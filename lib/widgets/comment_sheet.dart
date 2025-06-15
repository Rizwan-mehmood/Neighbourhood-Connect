import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> postData;

  const CommentsBottomSheet({required this.postData});

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  late User _currentUser;
  late Map<String, dynamic> _currentUserData;
  bool _isUserDataLoaded = false; // Flag to check if user data is loaded
  bool _areCommentsLoaded = false; // Flag to check if comments are loaded
  List<Map<String, dynamic>> _comments = []; // Store the comments

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _fetchData();
  }

  void _postComment() {
    if (!_isUserDataLoaded)
      return; // Prevent posting if user data is not loaded

    final commentText = _commentController.text.trim();
    if (commentText.isNotEmpty) {
      // Temporarily add the comment to the local list for immediate UI update
      final newComment = {
        'comment': commentText,
        'profilePicture': _currentUserData['profilePicture'],
        'timestamp': Timestamp.now(),
        'userId': _currentUserData['userId'],
        'username':
            '${_currentUserData['firstName']} ${_currentUserData['lastName']}',
      };

      setState(() {
        _comments.insert(
            0, newComment); // Add the comment at the top of the list
        _commentController.clear(); // Clear the comment field
      });

      final postId = widget.postData['id'];

      // Reference to the post document
      final postRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);

      // Update the comment count and save the comment to Firestore
      FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(postRef);

        if (postSnapshot.exists) {
          // Safely check if 'commentCount' exists
          final postData = postSnapshot.data() as Map<String, dynamic>?;
          int commentCount = postData?['commentCount'] ?? 0;

          // If 'commentCount' doesn't exist, initialize it to 0
          if (postData == null || !postData.containsKey('commentCount')) {
            transaction.update(postRef, {
              'commentCount': 0, // Initialize commentCount if not available
            });
            commentCount = 0; // Ensure commentCount is set to 0
          }

          // Increment comment count
          transaction.update(postRef, {
            'commentCount': commentCount + 1,
          });

          await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .add({
            'comment': commentText,
            'profilePicture': _currentUserData['profilePicture'],
            'timestamp': FieldValue.serverTimestamp(),
            'userId': _currentUserData['userId'],
            'username':
                '${_currentUserData['firstName']} ${_currentUserData['lastName']}',
          });
        }
      }).catchError((error) {
        print('Error adding comment: $error');
        // Optional: Handle error (e.g., remove the temporary comment from the list)
      });
    }
  }

  // Fetch user data and comments
  void _fetchData() async {
    try {
      // Fetch user data from Firestore 'users' collection
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      // Check if the user document exists
      if (userSnapshot.exists) {
        // Save user data into _currentUserData
        setState(() {
          _currentUserData = userSnapshot.data() as Map<String, dynamic>;
          _isUserDataLoaded = true; // Set flag to true once data is loaded
        });
      } else {
        print('User data not found.');
      }

      // Fetch comments for the post
      final postId = widget.postData['id'];
      final commentsQuery = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true);

      final querySnapshot = await commentsQuery.get();
      print('Found ${querySnapshot.docs.length} comments');

      if (querySnapshot.docs.isEmpty) {
        print('No comments found');
      }

      final commentsList =
          await Future.wait(querySnapshot.docs.map((doc) async {
        final commentData = doc.data();
        return {
          'comment': commentData['comment'],
          'profilePicture': commentData['profilePicture'],
          'timestamp': commentData['timestamp'],
          'username': commentData['username'],
          'userId': doc.id,
        };
      }).toList());

      setState(() {
        _comments = commentsList;
        _areCommentsLoaded = true; // Set flag to true once comments are loaded
      });
    } catch (e) {
      print('Error fetching user data or comments: $e');
    }
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final time = timeago.format(timestamp.toDate(), locale: 'en_short');
    return time.replaceFirst('~', '');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside the comment field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Draggable handle (grey line at the top)
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Comments heading
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: Center(
                  child: Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Divider
              Divider(),

              // Scrollable comments section
              Expanded(
                child: _isUserDataLoaded && _areCommentsLoaded
                    ? _comments.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final comment = _comments[index];

                              // Formatting timestamp to human-readable format
                              final timestamp =
                                  comment['timestamp'] as Timestamp;
                              final formattedTime = _formatTimeAgo(timestamp);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Display profile picture or first letter of username
                                    CircleAvatar(
                                      backgroundImage:
                                          comment['profilePicture'] != null
                                              ? NetworkImage(
                                                  comment['profilePicture'])
                                              : null,
                                      child: comment['profilePicture'] == null
                                          ? Text(comment['username'][0]
                                              .toUpperCase())
                                          : null,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Username and timestamp row
                                          Row(
                                            children: [
                                              Text(
                                                comment['username'] ??
                                                    'Anonymous',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                formattedTime ?? 'Just now',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          // Comment text
                                          Text(
                                            comment['comment'] ?? '',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                              'No comments available',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            ),
                          )
                    // Show shimmer loading effect while data is loading
                    : ListView.builder(
                        itemCount: 10, // Show 10 loading items for shimmer
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.grey[300],
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 10,
                                          color: Colors.grey[300],
                                          width: 120,
                                        ),
                                        SizedBox(height: 4),
                                        Container(
                                          height: 10,
                                          color: Colors.grey[300],
                                          width: 200,
                                        ),
                                        SizedBox(height: 4),
                                        Container(
                                          height: 10,
                                          color: Colors.grey[300],
                                          width: 80,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Comment input section stays fixed at the bottom
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: Offset(0, -1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 16.0, top: 10, bottom: 16),
                    child: Row(
                      children: [
                        // Profile picture or initials if the profile picture is null
                        _isUserDataLoaded
                            ? CircleAvatar(
                                radius: 20,
                                backgroundImage:
                                    _currentUserData['profilePicture'] != null
                                        ? NetworkImage(
                                            _currentUserData['profilePicture'])
                                        : null,
                                child: _currentUserData['profilePicture'] ==
                                        null
                                    ? Text(
                                        '${_currentUserData['firstName']} ${_currentUserData['lastName']}'
                                                .isNotEmpty
                                            ? _currentUserData['firstName'][0]
                                                .toUpperCase()
                                            : 'U',
                                        // Display the first letter of firstName if no profile picture
                                        style: TextStyle(fontSize: 16),
                                      )
                                    : null,
                              )
                            : Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[300],
                                ),
                              ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _isUserDataLoaded
                              ? Container(
                                  height: 55, // Set the desired height here
                                  child: TextField(
                                    controller: _commentController,
                                    focusNode: _commentFocusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Write a comment...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(26),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[200],
                                    ),
                                  ),
                                )
                              : Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                ),
                        ),
                        IconButton(
                          onPressed: _isUserDataLoaded ? _postComment : null,
                          icon: Icon(Icons.send, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
