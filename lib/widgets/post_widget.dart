import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:neighborhood_connect/widgets/comment_sheet.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String currentUserId; // Added field for current user ID

  const PostWidget(
      {Key? key, required this.postData, required this.currentUserId})
      : super(key: key);

  @override
  _PostWidgetState createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isLiked = false; // To track like status
  int _likeCount = 0; // To track like count
  Map<String, dynamic> _userData = {};
  String _postLocation = "";

  @override
  bool get wantKeepAlive => true;

  String _timeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) {
      return '${duration.inDays} days ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _getUserData(String userId) async {
    try {
      if (_userData.isNotEmpty) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    final lat = geoPoint.latitude;
    final lng = geoPoint.longitude;

    final apiKey = "AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8";

    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          String? street;
          String? area;
          String? city;

          for (var component in data['results'][0]['address_components']) {
            if (component['types'].contains('route')) {
              street = component['long_name'];
            } else if (component['types'].contains('neighborhood') ||
                component['types'].contains('sublocality') ||
                component['types'].contains('sublocality_level_1')) {
              area = component['long_name'];
            } else if (component['types'].contains('locality')) {
              city = component['long_name'];
            }
          }

          String address = "";
          if (street != null && area != null) {
            address = "$street, $area";
          } else if (area != null && city != null) {
            address = "$area, $city";
          } else if (street != null && city != null) {
            address = "$street, $city";
          } else if (area != null) {
            address = area;
          } else if (city != null) {
            address = city;
          } else {
            return "Address not found";
          }
          return address;
        }
      }
      return "Address not found";
    } catch (e) {
      return "Address not found";
    }
  }

  Future<void> _fetchLikeData() async {
    try {
      final postLikesRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postData['id']) // Assuming `id` is the post ID
          .collection('likes');

      final likeSnapshot = await postLikesRef.get();
      final userLikeDoc = await postLikesRef.doc(widget.currentUserId).get();

      setState(() {
        _likeCount = likeSnapshot.docs.length;
        _isLiked = userLikeDoc.exists;
      });
    } catch (e) {
      print("Error fetching like data: $e");
    }
  }

  Future<void> _toggleLike() async {
    final player = AudioPlayer(); // Create an instance of AudioPlayer

    try {
      final postLikesRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postData['id'])
          .collection('likes')
          .doc(widget.currentUserId);

      if (_isLiked) {
        // Unlike: Delete the user's document in the likes collection
        await postLikesRef.delete();
        setState(() {
          _isLiked = false;
          _likeCount--;
        });
      } else {
        // Like: Create a document with the user ID and save the timestamp
        await postLikesRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isLiked = true;
          _likeCount++;
        });

        // Play the sound effect when the user likes the post
        await player.play(AssetSource('sounds/like_sound.mp3'));
      }
    } catch (e) {
      print("Error toggling like: $e");
    }
  }

  void _loadData() async {
    await _getUserData(widget.postData['userId']);

    if (widget.postData['location'] != null) {
      _getAddressFromGeoPoint(widget.postData['location']).then((address) {
        if (mounted) {
          setState(() {
            _postLocation = address;
            _isLoading = false;
          });
        }
      });
    }

    await _fetchLikeData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _deletePost(String postId) async {
    try {
      // Save post ID in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      List<String> deletedPosts = prefs.getStringList('deletedPosts') ?? [];
      if (!deletedPosts.contains(postId)) {
        deletedPosts.add(postId);
        await prefs.setStringList('deletedPosts', deletedPosts);
      }

      // Update the UI to hide the post locally
      setState(() {
        widget.postData['isHidden'] = true;
      });

    } catch (error) {
      print('Error hiding post: $error');
    }
  }

  void _reportPost(String postId) async {
    TextEditingController issueController = TextEditingController();

    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Show the dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.report, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Report Post',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please specify the issue with this post (minimum 10 characters).',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 12),
              TextField(
                controller: issueController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Enter the issue',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
              child: Text(
                'Cancel',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final issueText = issueController.text.trim();
                if (issueText.length < 10) {
                  // Show error if issue is less than 10 characters
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Issue must be at least 10 characters long.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  try {
                    await FirebaseFirestore.instance.collection('reports').add({
                      'postId': postId,
                      'timestamp': FieldValue.serverTimestamp(),
                      'userId': widget.postData['userId'],
                      'issue': issueText,
                      'status': 'reported',
                    });
                    await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .update({
                      'reported': true,
                    });

                    // Hide the post locally
                    setState(() {
                      widget.postData['isHidden'] = true;
                    });

                    Navigator.of(dialogContext).pop(); // Close the dialog
                  } catch (error) {
                    print('Error reporting post: $error');
                  }
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return _buildShimmer();
    }

    if (widget.postData['isHidden'] == true) {
      return const SizedBox.shrink();
    }

    final String username = _userData['firstName'] ?? 'Unknown User';
    final String name = '${_userData['firstName']} ${_userData['lastName']}';
    final String content = widget.postData['content'] ?? '';
    final List<dynamic> mediaUrls = widget.postData['mediaUrls'] ?? [];
    final DateTime timestamp =
        (widget.postData['timestamp'] as Timestamp).toDate();
    final String timeAgo = _timeAgo(timestamp);

    return Card(
      margin: EdgeInsets.only(left: 0),
      elevation: 6,
      // margin: EdgeInsets.symmetric(vertical: 0),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 5),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _userData['profilePicture'] != null &&
                          _userData['profilePicture'].isNotEmpty
                      ? CachedNetworkImageProvider(_userData['profilePicture'])
                      : null,
                  child: (_userData['profilePicture'] == null ||
                          _userData['profilePicture'].isEmpty)
                      ? Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 20, color: Colors.black),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (_postLocation.isNotEmpty)
                        Text(
                          _postLocation,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      Text(
                        timeAgo,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    // Show the custom bottom sheet
                    showModalBottomSheet(
                        context: context,
                        isScrollControlled: true, // Allows custom height
                        builder: (BuildContext context) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                // Rounded corner for top-left
                                topRight: Radius.circular(30),
                              ),
                            ),
                            height: 220, // Set the desired height here
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                // Heading
                                Center(
                                  child: Text(
                                    'Post Actions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Divider(), // Separator line
// Action buttons
                                Material(
                                  color: Colors.transparent,
                                  // Ensure the Material widget is transparent
                                  child: InkWell(
                                    onTap: () {
                                      _deletePost(widget.postData['id']);
                                      Navigator.pop(
                                          context); // Close the bottom sheet
                                    },
                                    child: ListTile(
                                      leading: Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      title: Text('Hide Post'),
                                    ),
                                  ),
                                ),
                                Divider(),
                                Material(
                                  color: Colors.transparent,
                                  // Ensure the Material widget is transparent
                                  child: InkWell(
                                    onTap: () {
                                      // Call _reportPost with the post ID
                                      _reportPost(widget.postData['id']);
                                    },
                                    child: ListTile(
                                      leading: const Icon(Icons.report,
                                          color: Colors.orange),
                                      title: const Text('Report Post'),
                                    ),
                                  ),
                                ),
                                Divider(),
                              ],
                            ),
                          );
                        });
                  },
                  child: const Icon(Icons.more_vert),
                )
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 8),
          if (mediaUrls.isNotEmpty)
            Column(
              children: mediaUrls.map((url) {
                final isVideo = url.endsWith('.mp4') || url.endsWith('.mov');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: isVideo
                      ? Container(
                          height: 200,
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, size: 50),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              width: double.infinity,
                              height: 200, // Set height for shimmer placeholder
                              color: Colors.grey,
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like Button
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
                        color: _isLiked ? Colors.blue : Colors.black,
                      ),
                      onPressed: _toggleLike,
                    ),
                    Text(
                      '$_likeCount',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                // Comment Button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: () {
                        // Assuming you want to pass the entire postData for this post
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true, // Allows custom height
                          builder: (BuildContext context) {
                            return Container(
                              height: MediaQuery.of(context).size.height * 0.7,
                              // Set the desired height here (60% of screen height)
                              child: CommentsBottomSheet(
                                  postData: widget.postData),
                            );
                          },
                        );
                      },
                    ),
                    Text(
                      '${widget.postData['commentCount'] ?? 0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),

                // Share Button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {
                        // Share post action
                      },
                    ),
                    Text(
                      '${widget.postData['shareCount'] ?? 0}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black12,
            height: 6,
          )
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 2,
      // Number of shimmer placeholders
      physics: const NeverScrollableScrollPhysics(),
      // Disable scrolling for shimmer placeholders
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
            child: Row(
              children: [
                // Left-side circular profile
                CircleAvatar(radius: 30, backgroundColor: Colors.grey),
                const SizedBox(width: 12),
                // Right-side rectangular container
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.6,
                        height: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: 15,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
