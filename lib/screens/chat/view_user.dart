import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;

class ViewUser extends StatelessWidget {
  final String userId;

  const ViewUser({Key? key, required this.userId}) : super(key: key);

  // Fetch user data from Firestore.
  Future<DocumentSnapshot> _fetchUserData() {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  // Stream posts of the user from Firestore, ordered by 'timestamp'.
  Stream<QuerySnapshot> _fetchUserPosts() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('User not found.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String firstName = userData['firstName'] as String? ?? '';
          final String lastName = userData['lastName'] as String? ?? '';
          final String profilePicture =
              userData['profilePicture'] as String? ?? '';
          final String bio = userData['bio'] as String? ?? '';
          final createdAt = userData['createdAt'];
          String memberSince = '';
          if (createdAt is Timestamp) {
            memberSince = DateFormat('MMM dd, yyyy').format(createdAt.toDate());
          } else if (createdAt is DateTime) {
            memberSince = DateFormat('MMM dd, yyyy').format(createdAt);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profilePicture.isNotEmpty
                            ? NetworkImage(profilePicture)
                            : null,
                        child: profilePicture.isEmpty
                            ? Text(
                                firstName.isNotEmpty ? firstName[0] : '',
                                style: const TextStyle(fontSize: 40),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since $memberSince',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons: Friend Request and Message
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement friend request logic.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Friend request sent!')),
                              );
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Friend'),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () async {
                              // Messaging logic:
                              // 1. Get the current user.
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please log in to send a message.')));
                                return;
                              }
                              final currentUserId = currentUser.uid;
                              final peerUserId = userId;

                              // 2. Create a unique channel id by sorting the ids.
                              final members = [currentUserId, peerUserId]
                                ..sort();
                              final channelId = members.join('_');

                              // 3. Get the Stream Chat client from context.
                              final client =
                                  stream.StreamChat.of(context).client;

                              // 4. Create (or get) a channel for one-to-one messaging.
                              final channel = client.channel('messaging',
                                  id: channelId,
                                  extraData: {
                                    'members': members,
                                  });
                              await channel.watch();

                              // 5. Navigate to the ChatScreen.
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ChatScreen(channel: channel)),
                              );
                            },
                            icon: const Icon(Icons.message),
                            label: const Text('Message'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Posts Header
                Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  padding: const EdgeInsets.all(12.0),
                  child: const Text(
                    'Posts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // User Posts Section
                StreamBuilder<QuerySnapshot>(
                  stream: _fetchUserPosts(),
                  builder: (context, postsSnapshot) {
                    if (postsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!postsSnapshot.hasData ||
                        postsSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text('No posts available.')),
                      );
                    }
                    final posts = postsSnapshot.data!.docs;
                    return ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: posts.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final postData =
                            posts[index].data() as Map<String, dynamic>;
                        final String content =
                            postData['content'] as String? ?? '';
                        final Timestamp? timestamp =
                            postData['timestamp'] as Timestamp?;
                        final String postDate = timestamp != null
                            ? DateFormat('MMM dd, yyyy hh:mm a')
                                .format(timestamp.toDate())
                            : '';
                        final int commentCount = postData['commentCount'] is int
                            ? postData['commentCount'] as int
                            : 0;
                        final List<dynamic> mediaUrlsDynamic =
                            postData['mediaUrls'] as List<dynamic>? ?? [];
                        final List<String> mediaUrls =
                            mediaUrlsDynamic.map((e) => e.toString()).toList();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (content.isNotEmpty)
                                  Text(
                                    content,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                if (content.isNotEmpty)
                                  const SizedBox(height: 8),
                                if (mediaUrls.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      mediaUrls[0],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          postDate,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.comment,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$commentCount',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A simple chat screen using Stream Chat widgets.
class ChatScreen extends StatelessWidget {
  final stream.Channel channel;

  const ChatScreen({Key? key, required this.channel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return stream.StreamChannel(
      channel: channel,
      child: Scaffold(
        appBar: stream.StreamChannelHeader(),
        body: Column(
          children: [
            Expanded(child: stream.StreamMessageListView()),
            stream.StreamMessageInput(),
          ],
        ),
      ),
    );
  }
}
