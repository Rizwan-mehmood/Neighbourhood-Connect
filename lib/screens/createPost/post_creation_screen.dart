import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:neighborhood_connect/screens/createPost/location_selection_screen.dart';

import '../../widgets/post_creation_helper.dart';

class PostCreationScreen extends StatefulWidget {
  @override
  _PostCreationScreenState createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late GeoPoint? postLocation;
  bool isPublishEnabled = false;
  Map<String, dynamic>? userData;
  String? userLocation;
  bool isLoading = true;
  bool hasFetchedUserData = false;
  List<Map<String, dynamic>> mediaFiles = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!hasFetchedUserData) {
      fetchUserData();
    }
  }

  void _selectMedia() async {
    final List<XFile>? pickedFiles = await _picker.pickMultipleMedia();

    bool showToast = false; // Flag to show the toast message once

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() async {
        for (var pickedFile in pickedFiles) {
          // Check if the file path is not null and is valid
          if (pickedFile.path == null || pickedFile.path.isEmpty) {
            print('Picked file path is invalid: ${pickedFile.path}');
            continue; // Skip this file
          }

          // Check if the file is already in the list
          bool fileExists =
              mediaFiles.any((media) => media['file'].path == pickedFile.path);

          // Add the file only if it's not already in the list
          if (!fileExists) {
            String fileType = '';

            // Check file extension to determine if it's an image or video
            if (pickedFile.path.endsWith('.mp4') ||
                pickedFile.path.endsWith('.mov') ||
                pickedFile.path.endsWith('.avi') ||
                pickedFile.path.endsWith('.mkv')) {
              fileType = 'video';

              // Generate a video thumbnail and save it
              final uint8list = await VideoThumbnail.thumbnailData(
                video: pickedFile.path,
                imageFormat: ImageFormat.JPEG,
                maxWidth: 128, // Specify the width of the thumbnail
                quality: 25, // Set the quality of the thumbnail
              );

              // Save the thumbnail as a file (if you need to store it)
              String thumbnailPath =
                  pickedFile.path + "_thumbnail.jpg"; // Thumbnail path
              File thumbnailFile = File(thumbnailPath);
              await thumbnailFile.writeAsBytes(
                  uint8list); // Write the thumbnail to the file system

              // Add the media with the thumbnail information
              mediaFiles.add({
                'type': fileType,
                'file': File(pickedFile.path),
                'thumbnail': thumbnailFile, // Add the thumbnail file
              });
            } else if (pickedFile.path.endsWith('.jpg') ||
                pickedFile.path.endsWith('.jpeg') ||
                pickedFile.path.endsWith('.png') ||
                pickedFile.path.endsWith('.gif')) {
              fileType = 'image';

              // Add the media file as an image
              mediaFiles.add({
                'type': fileType,
                'file': File(pickedFile.path),
              });
            }

            // Only add if the file is an image or video
            if (fileType.isNotEmpty) {
              setState(() {
                isPublishEnabled = true;
              });
            } else {
              // Show toast message only once
              if (!showToast) {
                Fluttertoast.showToast(
                  msg: "Only images and videos are allowed",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                );
                showToast =
                    true; // Set the flag to prevent further toast messages
              }
            }
          }
        }
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      mediaFiles.removeAt(index);

      // Check if there is text in the input field
      bool hasText = _controller.text.trim().isNotEmpty;

      // If there is no text and no media files left, disable the publish button
      if (mediaFiles.isEmpty && !hasText) {
        isPublishEnabled = false;
      }
    });
  }

  Future<void> fetchUserData() async {
    try {
      // Get current user ID
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          final LocationSettings locationSettings = LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100,
          );
          // Fetch the current position
          Position position = await Geolocator.getCurrentPosition(
              locationSettings: locationSettings);
          GeoPoint? location = GeoPoint(position.latitude, position.longitude);
          String? address;

          address = await _getAddressFromGeoPoint(location);

          setState(() {
            userData = data;
            userLocation = address ?? "Location not available";
            postLocation = location;
            isLoading = false;
            hasFetchedUserData = true;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _publishPost() {
    if (isPublishEnabled) {
      String text = _controller.text.trim();
      Map<String, dynamic> postData = {
        'text': text,
        'mediaFiles': mediaFiles,
        'location': postLocation,
      };

      // Navigate to the helper widget and pass the data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HelperWidget(postData: postData),
        ),
      );
    } else {
      Fluttertoast.showToast(
        msg: "Please add text or media to your post",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
      );
    }
  }

  void _navigateToLocationSelection() async {
    // Navigate to the location selection screen and await the selected location
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationSelectionScreen()),
    );

    if (selectedLocation != null) {
      // Convert the LatLng to a GeoPoint
      final GeoPoint convertedLocation = GeoPoint(
        selectedLocation.latitude,
        selectedLocation.longitude,
      );

      // Fetch the address from the selected location
      final String address = await _getAddressFromLatLng(selectedLocation);

      setState(() {
        // Update the address and location
        userLocation = address;
        postLocation = convertedLocation;
      });
    } else {
      // If no location is selected, provide a fallback
      setState(() {
        userLocation = userLocation ?? "Location not available";
      });
    }
  }

  Future<String> _getAddressFromGeoPoint(GeoPoint geoPoint) async {
    final lat = geoPoint.latitude;
    final lng = geoPoint.longitude;
    final apiKey =
        "AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8"; // Replace with your API key

    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          String? street;
          String? area;
          String? city;

          for (var component in data['results'][0]['address_components']) {
            if (component['types'].contains('route')) {
              street = component['long_name'];
            } else if (component['types'].contains('neighborhood') ||
                component['types'].contains('sublocality') ||
                component['types'].contains('sublocality_level_1')) {
              area = component['long_name'];
            } else if (component['types'].contains('locality')) {
              city = component['long_name'];
            }
          }

          if (street != null && area != null) {
            return "$street, $area";
          } else if (area != null && city != null) {
            return "$area, $city";
          } else if (street != null && city != null) {
            return "$street, $city";
          } else if (area != null) {
            return area;
          } else if (city != null) {
            return city;
          }
        }
      }
      return "Address not found";
    } catch (e) {
      print("Error fetching address: $e");
      return "Address not found";
    }
  }

  Future<String> _getAddressFromLatLng(LatLng geoPoint) async {
    final lat = geoPoint.latitude;
    final lng = geoPoint.longitude;
    final apiKey =
        "AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8"; // Replace with your API key

    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && data['results'].isNotEmpty) {
          String? street;
          String? area;
          String? city;

          for (var component in data['results'][0]['address_components']) {
            if (component['types'].contains('route')) {
              street = component['long_name'];
            } else if (component['types'].contains('neighborhood') ||
                component['types'].contains('sublocality') ||
                component['types'].contains('sublocality_level_1')) {
              area = component['long_name'];
            } else if (component['types'].contains('locality')) {
              city = component['long_name'];
            }
          }

          if (street != null && area != null) {
            return "$street, $area";
          } else if (area != null && city != null) {
            return "$area, $city";
          } else if (street != null && city != null) {
            return "$street, $city";
          } else if (area != null) {
            return area;
          } else if (city != null) {
            return city;
          }
        }
      }
      return "Address not found";
    } catch (e) {
      print("Error fetching address: $e");
      return "Address not found";
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        // Adjusts the body when the keyboard appears
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              title: Row(
                children: [
                  Text(
                    'Create Post',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: EdgeInsets.only(right: 10),
                  child: ElevatedButton(
                    onPressed: isPublishEnabled ? _publishPost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPublishEnabled ? Colors.blue : Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: Size(80, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Publish',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                // Prevent overflow when the keyboard appears
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Circular Profile Container
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                              ),
                              child: userData?['profilePicture'] != null &&
                                      userData!['profilePicture'].isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        userData!['profilePicture'],
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        userData?['firstName'] != null
                                            ? userData!['firstName'][0]
                                                .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          // User Info
                          if (userData != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${userData!['firstName']} ${userData!['lastName']}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      userLocation != null &&
                                              userLocation!.length > 30
                                          ? userLocation!.substring(0, 30) +
                                              '...'
                                          : userLocation ??
                                              "Location not available",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),

                      SizedBox(height: 20),

                      // Post Content Input
                      Container(
                        height: 300,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 20,
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (text) {
                            setState(() {
                              // Enable the publish button if text or media is added
                              isPublishEnabled = text.trim().isNotEmpty ||
                                  mediaFiles.isNotEmpty;
                            });
                          },
                        ),
                      ),

                      // Media Preview Section
                      if (mediaFiles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: mediaFiles.length,
                            itemBuilder: (context, index) {
                              final media = mediaFiles[index];

                              // Check if the file is null
                              if (media['file'] == null) {
                                print('Error: File is null for index $index');
                                return Container(); // Return an empty container or handle it differently
                              }

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: media['type'] == 'image'
                                        ? Image.file(
                                            media['file'],
                                            fit: BoxFit.cover,
                                          )
                                        : Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // Display the video thumbnail as the background
                                              media['thumbnail'] != null
                                                  ? Image.file(
                                                      media['thumbnail'],
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      color: Colors.grey
                                                          .withOpacity(0.5),
                                                    ),
                                              // Overlay the play icon for video
                                              Positioned(
                                                top: 4,
                                                left: 4,
                                                child: Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeMedia(index),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: AnimatedContainer(
            height: 65,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: BottomAppBar(
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(Icons.photo_library,
                          color: Colors.blue, size: 28),
                      onPressed: _selectMedia,
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.location_on, color: Colors.red, size: 28),
                      onPressed: _navigateToLocationSelection,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
