import 'package:flutter/material.dart';
import 'package:neighborhood_connect/screens/chat/chat_screen.dart';
import 'package:neighborhood_connect/screens/createPost/post_creation_screen.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart';
import 'package:neighborhood_connect/screens/marketplace/marketplace_screen.dart';
import 'package:neighborhood_connect/screens/marketplace_home_screen.dart';
import 'package:neighborhood_connect/screens/search/search_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  @override
  _MainNavigationContainerState createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  // Instantiate your five screens once so state is preserved.
  final List<Widget> _screens = [
    HomeScreen(),
    SearchScreen(),
    PostCreationScreen(),
    MarketplaceHomeScreen(),
    ChatListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using an IndexedStack keeps all screens alive and preserves their state.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
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
            label: 'Sale',
            tooltip: ' Sale',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add),
            label: 'Chat',
            tooltip: 'Chat',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedLabelStyle: TextStyle(fontSize: 14),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
    );
  }
}
