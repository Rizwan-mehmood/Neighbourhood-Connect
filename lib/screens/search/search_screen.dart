import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/rendering.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../createPost/post_creation_screen.dart';
import '../marketplace/marketplace_screen.dart';
import '../notification/notification_screen.dart';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String? _userProfileImageUrl;
  String _userNameInitial = '';
  String _userName = '';
  bool _isSidebarOpen = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> recentSearches = ["Flutter", "Firebase", "Dart", "Marketplace"];
  final int maxSearches = 10;
  int unreadNotifications = 0;

  // void _addToRecentSearches(String query) {
  //   if (query.isNotEmpty) {
  //     setState(() {
  //       // Remove existing search if it already exists
  //       recentSearches.remove(query);
  //       // Add the new search at the top
  //       recentSearches.insert(0, query);
  //       // Keep only the latest 10 searches
  //       if (recentSearches.length > maxSearches) {
  //         recentSearches.removeLast();
  //       }
  //     });
  //   }
  // }

  void _deleteRecentSearch(String search) {
    setState(() {
      recentSearches.remove(search);
    });
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> fetchUnreadNotifications() async {
    try {
      // Get the current user's ID
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // If no user is logged in, handle gracefully
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }

      final userId = currentUser.uid;
      // Check if the user has a document in the `notifications` collection
      final userNotificationDoc = await FirebaseFirestore.instance
          .collection('notification') // Parent notifications collection
          .doc(userId) // Match docId with current user ID
          .get();
      if (!userNotificationDoc.exists) {
        // If no matching document exists
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }
      // Fetch the nested `notifications` collection
      final nestedNotificationsSnapshot = await FirebaseFirestore.instance
          .collection('notification')
          .doc(userId)
          .collection('notifications') // Nested collection
          .get();

      if (nestedNotificationsSnapshot.docs.isEmpty) {
        // If the nested collection is empty
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }

      // Count notifications where `isRead` is false
      int count = nestedNotificationsSnapshot.docs
          .where((doc) => doc.data()['isRead'] == false)
          .length;

      setState(() {
        unreadNotifications = count;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        unreadNotifications = 0; // Default to 0 on error
      });
    }
  }

  Future<void> initialize() async {
    await _fetchUserProfile();
    await fetchUnreadNotifications();
  }

  void _clearAllSearches() {
    setState(() {
      recentSearches.clear();
    });
  }

  Future<void> _fetchUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _userProfileImageUrl = userProfile[
            'profilePicture']; // profilePicture field in user document
        _userNameInitial = userProfile['firstName'].isNotEmpty
            ? userProfile['firstName'][0]
            : '';
        _userName = userProfile['firstName'] + ' ' + userProfile['lastName'];
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _viewProfile() {
    Navigator.pushNamed(context, '/profile');
  }

  void _viewEvents() {
    Navigator.pushNamed(context, '/events');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile Icon (First letter or Profile Picture)
            GestureDetector(
              onTap: _toggleSidebar,
              child: CircleAvatar(
                radius: 20, // Adjusted size
                backgroundImage: _userProfileImageUrl != null &&
                        _userProfileImageUrl!.isNotEmpty
                    ? NetworkImage(_userProfileImageUrl!)
                    : null,
                child: _userProfileImageUrl == null ||
                        _userProfileImageUrl!.isEmpty
                    ? Text(_userNameInitial)
                    : null,
              ),
            ),
            // Search Bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(30),
                        right: Radius.circular(30),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  ),
                ),
              ),
            ),
            // Add Connection Icon
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationScreen()));
                  },
                ),
                Positioned(
                  right: 8,
                  // Adjust the position to align with the icon
                  top: 2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadNotifications > 10
                            ? '10+'
                            : unreadNotifications.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
        automaticallyImplyLeading:
            false, // Make sure the back arrow doesn't appear automatically
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recentSearches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Searches",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: _clearAllSearches,
                          child: Text(
                            "Clear All",
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (recentSearches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: recentSearches.map((search) {
                        return Chip(
                          label: Text(search),
                          backgroundColor: Colors.grey[200],
                          deleteIcon: Icon(Icons.close, color: Colors.black),
                          deleteIconColor: Colors.black,
                          onDeleted: () => _deleteRecentSearch(search),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Explore Nearby",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ExploreItem(icon: Icons.group, label: "Groups"),
                      ExploreItem(icon: Icons.event, label: "Events"),
                      ExploreItem(icon: Icons.store, label: "Marketplace"),
                      ExploreItem(icon: Icons.local_offer, label: "Offers"),
                      ExploreItem(icon: Icons.work, label: "Jobs"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          if (_isSidebarOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 250,
              child: Drawer(
                child: Column(
                  children: [
                    Container(
                      color: Colors.purple,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back,
                                size: 30, color: Colors.white),
                            onPressed: _toggleSidebar,
                          ),
                        ),
                      ),
                    ),
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                      ),
                      currentAccountPicture: CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            _userProfileImageUrl?.isNotEmpty == true
                                ? NetworkImage(_userProfileImageUrl!)
                                : null,
                        child: _userProfileImageUrl == null ||
                                _userProfileImageUrl!.isEmpty
                            ? Text(
                                _userNameInitial,
                                style: TextStyle(
                                    fontSize: 24, color: Colors.white),
                              )
                            : null,
                      ),
                      accountName: Text(
                        _userName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      accountEmail: SizedBox.shrink(),
                    ),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.black),
                      title: Text('View Profile'),
                      onTap: _viewProfile,
                    ),
                    ListTile(
                      leading: Icon(Icons.event, color: Colors.black),
                      title: Text('Events'),
                      onTap: _viewEvents,
                    ),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.black),
                      title: Text('Settings'),
                      onTap: () {
                        // Navigate to settings screen
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.black),
                      title: Text('Sign Out'),
                      onTap: _signOut,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        // Ensure both icons and labels are shown
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            tooltip: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
            tooltip: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Add Post',
            tooltip: 'Add Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'For Sale',
            tooltip: 'For Sale',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add),
            label: 'Chat',
            tooltip: 'Chat',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomeScreen()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostCreationScreen()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MarketplaceScreen()),
            );
          }
          if (index == 4) {
            // Navigator.push(
            //   context,
            //   MaterialPageRoute(builder: (context) => ChatHomeScreen()),
            // );
          }
        },
        selectedLabelStyle: TextStyle(fontSize: 14),
        // Selected label style
        unselectedLabelStyle: TextStyle(fontSize: 10), // Unselected label style
      ),
    );
  }
}

class ExploreItem extends StatefulWidget {
  final IconData icon;
  final String label;

  ExploreItem({required this.icon, required this.label});

  @override
  _ExploreItemState createState() => _ExploreItemState();
}

class _ExploreItemState extends State<ExploreItem> {
  Color _containerColor = Colors.grey[200]!; // Initial background color

  void _changeColorOnTap() {
    setState(() {
      _containerColor = Colors.grey[300]!; // Change to a slightly darker color
    });

    // Revert the color back after a delay to simulate the click effect
    Future.delayed(Duration(milliseconds: 100), () {
      setState(() {
        _containerColor = Colors.grey[200]!; // Reset back to original color
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _changeColorOnTap, // Change color when tapped
      child: Container(
        padding: EdgeInsets.only(top: 16, bottom: 16, right: 30, left: 10),
        decoration: BoxDecoration(
          color: _containerColor, // Update background color on click
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 28, color: Colors.blue),
            SizedBox(width: 8),
            Text(widget.label, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
