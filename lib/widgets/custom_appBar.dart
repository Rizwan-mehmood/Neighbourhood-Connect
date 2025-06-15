import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String profilePicture;
  final String firstName;
  final GlobalKey<ScaffoldState> scaffoldKey;

  // Pass the current user's ID so you can filter notifications.
  final String currentUserId;

  CustomAppBar({
    required this.profilePicture,
    required this.firstName,
    required this.scaffoldKey,
    required this.currentUserId,
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
                scaffoldKey.currentState?.openDrawer(); // Open the sidebar
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(profilePicture)
                    : null,
                child: profilePicture.isEmpty
                    ? (firstName.isNotEmpty
                        ? Text(
                            firstName[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 20, color: Colors.black),
                          )
                        : const Icon(
                            Icons.person,
                            color: Colors.black,
                          ))
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
            // Notifications icon wrapped with a StreamBuilder to listen to changes
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: currentUserId)
                  .where('read', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int count = 0;
                if (snapshot.hasData) {
                  count = snapshot.data!.docs.length;
                }
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications),
                      onPressed: () {
                        // Add your notification functionality here
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 11,
                        top: 7,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
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
