import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:neighborhood_connect/screens/events/event_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/view_event.dart';

/// Custom AppBar that includes a search field.
class CustomEventsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String profilePicture;
  final String firstName;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;

  CustomEventsAppBar({
    required this.profilePicture,
    required this.firstName,
    required this.scaffoldKey,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Padding(
        padding: EdgeInsets.only(left: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                // Open the sidebar drawer
                scaffoldKey.currentState?.openDrawer();
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(profilePicture)
                    : null,
                child: (profilePicture.isEmpty)
                    ? (firstName.isNotEmpty
                        ? Text(
                            firstName[0].toUpperCase(),
                            style: TextStyle(fontSize: 20, color: Colors.black),
                          )
                        : Icon(Icons.person, color: Colors.black))
                    : null,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  cursorHeight: 20,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CreateEventScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
