import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:neighborhood_connect/screens/events/all_events.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart';

class CreateEventHelper extends StatefulWidget {
  final Map<String, dynamic> eventData;

  CreateEventHelper({required this.eventData});

  @override
  _CreateEventHelperState createState() => _CreateEventHelperState();
}

class _CreateEventHelperState extends State<CreateEventHelper> {
  late Cloudinary cloudinary;
  bool isUploading = true;
  List<String> mediaUrls = [];
  bool isLocationFetched = false;

  @override
  void initState() {
    super.initState();
    cloudinary = Cloudinary.signedConfig(
      apiKey: '882933186912216',
      apiSecret: 'anCDfBG-xr6oKRQGyVzoRwvnNuo',
      cloudName: 'drmm9icnp',
    );
  }

  Future<void> uploadMedia() async {
    List<String> uploadedUrls = [];
    for (var media in widget.eventData['images']) {
      if (media is String && File(media).existsSync()) {
        File file = File(media);
        final response = await cloudinary.upload(file: file.path);
        if (response.isSuccessful) {
          uploadedUrls.add(response.secureUrl!);
        } else {
          Fluttertoast.showToast(msg: "Failed to upload media");
        }
      }
    }
    setState(() {
      mediaUrls = uploadedUrls;
    });
  }

  Future<String?> getCurrentUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> saveEventData() async {
    try {
      String title = widget.eventData['eventName'];
      String location = widget.eventData['address'];
      GeoPoint geoPointLocation = widget.eventData['location'];
      dynamic dateInput = widget.eventData['date'];
      String time = widget.eventData['time']; // E.g., "03:00 PM"
      String eventType = widget.eventData['eventType'];
      String category = widget.eventData['category'];
      String price = widget.eventData['price'] ?? 'N/A';
      String? userId = await getCurrentUserId();

      DateTime date =
          dateInput is String ? DateTime.parse(dateInput) : dateInput;
      if (userId != null) {
        // Convert time to 24-hour format
        List<String> timeParts =
            time.split(' '); // Splits "03:00 PM" into ["03:00", "PM"]
        String hourMinute = timeParts[0]; // "03:00"
        String period = timeParts[1]; // "PM"

        List<String> hourMinuteParts =
            hourMinute.split(':'); // Splits "03:00" into ["03", "00"]
        int hour = int.parse(hourMinuteParts[0]);
        int minute = int.parse(hourMinuteParts[1]);

        // Adjust hour for PM times
        if (period == "PM" && hour != 12) {
          hour += 12; // Convert to 24-hour format
        } else if (period == "AM" && hour == 12) {
          hour = 0; // Midnight case
        }

        DateTime combinedDateTime =
            DateTime(date.year, date.month, date.day, hour, minute);

        CollectionReference events =
            FirebaseFirestore.instance.collection('events');
        await events.add({
          'title': title,
          'location': geoPointLocation,
          'address': location,
          'timestamp': Timestamp.fromDate(combinedDateTime),
          'eventType': eventType,
          'category': category,
          'price': price,
          'pictures': mediaUrls,
          'createdAt': Timestamp.now(),
          'userId': userId,
          'coming_ids': [],
          'notComing_ids': []
        });

        Fluttertoast.showToast(msg: "Event created successfully!");
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => AllEvents()));
      } else {
        Fluttertoast.showToast(
            msg: "User not logged in or location not available");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving event data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isUploading
            ? Lottie.asset('assets/lottie/progress.json',
                width: 150, height: 150)
            : SizedBox.shrink(),
      ),
    );
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (widget.eventData['images'] != null &&
        widget.eventData['images'].isNotEmpty) {
      await uploadMedia();
    }
    await saveEventData();
  }
}
