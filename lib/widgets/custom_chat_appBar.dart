import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String profilePicture;
  final String firstName;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final TextEditingController controller;

  const CustomChatAppBar({
    required this.profilePicture,
    required this.firstName,
    required this.scaffoldKey,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => scaffoldKey.currentState?.openDrawer(),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: profilePicture.isNotEmpty
                    ? CachedNetworkImageProvider(profilePicture)
                    : null,
                child: profilePicture.isEmpty
                    ? Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '',
                        style:
                            const TextStyle(fontSize: 20, color: Colors.black))
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => controller.clear(),
                          )
                        : null,
                  ),
                  cursorHeight: 20,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
