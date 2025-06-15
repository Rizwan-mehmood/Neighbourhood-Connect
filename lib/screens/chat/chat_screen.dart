import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neighborhood_connect/screens/chat/view_user.dart';
import 'package:neighborhood_connect/widgets/custom_chat_appBar.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;
import '../../widgets/custom_siderBar.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final stream.StreamChannelListController _channelListController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Variables to store the current user's data.
  String firstName = '';
  String lastName = '';
  String profilePicture = '';
  bool isLoading = true;
  late TextEditingController _searchController;
  Stream<QuerySnapshot>? _usersStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    // Retrieve the Stream Chat client from the inherited widget.
    final streamClient = stream.StreamChat.of(context).client;
    // Create a filter to get only channels where the current user is a member.
    final filter = stream.Filter.and([
      stream.Filter.in_('members', [streamClient.state.currentUser?.id ?? '']),
    ]);
    _channelListController = stream.StreamChannelListController(
      client: streamClient,
      filter: filter,
      limit: 20,
    );
    _searchController = TextEditingController();
    _searchController.addListener(_performSearch);
  }

  Future<List<QueryDocumentSnapshot>> _searchUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_searchQuery.isEmpty || currentUserId == null) return [];

    final searchQueryLower = _searchQuery.toLowerCase();

    // Fetch all users except the current one.
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('userId', isNotEqualTo: currentUserId)
        .get();

    // Client-side filtering: check if the first or last name contains the search query.
    final filteredDocs = usersSnapshot.docs.where((doc) {
      final fname = (doc.get('firstName') as String).toLowerCase();
      final lname = (doc.get('lastName') as String).toLowerCase();
      return fname.contains(searchQueryLower) ||
          lname.contains(searchQueryLower);
    }).toList();

    return filteredDocs;
  }

  void _performSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });

    if (_searchQuery.isEmpty) {
      setState(() => _usersStream = null);
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() {
      _usersStream = FirebaseFirestore.instance
          .collection('users')
          .where('userId', isNotEqualTo: currentUserId)
          .where('firstName', isGreaterThanOrEqualTo: _searchQuery)
          .where('firstName', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .orderBy('firstName')
          .snapshots();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            firstName = userDoc.get('firstName') ?? '';
            lastName = userDoc.get('lastName') ?? '';
            profilePicture = userDoc.get('profilePicture') ?? '';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  void dispose() {
    _channelListController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_scaffoldKey.currentState!.isDrawerOpen) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          // Set the height of the appBar
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black12, // Shadow color
                  blurRadius: 6.0, // Softness of the shadow
                  offset: Offset(0, 4), // Position the shadow below the appBar
                ),
              ],
            ),
            child: CustomChatAppBar(
              profilePicture: profilePicture,
              firstName: firstName,
              scaffoldKey: _scaffoldKey,
              controller: _searchController,
            ),
          ),
        ),
        drawer: CustomDrawer(
          profilePicture: profilePicture,
          firstName: firstName,
          lastName: lastName,
        ),
        body: Stack(
          children: [
            // Main content: Channel list view filling available space.
            Positioned.fill(
              child: stream.StreamChannelListView(
                controller: _channelListController,
                itemBuilder: (context, channels, index, defaultWidget) {
                  final channel = channels[index];
                  return ChatListTile(
                    channel: channel,
                    currentUserId: currentUserId,
                  );
                },
              ),
            ),
            // Floating search results overlay.
            if (_searchQuery.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    color: Colors.white,
                    child: FutureBuilder<List<QueryDocumentSnapshot>>(
                      future: _searchUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const ListTile(
                              title: Text('Error fetching users'));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const ListTile(title: Text('No users found'));
                        }
                        final users = snapshot.data!;
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: users.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 0),
                          itemBuilder: (context, index) {
                            final user =
                                users[index].data() as Map<String, dynamic>;
                            final fname = user['firstName'] as String? ?? '';
                            final lname = user['lastName'] as String? ?? '';
                            final pfp = user['profilePicture'] as String? ?? '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    pfp.isNotEmpty ? NetworkImage(pfp) : null,
                                child: pfp.isEmpty
                                    ? Text(fname.isNotEmpty ? fname[0] : '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text('$fname $lname'),
                              onTap: () {
                                _searchController.clear();
                                final userId = user['userId'] as String;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ViewUser(userId: userId),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.person_search),
          backgroundColor: Colors.greenAccent[100],
          onPressed: () {
            Navigator.pushNamed(context, '/searchUser');
          },
        ),
      ),
    );
  }
}

/// Custom widget for displaying a chat list tile with avatar, name, last message, time, and unread count.
class ChatListTile extends StatelessWidget {
  final stream.Channel channel;
  final String currentUserId;

  const ChatListTile({
    Key? key,
    required this.channel,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<dynamic> memberIds =
        channel.state?.members.map((m) => m.user?.id).toList() ?? [];
    final peerUserId = memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return Column(
      children: [
        // const Divider(height: 1, thickness: 0.5),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(peerUserId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.data() == null) {
              return const ListTile(title: Text('Loading...'));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String fname = data['firstName'] ?? '';
            final String lname = data['lastName'] ?? '';
            final String pfp = data['profilePicture'] ?? '';

            final lastMessage = channel.state?.messages.isNotEmpty == true
                ? channel.state!.messages.last
                : null;
            final lastMessageText = lastMessage?.text ?? '';
            final lastMessageTime = lastMessage?.createdAt;
            String timeString = '';
            if (lastMessageTime != null) {
              timeString = DateFormat('hh:mm a').format(lastMessageTime);
            }

            final int unreadCount = (channel.state?.read.isNotEmpty ?? false)
                ? channel.state!.unreadCount
                : 0;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(0),
              ),
              // margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => stream.StreamChannel(
                          channel: channel,
                          child: const ChatScreen(),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            pfp.isNotEmpty ? Colors.transparent : Colors.blue,
                        backgroundImage:
                            pfp.isNotEmpty ? NetworkImage(pfp) : null,
                        child: pfp.isEmpty
                            ? Text(
                                fname.isNotEmpty ? fname[0].toUpperCase() : '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$fname $lname',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.blueAccent,
                                      Colors.lightBlueAccent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class CustomChannelHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const CustomChannelHeader({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<DocumentSnapshot<Map<String, dynamic>>> _getOtherUserData(
      String otherUserId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    final channel = stream.StreamChannel.of(context).channel;
    final currentUser = stream.StreamChat.of(context).currentUser;

    // Determine the other member's id in a one-to-one chat.
    String? otherUserId;
    if (channel.state?.members != null && currentUser != null) {
      try {
        final member = channel.state!.members.firstWhere(
          (m) => m.user?.id != currentUser.id,
        );
        otherUserId = member.user?.id;
      } catch (_) {
        // fallback if no member is found
      }
    }

    if (otherUserId == null) {
      // Fallback header if we can't determine the other user.
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Chat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _getOtherUserData(otherUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While loading, show an AppBar with a circular progress indicator.
          return AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            title: Row(
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // If no data is available, fallback.
          return AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
          );
        }

        final userData = snapshot.data!.data()!;
        final String firstName = userData['firstName'] ?? '';
        final String lastName = userData['lastName'] ?? '';
        final String profilePicture = userData['profilePicture'] ?? '';
        final String displayName = ('$firstName $lastName').trim();

        return AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: profilePicture.isNotEmpty
                    ? Colors.transparent
                    : Colors.blue,
                backgroundImage: profilePicture.isNotEmpty
                    ? NetworkImage(profilePicture)
                    : null,
                child: profilePicture.isEmpty
                    ? Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _hasMarkedRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasMarkedRead) {
      // Mark the channel as read immediately after the first frame is rendered.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final channel = stream.StreamChannel.of(context).channel;
        channel.markRead();
        // You may also trigger additional logic to update your UI or remove
        // unread count badges here.
      });
      _hasMarkedRead = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomChannelHeader(),
      body: Column(
        children: [
          // Wrap the message list with a ScrollConfiguration for smooth scrolling.
          Expanded(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(),
              ),
              child: stream.StreamMessageListView(
                  // Optionally, supply a custom messageBuilder to create chat bubbles
                  // similar to WhatsApp. For example:
                  // messageBuilder: (context, details, messages, defaultMessageWidget) {
                  //   return CustomMessageBubble(
                  //     message: details.message,
                  //     // Add further customizations for seen/read indicators.
                  //   );
                  // },
                  ),
            ),
          ),
          // Chat message input field.
          stream.StreamMessageInput(
              // Customize your message input as needed.
              // For example, you could add send button styling or attachment handling.
              ),
        ],
      ),
    );
  }
}
