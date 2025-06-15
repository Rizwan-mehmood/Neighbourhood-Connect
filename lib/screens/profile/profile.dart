import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:neighborhood_connect/widgets/upload_media.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<String?> coverPhotoNotifier = ValueNotifier(null);
  final ValueNotifier<String?> profilePhotoNotifier = ValueNotifier(null);

  DocumentSnapshot? _userDoc;

  bool _isUpdatingCover = false;
  bool _isUpdatingProfile = false;

  // For demonstration, these fields are optional in Firestore.
  String coverPhoto = '';
  String profilePicture = '';
  String fullName = '';
  String bio = '';
  String school = '';
  String city = '';
  String marriageStatus = '';
  int friendsCount = 0;
  List<dynamic> friends = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    coverPhotoNotifier.dispose();
    profilePhotoNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      final doc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;

        // Safely extract fields; if they don't exist, fallback to empty or 0.
        final fetchedCoverPhoto =
            userData.containsKey('coverPhoto') ? userData['coverPhoto'] : '';
        final fetchedProfilePicture = userData.containsKey('profilePicture')
            ? userData['profilePicture']
            : '';
        final firstName =
            userData.containsKey('firstName') ? userData['firstName'] : '';
        final lastName =
            userData.containsKey('lastName') ? userData['lastName'] : '';
        final fetchedFullName = '$firstName $lastName'.trim();
        final fetchedBio = userData.containsKey('bio') ? userData['bio'] : '';
        final fetchedSchool =
            userData.containsKey('school') ? userData['school'] : '';
        final fetchedCity =
            userData.containsKey('city') ? userData['city'] : '';
        final fetchedMarriageStatus = userData.containsKey('marriageStatus')
            ? userData['marriageStatus']
            : '';
        final fetchedFriendsCount = userData.containsKey('friends_count')
            ? userData['friends_count']
            : 0;
        final fetchedFriends =
            userData.containsKey('friends') ? userData['friends'] as List : [];

        setState(() {
          coverPhoto = fetchedCoverPhoto;
          profilePicture = fetchedProfilePicture;
          fullName = fetchedFullName;
          bio = fetchedBio;
          school = fetchedSchool;
          city = fetchedCity;
          marriageStatus = fetchedMarriageStatus;
          friendsCount = fetchedFriendsCount;
          friends = fetchedFriends;
        });

        // Update the notifiers with the fetched values.
        coverPhotoNotifier.value = fetchedCoverPhoto;
        profilePhotoNotifier.value = fetchedProfilePicture;

        _userDoc = doc;
      }
    }
  }

  Future<Map<String, dynamic>> getUserData(String friendId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .get();
    if (docSnapshot.exists) {
      return docSnapshot.data() as Map<String, dynamic>;
    }
    return {};
  }

  // ----- COVER & PROFILE PHOTO UPDATE LOGIC -----
  Future<void> _updateCoverPhoto() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return; // user canceled picking an image

    // Show the loader overlay.
    setState(() {
      _isUpdatingCover = true;
    });

    final file = File(pickedFile.path);
    final fileName =
        'coverPhotos/${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Upload the file to Google Drive using your GoogleDriveService.
    final downloadUrl = await GoogleDriveService.uploadFile(file, fileName);

    // Update Firestore user document with the new cover photo URL.
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'coverPhoto': downloadUrl});

    // Update the notifier and hide the loader.
    coverPhotoNotifier.value = downloadUrl;
    setState(() {
      _isUpdatingCover = false;
    });
  }

  Future<void> _updateProfilePhoto() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return; // user canceled picking an image

    // Show the loader overlay.
    setState(() {
      _isUpdatingProfile = true;
    });

    final file = File(pickedFile.path);
    final fileName =
        'profilePictures/${_auth.currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Upload the file to Google Drive using your GoogleDriveService.
    final downloadUrl = await GoogleDriveService.uploadFile(file, fileName);

    // Update Firestore user document with the new profile photo URL.
    await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'profilePicture': downloadUrl});

    // Update the notifier and hide the loader.
    profilePhotoNotifier.value = downloadUrl;
    setState(() {
      _isUpdatingProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // While loading user data, show a loader.
    if (_userDoc == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Profile')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // COVER PHOTO
            ValueListenableBuilder<String?>(
              valueListenable: coverPhotoNotifier,
              builder: (context, coverPhoto, child) {
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        image: (coverPhoto != null && coverPhoto.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(coverPhoto),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                    // Camera icon for cover photo
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: InkWell(
                        onTap: _updateCoverPhoto,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.camera_alt, color: Colors.white),
                        ),
                      ),
                    ),
                    // Loader overlay
                    if (_isUpdatingCover)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black45,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                  ],
                );
              },
            ),
            // PROFILE PHOTO & NAME
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Overlapping profile photo
                  ValueListenableBuilder<String?>(
                    valueListenable: profilePhotoNotifier,
                    builder: (context, profilePicture, child) {
                      return Transform.translate(
                        offset: Offset(0, -80),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[300],
                                backgroundImage: (profilePicture != null &&
                                        profilePicture.isNotEmpty)
                                    ? NetworkImage(profilePicture)
                                    : null,
                                child: (profilePicture == null ||
                                        profilePicture.isEmpty)
                                    ? Icon(Icons.person, size: 50)
                                    : null,
                              ),
                            ),
                            // Camera icon for profile photo
                            Positioned(
                              right: 10,
                              bottom: 5,
                              child: InkWell(
                                onTap: _updateProfilePhoto,
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.camera_alt,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            // Loader overlay for profile photo
                            if (_isUpdatingProfile)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black45,
                                  ),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(-140, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isNotEmpty ? fullName : "No Name",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              text: '$friendsCount ', // This part is bold
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: 'friends', // This part is normal
                                  style: TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 5,
              thickness: 5,
              color: Colors.grey[300],
            ),
            SizedBox(height: 10),
            // FRIENDS
            _buildFriendsSection(),
            SizedBox(height: 20),
            Divider(
              height: 5,
              thickness: 5,
              color: Colors.grey[300],
            ),
            _buildPostsTab(),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildFriendsSection() {
    if (friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "No Friends",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Friends",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        // Grid of friends
        // shrinkWrap + NeverScrollableScrollPhysics ensures the grid
        // expands to fit its children without scrolling inside the Column.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Number of columns
              crossAxisSpacing: 4, // Horizontal spacing
              mainAxisSpacing: 8, // Vertical spacing
              childAspectRatio: 0.75, // Width/height ratio of each cell
            ),
            // Limit how many friends to show (max 6 friends)
            itemCount: friends.length > 6 ? 6 : friends.length,
            itemBuilder: (context, index) {
              final friendId = friends[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: getUserData(friendId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError || !snapshot.hasData) {
                    return Icon(Icons.error);
                  }
                  final friendData = snapshot.data!;
                  final friendFirstName = friendData['firstName'] ?? '';
                  final friendLastName = friendData['lastName'] ?? '';
                  final friendName = "$friendFirstName $friendLastName".trim();
                  final friendProfile = friendData['profilePicture'] ?? '';

                  return GestureDetector(
                    onTap: () {
                      // Navigate to friend's profile screen with friendData.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FriendProfileScreen(friendData: friendData),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        // Friend image with rounded corners
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: friendProfile.isNotEmpty
                              ? Image.network(
                                  friendProfile,
                                  height: 115,
                                  width: 115,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 115,
                                  width: 115,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.person, size: 30),
                                ),
                        ),
                        const SizedBox(height: 4),
                        // Friend name (with ellipsis if too long)
                        Container(
                          width: 115, // Fixed width matching the image
                          child: Text(
                            friendName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // "See all friends" button below the grid
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[200], // background color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // rounded corners
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AllFriendsScreen()),
                );
              },
              child: Text(
                "See all friends",
                style: TextStyle(
                  color: Colors.black, // text color
                  fontSize: 14,
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No posts found"));
        }

        final posts = snapshot.data!.docs; // List of post documents
        final List<Widget> postWidgets = [];

        // Add Posts heading
        postWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              "Posts",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );

        // Loop through each post and add a card along with a divider after each (except the last one)
        for (int i = 0; i < posts.length; i++) {
          final doc = posts[i];
          final postData = doc.data() as Map<String, dynamic>;

          final content = postData['content'] ?? '';
          final timestamp = postData['timestamp'] as Timestamp;
          final postTime = timestamp.toDate();
          final mediaUrls = (postData['mediaUrls'] ?? []) as List;
          final userId = postData['userId'] ?? '';

          postWidgets.add(
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return SizedBox.shrink();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                final userName =
                    '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                        .trim();
                final userProfilePic = userData['profilePicture'] ?? '';

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero, // No rounded corners
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row for user avatar, name, and timestamp
                      Padding(
                        padding: EdgeInsets.only(left: 12, right: 12, top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: userProfilePic.isNotEmpty
                                  ? NetworkImage(userProfilePic)
                                  : null,
                              child: userProfilePic.isEmpty
                                  ? const Icon(Icons.person, size: 20)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName.isNotEmpty
                                        ? userName
                                        : 'Unknown User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy – hh:mm a')
                                        .format(postTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Post content
                      if (content.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            content,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Show the first image if available (no rounded corners)
                      if (mediaUrls.isNotEmpty)
                        Image.network(
                          mediaUrls[0],
                          fit: BoxFit.cover,
                        ),
                    ],
                  ),
                );
              },
            ),
          );

          // Add a divider between posts (except after the last post)
          if (i != posts.length - 1) {
            postWidgets.add(
              Divider(
                height: 5,
                thickness: 5,
                color: Colors.grey[300],
              ),
            );
          }
        }

        // Add a final stylish message after the last post
        postWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                "You've caught up!",
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: postWidgets,
        );
      },
    );
  }
}

// ----- PLACEHOLDER SCREENS BELOW -----

class EditProfileScreen extends StatelessWidget {
  // Here you can build a form to edit the user's bio, school, city, marriage status, etc.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Profile"),
      ),
      body: Center(child: Text("Edit Profile Screen")),
    );
  }
}

class AllFriendsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Display a full list of user's friends
    return Scaffold(
      appBar: AppBar(
        title: Text("All Friends"),
      ),
      body: Center(child: Text("All Friends Screen")),
    );
  }
}

class FriendProfileScreen extends StatelessWidget {
  final Map friendData;

  const FriendProfileScreen({Key? key, required this.friendData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    String friendFirstName = friendData['firstName'] ?? '';
    String friendLastName = friendData['lastName'] ?? '';
    String friendName = "$friendFirstName $friendLastName".trim();
    String friendProfile = friendData['profilePicture'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(friendName.isNotEmpty ? friendName : "Friend Profile"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  friendProfile.isNotEmpty ? NetworkImage(friendProfile) : null,
              child:
                  friendProfile.isEmpty ? Icon(Icons.person, size: 50) : null,
            ),
            SizedBox(height: 16),
            Text(friendName, style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}
