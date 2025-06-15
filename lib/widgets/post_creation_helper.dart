import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart'; // Import Lottie package

class HelperWidget extends StatefulWidget {
  final Map<String, dynamic> postData; // Data passed to the helper widget

  HelperWidget({required this.postData});

  @override
  _HelperWidgetState createState() => _HelperWidgetState();
}

class _HelperWidgetState extends State<HelperWidget> {
  late Cloudinary cloudinary;
  bool isUploading = true;
  List<String> mediaUrls = [];
  bool isLocationFetched = false;
  GeoPoint? userLocation;

  @override
  void initState() {
    super.initState();
    // Initialize Cloudinary with the provided credentials
    cloudinary = Cloudinary.signedConfig(
      apiKey: '882933186912216',
      apiSecret: 'anCDfBG-xr6oKRQGyVzoRwvnNuo',
      cloudName: 'drmm9icnp',
    );

    // Fetch user location (static in this case for demonstration)
    fetchUserLocation();
  }

  // Function to upload media to Cloudinary
  Future<void> uploadMedia() async {
    List<String> uploadedUrls = [];

    for (var media in widget.postData['mediaFiles']) {
      File file = media['file']; // Assuming media is a file

      // Upload image/video to Cloudinary
      final response = await cloudinary.upload(file: file.path);

      if (response.isSuccessful) {
        uploadedUrls.add(response.secureUrl!);
      } else {
        // Handle upload error
        Fluttertoast.showToast(
          msg: "Failed to upload media",
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    }

    setState(() {
      mediaUrls = uploadedUrls;
    });
  }

  // Function to get current logged-in user's ID
  Future<String?> getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Function to fetch user's current location (this is just an example)
  Future<void> fetchUserLocation() async {
    // Replace this with actual location fetching logic.
    // For demonstration, using a static location:
    setState(() {
      userLocation = widget.postData['location']; // Example location
      isLocationFetched = true;
    });
  }

  // Function to save post data to Firestore
  Future<void> savePostData() async {
    String text = widget.postData['text'];
    String? userId = await getCurrentUserId();

    if (userId != null && isLocationFetched) {
      CollectionReference posts =
          FirebaseFirestore.instance.collection('posts');
      await posts.add({
        'content': text,
        'location': userLocation,
        // User's location
        'mediaUrls': mediaUrls.isNotEmpty ? mediaUrls : [],
        // URLs from Cloudinary if available
        'timestamp': Timestamp.now(),
        // Current timestamp
        'userId': userId,
        // Current user's ID
      });

      // Show success message and navigate back to the home screen
      Fluttertoast.showToast(
        msg: "Post published successfully!",
        toastLength: Toast.LENGTH_SHORT,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      ); // Go back to the home page
    } else {
      // Handle error (user not logged in or location not fetched)
      Fluttertoast.showToast(
        msg: "User not logged in or location not available",
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Full white background
      body: Center(
        child: isUploading
            ? Lottie.asset(
                'assets/lottie/progress.json', // The Lottie animation path
                width: 150, // Set the size of the animation
                height: 150,
                fit: BoxFit.cover,
              )
            : SizedBox.shrink(), // Empty container when the upload is complete
      ),
    );
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    // Check if media files are present in the passed data
    if (widget.postData['mediaFiles'] != null &&
        widget.postData['mediaFiles'].isNotEmpty) {
      await uploadMedia(); // Upload the media to Cloudinary
    }

    // Save post data to Firestore
    await savePostData(); // Save the post data in Firestore
  }
}
