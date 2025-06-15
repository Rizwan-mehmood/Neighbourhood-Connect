import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewEvent extends StatefulWidget {
  final String eventId;
  final bool isPersonal;

  ViewEvent({required this.eventId, required this.isPersonal});

  @override
  _ViewEventState createState() => _ViewEventState();
}

class _ViewEventState extends State<ViewEvent> {
  Map<String, dynamic>? event;
  bool isLoading = true;
  String? userSelection;
  int comingCount = 0;
  int notComingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchEventDetails();
  }

  Future<void> _fetchEventDetails() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId)
        .get();

    if (doc.exists) {
      setState(() {
        event = doc.data() as Map<String, dynamic>;

        // Set initial selection based on the current user's ID
        String userId = FirebaseAuth.instance.currentUser!.uid;
        if ((event?['coming_ids'] as List).contains(userId)) {
          userSelection = 'Coming';
        } else if ((event?['notComing_ids'] as List).contains(userId)) {
          userSelection = 'Not Coming';
        }

        // Update the coming and not coming counts
        comingCount = (event?['coming_ids'] as List?)?.length ?? 0;
        notComingCount = (event?['notComing_ids'] as List?)?.length ?? 0;

        isLoading = false;
      });
    }
  }

  void _updateAttendance(String choice) async {
    if (userSelection == choice) return; // Prevent re-selection

    // Store the previous selection before updating the state
    String? previousSelection = userSelection;

    // Determine the fields to increment and decrement based on the choice and previous selection
    String fieldToIncrement =
        choice == "Coming" ? 'coming_ids' : 'notComing_ids';
    String fieldToDecrement =
        previousSelection == "Coming" ? 'coming_ids' : 'notComing_ids';

    // Set up the user ID to add/remove from the collections
    String userId = FirebaseAuth.instance.currentUser!.uid;

    // Update the counts immediately in the UI
    setState(() {
      if (previousSelection == null) {
        // If no selection has been made yet, just increment the selected choice
        if (choice == "Coming") {
          comingCount++;
        } else {
          notComingCount++;
        }
      } else {
        // If there was a previous selection, update the counts accordingly
        if (choice == "Coming") {
          comingCount++;
          if (previousSelection == "Not Coming") notComingCount--;
        } else {
          notComingCount++;
          if (previousSelection == "Coming") comingCount--;
        }
      }
      // Update the userSelection with the current choice
      userSelection = choice;
    });

    // Firestore reference for the event document
    var eventRef =
        FirebaseFirestore.instance.collection('events').doc(widget.eventId);

    // Perform the Firestore updates
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Get the current event document
      DocumentSnapshot eventDoc = await transaction.get(eventRef);

      // Update the attendance counts in Firestore
      transaction.update(eventRef, {
        fieldToIncrement: FieldValue.arrayUnion([userId]),
        if (previousSelection != null)
          fieldToDecrement: FieldValue.arrayRemove([userId]),
      });
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // Local variable to track deletion state.
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Wrap(
                children: <Widget>[
                  // A small drag handle for aesthetics
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Delete Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Are you sure you want to delete this event?',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        child: Text('Cancel'),
                        onPressed: isDeleting
                            ? null
                            : () {
                                Navigator.pop(context); // Close the modal
                              },
                      ),
                      // If deletion is in progress, show a spinner; otherwise show Delete button.
                      isDeleting
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              child: Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () async {
                                // Set the flag to show spinner.
                                setState(() {
                                  isDeleting = true;
                                });
                                try {
                                  // Delete the event from Firebase Firestore.
                                  await FirebaseFirestore.instance
                                      .collection('events')
                                      .doc(widget.eventId)
                                      .delete();
                                  Navigator.pop(context); // Close the modal.
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Event deleted successfully.')),
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  Navigator.pop(context); // Close the modal.
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Error deleting event: $e')),
                                  );
                                }
                              },
                            ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Event Details")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Shadow color
                offset: Offset(0, 4), // Bottom shadow
                blurRadius: 8, // Blur effect
              ),
            ],
          ),
          child: AppBar(
            leading: BackButton(),
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            title: Text(
              "Event Details",
              textAlign: TextAlign.center,
            ),
            actions: widget.isPersonal
                ? [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        // Navigate to Edit Event screen
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmation(context);
                      },
                    ),
                  ]
                : null,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchEventDetails,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Carousel
              if ((event?['pictures'] as List?)?.isNotEmpty ?? false)
                CarouselSlider(
                  items: (event!['pictures'] as List).map<Widget>((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(url,
                          width: double.infinity, fit: BoxFit.cover),
                    );
                  }).toList(),
                  options: CarouselOptions(
                    autoPlay: true,
                    enlargeCenterPage: true,
                    aspectRatio: 16 / 9,
                  ),
                ),
              SizedBox(height: 20),
              Divider(
                color: Colors.grey[200],
                height: 1,
                thickness: 1,
              ),

              // Event Details in a Card
              _buildDetailCard("Title", event?['title']),
              _buildDetailCard("Category", event?['category']),
              _buildDetailCard("Event Type", event?['eventType']),
              _buildDetailCard("Price", "Rs. ${event?['price']}"),
              _buildDetailCard("Address", event?['address']),
              _buildDetailCard(
                  "Date",
                  DateFormat('MMM dd, yyyy - hh:mm a')
                      .format(event!['timestamp'].toDate())),
              SizedBox(height: 20),

              // Coming / Not Coming Bar (Progress Bar)
              _buildStatusBar(comingCount, notComingCount),

              // Coming / Not Coming Buttons
              if (!widget.isPersonal)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton("Coming", Colors.green),
                      _buildActionButton("Not Coming", Colors.red),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildDetailCard(String label, String? value) {
    if (label == "Price" && event?["eventType"] == "Free") {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 5,
      color: Colors.white,
      margin: EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: RichText(
          text: TextSpan(
            text: "$label: ",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
            children: [
              TextSpan(
                  text: value ?? "N/A",
                  style: TextStyle(fontWeight: FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(int comingCount, int notComingCount) {
    double total = comingCount + notComingCount > 0
        ? comingCount + notComingCount.toDouble()
        : 1;
    double comingPercentage = (comingCount / total) * 100;
    double notComingPercentage = (notComingCount / total) * 100;

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10)),
            ),
            Row(
              children: [
                Expanded(
                  flex: comingCount,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  flex: notComingCount,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          "$comingCount Coming | $notComingCount Not Coming",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color) {
    bool isSelected = userSelection == label;

    return ElevatedButton(
      onPressed: () => _updateAttendance(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: TextStyle(fontSize: 16)),
    );
  }
}
