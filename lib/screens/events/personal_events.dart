import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:neighborhood_connect/screens/events/event_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/event_screen.dart';
import 'package:neighborhood_connect/screens/events/view_event.dart';

class YourEventsScreen extends StatefulWidget {
  @override
  _YourEventsScreenState createState() => _YourEventsScreenState();
}

class _YourEventsScreenState extends State<YourEventsScreen> {
  String searchQuery = "";
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Shadow color
                offset: Offset(0, 4), // Shadow offset
                blurRadius: 8, // Blur effect
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            scrolledUnderElevation: 0,
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200], // Background color of the search field
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val.toLowerCase();
                  });
                },
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(Icons.add_circle_outline),
                  iconSize: 30,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateEventScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                Center(
                    child: Text("No events found",
                        style: TextStyle(fontSize: 18))),
              ],
            );
          }

          final events = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async {
              // With a stream, this is optional; you could also use it to show a pull-to-refresh UI.
            },
            child: ListView.builder(
              padding: EdgeInsets.all(10),
              itemCount: events.length,
              itemBuilder: (context, index) {
                var event = events[index].data() as Map<String, dynamic>;
                String eventId = events[index].id; // Get event document ID

                if (searchQuery.isNotEmpty &&
                    !event['title'].toLowerCase().contains(searchQuery)) {
                  return SizedBox.shrink();
                }

                return _buildEventCard(event, eventId);
              },
            ),
          );
        },
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        // Highlight selected with blue
        unselectedItemColor: Colors.grey,
        // Unselected items in grey
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.public), // Globe icon for Public Events
            label: 'Public Events',
            tooltip: 'View public events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // User icon for Your Events
            label: 'Your Events',
            tooltip: 'View your events',
          ),
        ],
        currentIndex: 1,
        // Public Events selected by default
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventsScreen()),
            );
          }
        },
        selectedLabelStyle:
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, String eventId) {
    String title = event['title'];
    String location = event['address'];
    DateTime eventDate = event['timestamp'].toDate();
    String formattedDate =
        DateFormat('MMM dd, yyyy - hh:mm a').format(eventDate);
    String imageUrl = (event['pictures'] as List).isNotEmpty
        ? event['pictures'][0]
        : "https://via.placeholder.com/400";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewEvent(eventId: eventId, isPersonal: true),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.darken,
            ),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
