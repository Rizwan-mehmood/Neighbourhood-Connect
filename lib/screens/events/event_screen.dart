import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:neighborhood_connect/screens/chat/chat_screen.dart';
import 'package:neighborhood_connect/screens/createPost/post_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/all_events.dart';
import 'dart:convert';

import 'package:neighborhood_connect/screens/events/event_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/personal_events.dart';
import 'package:neighborhood_connect/screens/events/view_event.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart';
import 'package:neighborhood_connect/screens/marketplace/marketplace_screen.dart';
import 'package:neighborhood_connect/screens/search/search_screen.dart';
import 'package:neighborhood_connect/widgets/custom_events_appBar.dart';
import 'package:neighborhood_connect/widgets/custom_siderBar.dart';

class EventsScreen extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  DateTime selectedDate = DateTime.now();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _searchFocusNode = FocusNode();
  bool isLoading = false;
  List<Map<String, dynamic>> events = [];
  bool _isUserDataLoading = true;
  String bio = "";
  String firstName = "";
  String lastName = "";
  String email = "";
  String profilePicture = "";
  bool isActive = false;
  GeoPoint? savedLocation;

  // Search query to filter events
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          bio = userDoc['bio'] ?? '';
          firstName = userDoc['firstName'] ?? '';
          lastName = userDoc['lastName'] ?? '';
          email = userDoc['email'] ?? '';
          profilePicture = userDoc['profilePicture'] ?? '';
          isActive = userDoc['isActive'] ?? false;
          savedLocation = userDoc['location'] ?? GeoPoint(0.0, 0.0);
        });
      }
    }
  }

  Future<void> _fetchEventsForDate(DateTime date) async {
    await deleteExpiredEvents();
    setState(() {
      isLoading = true;
    });

    // Get the user's current location
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );
    // Fetch the current position
    Position userPosition =
        await Geolocator.getCurrentPosition(locationSettings: locationSettings);

    double userLat = userPosition.latitude;
    double userLng = userPosition.longitude;

    // Set the start and end of the selected date
    DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Convert start and end of the day to Firebase Timestamps
    Timestamp startTimestamp = Timestamp.fromDate(startOfDay);
    Timestamp endTimestamp = Timestamp.fromDate(endOfDay);

    try {
      // Query Firestore for events on the selected date
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      // Fetch events and address data
      List<Map<String, dynamic>> fetchedEvents = [];
      for (var doc in snapshot.docs) {
        GeoPoint eventLocation = doc['location'];
        double distance = _calculateDistance(
          userLat,
          userLng,
          eventLocation.latitude,
          eventLocation.longitude,
        );

        // Filter events within 20 km
        if (distance <= 20) {
          Map<String, dynamic> event = {
            'title': doc['title'],
            'timestamp': doc['timestamp'],
            'location': doc['location'],
            'pictures': doc['pictures'],
            'id': doc.id,
          };

          // Fetch the location address from GeoPoint
          String address = await _getAddressFromLatLng(eventLocation);
          event['locationAddress'] = address;

          fetchedEvents.add(event);
        }
      }

      setState(() {
        events = fetchedEvents;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching events: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // Earth radius in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<String> _getAddressFromLatLng(GeoPoint geoPoint) async {
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
  void initState() {
    super.initState();
    _getUserData().then((_) {
      setState(() {
        _isUserDataLoading = false;
      });
    });
    _fetchEventsForDate(selectedDate);
  }

  Future<void> _refreshEvents() async {
    setState(() {
      isLoading = true;
    });
    await _fetchEventsForDate(selectedDate);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> deleteExpiredEvents() async {
    DateTime currentDate = DateTime.now();
    QuerySnapshot eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .where('timestamp', isLessThan: currentDate)
        .get();
    for (var eventDoc in eventsSnapshot.docs) {
      try {
        await eventDoc.reference.delete();
      } catch (e) {
        print('Error deleting event: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserDataLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Compute search results by filtering the events based on the search query.
    final List<Map<String, dynamic>> searchResults = events.where((event) {
      final title = (event['title'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode()); // Dismiss keyboard
        if (_scaffoldKey.currentState!.isDrawerOpen) {
          Navigator.pop(context); // Close the drawer if open
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        appBar: CustomEventsAppBar(
          profilePicture: profilePicture,
          firstName: firstName,
          scaffoldKey: _scaffoldKey,
          searchController: _searchController,
          // provide your TextEditingController
          searchFocusNode: _searchFocusNode,
          // provide your FocusNode
          onSearchChanged: (value) {
            // handle the search change here
          },
        ),
        drawer: CustomDrawer(
          profilePicture: profilePicture,
          firstName: firstName,
          lastName: lastName,
        ),
        // Wrap the main body in a Stack so that the search results overlay is positioned absolutely.
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshEvents,
              child: DefaultTabController(
                length: 2,
                initialIndex: 0, // Default to Public Events
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        indicatorColor: Colors.blue,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(
                            text: 'Public Events',
                          ),
                          Tab(
                            text: 'Your Events',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Public Events Content
                          SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                  height: 1,
                                ),
                                // Categories and All Events Row
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Upcoming Events',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    AllEvents()),
                                          );
                                        },
                                        child: Text(
                                          'All Events',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 60,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 10,
                                    itemBuilder: (context, index) {
                                      DateTime date = DateTime.now()
                                          .add(Duration(days: index));
                                      bool isSelected = date.day ==
                                              selectedDate.day &&
                                          date.month == selectedDate.month &&
                                          date.year == selectedDate.year;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedDate = date;
                                          });
                                          _fetchEventsForDate(selectedDate);
                                        },
                                        child: Container(
                                          width: 60,
                                          padding: EdgeInsets.all(8),
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 5),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border:
                                                Border.all(color: Colors.blue),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                DateFormat('dd').format(date),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('EEE').format(date),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 15),
                                Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                                // Main events list container
                                Container(
                                  height: 280,
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: isLoading
                                          ? [
                                              Center(
                                                  child:
                                                      CircularProgressIndicator())
                                            ]
                                          : events.isEmpty
                                              ? [
                                                  Center(
                                                      child: Text(
                                                          'No events found'))
                                                ]
                                              : events.map((event) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ViewEvent(
                                                            eventId:
                                                                event['id'],
                                                            isPersonal: false,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Card(
                                                      margin:
                                                          EdgeInsets.symmetric(
                                                              vertical: 8,
                                                              horizontal: 16),
                                                      color: Colors.white,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              margin: EdgeInsets
                                                                  .all(10),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Text(
                                                                    event[
                                                                        'title'],
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                      height:
                                                                          8),
                                                                  Row(
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .calendar_today,
                                                                          size:
                                                                              16),
                                                                      SizedBox(
                                                                          width:
                                                                              5),
                                                                      Text(
                                                                        DateFormat('MMMM dd, yyyy')
                                                                            .format(event['timestamp'].toDate()),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  SizedBox(
                                                                      height:
                                                                          5),
                                                                  Row(
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .location_on,
                                                                          size:
                                                                              16),
                                                                      SizedBox(
                                                                          width:
                                                                              5),
                                                                      Expanded(
                                                                        child:
                                                                            Text(
                                                                          event[
                                                                              'locationAddress'],
                                                                          softWrap:
                                                                              true,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .only(
                                                              topRight: Radius
                                                                  .circular(12),
                                                              bottomRight:
                                                                  Radius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            child: event[
                                                                        'pictures']
                                                                    .isNotEmpty
                                                                ? Container(
                                                                    width: 100,
                                                                    height: 100,
                                                                    child: Image
                                                                        .network(
                                                                      event['pictures']
                                                                          [0],
                                                                      fit: BoxFit
                                                                          .cover,
                                                                    ),
                                                                  )
                                                                : Container(
                                                                    width: 100,
                                                                    height: 100,
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Icon(
                                                                        Icons
                                                                            .image,
                                                                        size:
                                                                            40,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                    ),
                                                                  ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Your Events Content
                          YourEventsContent(), // See step 2 below.
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Search results overlay – absolutely positioned so it doesn't affect underlying content.
            if (_searchQuery.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Material(
                  elevation: 4,
                  child: Container(
                    color: Colors.white,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return ListTile(
                          title: Text(result['title']),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewEvent(
                                  eventId: result['id'],
                                  isPersonal: false,
                                ),
                              ),
                            );
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        // bottomNavigationBar: BottomNavigationBar(
        //   backgroundColor: Colors.white,
        //   selectedItemColor: Colors.black,
        //   unselectedItemColor: Colors.grey,
        //   type: BottomNavigationBarType.fixed,
        //   // Ensure both icons and labels are shown
        //   items: [
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.home),
        //       label: 'Home',
        //       tooltip: 'Home',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.event),
        //       label: 'Events',
        //       tooltip: 'Events',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.add),
        //       label: 'Add Post',
        //       tooltip: 'Add Post',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.store),
        //       label: 'For Sale',
        //       tooltip: 'For Sale',
        //     ),
        //     BottomNavigationBarItem(
        //       icon: Icon(Icons.group_add),
        //       label: 'Chat',
        //       tooltip: 'Chat',
        //     ),
        //   ],
        //
        //   currentIndex: 1,
        //   onTap: (index) {
        //     if (index == 0) {
        //       Navigator.push(context,
        //           MaterialPageRoute(builder: (context) => HomeScreen()));
        //     }
        //     if (index == 2) {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => PostCreationScreen()),
        //       );
        //     }
        //     if (index == 3) {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => MarketplaceScreen()),
        //       );
        //     }
        //     if (index == 4) {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(builder: (context) => ChatListScreen()),
        //       );
        //     }
        //   },
        //   selectedLabelStyle: TextStyle(fontSize: 14),
        //   // Selected label style
        //   unselectedLabelStyle:
        //       TextStyle(fontSize: 10), // Unselected label style
        // ),
      ),
    );
  }
}

class YourEventsContent extends StatelessWidget {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Show loader while data is being fetched.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        // If no data or empty list, show "No events found" in the center.
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              "No events found",
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final events = snapshot.data!.docs;

        return RefreshIndicator(
          onRefresh: () async {
            // Optionally add refresh logic here.
          },
          child: ListView.builder(
            padding: EdgeInsets.all(10),
            itemCount: events.length,
            itemBuilder: (context, index) {
              var event = events[index].data() as Map<String, dynamic>;
              String eventId = events[index].id;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewEvent(eventId: eventId, isPersonal: true),
                    ),
                  );
                },
                child: _buildEventCard(event, eventId),
              );
            },
          ),
        );
      },
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

    return Container(
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
    );
  }
}
