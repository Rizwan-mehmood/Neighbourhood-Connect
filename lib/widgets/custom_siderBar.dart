import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class CustomDrawer extends StatelessWidget {
  final String profilePicture;
  final String firstName;
  final String lastName;

  CustomDrawer({
    required this.profilePicture,
    required this.firstName,
    required this.lastName,
  });

  // Sign out function
  Future<void> _signOut(BuildContext context) async {
    Navigator.pushNamed(context, '/logout');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: GestureDetector(
        onTap: () {}, // Disable the default tap behavior
        child: Material(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(height: 25),
              ListTile(
                leading: Icon(Icons.arrow_back, color: Colors.black),
                title: Text("Close Sidebar"),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                },
              ),
              Divider(),
              // Profile Circle in the center with user's image or initial
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: profilePicture.isNotEmpty
                          ? CachedNetworkImageProvider(profilePicture)
                          : null,
                      child: profilePicture.isEmpty
                          ? Text(
                              firstName.isNotEmpty ? firstName[0] : '?',
                              style:
                                  TextStyle(fontSize: 30, color: Colors.black),
                            )
                          : null,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '$firstName $lastName',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Divider(),
              // ListTiles for Profile, Events, Settings
              AbsorbPointer(
                absorbing: false, // Allow taps to these ListTiles
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.blue[600]),
                      title: Text('Profile',
                          style: TextStyle(color: Colors.black)),
                      trailing: Icon(Icons.chevron_right, color: Colors.black),
                      onTap: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.grey[600]),
                      title: Text('Settings',
                          style: TextStyle(color: Colors.black)),
                      trailing: Icon(Icons.chevron_right, color: Colors.black),
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ],
                ),
              ),
              Divider(),
              Spacer(),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.red[600]),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red[600]),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.red[600]),
                onTap: () {
                  // Handle sign-out
                  _signOut(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
