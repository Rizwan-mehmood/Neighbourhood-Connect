import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:neighborhood_connect/widgets/custom_appBar.dart';
import 'package:neighborhood_connect/widgets/custom_siderBar.dart';
import 'package:neighborhood_connect/widgets/post_widget.dart';
import 'package:neighborhood_connect/screens/home/location_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onInitialized; // Made optional (nullable)

  const HomeScreen({Key? key, this.onInitialized}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> posts = [];
  DocumentSnapshot? lastPost;
  bool isLoading = false;
  bool hasMore = true;
  int postLimit = 10;
  bool isLocationDetermined = false;
  String bio = "";
  String firstName = "";
  String lastName = "";
  String email = "";
  String profilePicture = "";
  bool isActive = false;
  GeoPoint? location;
  GeoPoint? savedLocation;
  String currentUserID = "";

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chips data
  final List<String> chipLabels = ['For You', 'Nearby', 'Recent'];
  String selectedChip = 'For You'; // Default selected chip

  @override
  void initState() {
    super.initState();
    _getUserData(); // This will also handle fetching location.
    _scrollController.addListener(_scrollListener);
    _fetchPosts();
  }

  Future<void> _handleRefresh() async {
    Navigator.pushNamed(context, '/refreshScreens');
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
          currentUserID = user.uid;
        });

        // Attempt to fetch the current location
        await _fetchCurrentLocation(user);
        print("CHECKING THE LOGIC");
        widget.onInitialized?.call();
      }
    }
  }

  // Method to get the current location or use Firebase location if permission denied
  Future<void> _fetchCurrentLocation(User user) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled.')));
      setState(() {
        isLocationDetermined = true; // Allow UI rendering after location check
      });
      return;
    }

    // Request location permission
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Location permission denied.')));
      setState(() {
        isLocationDetermined = true; // Allow UI rendering after location check
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission permanently denied.')));
      setState(() {
        isLocationDetermined = true; // Allow UI rendering after location check
      });
      return;
    }

    try {
      // Fetch current position
      LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      Position userPosition = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);

      // If the user allows the location, update the location
      setState(() {
        location = GeoPoint(userPosition.latitude, userPosition.longitude);
      });

      setState(() {
        isLocationDetermined = true; // Allow UI rendering after location check
      });

      _refreshPosts('For You');
    } catch (e) {
      // If an error occurs, use the location from Firebase (fallback)
      print('Error fetching location: $e');
      setState(() {
        location = GeoPoint(0.0, 0.0); // Fallback location if any error occurs
        isLocationDetermined = true; // Allow UI rendering after location check
      });
    }
  }

  Future<void> _fetchPosts() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    try {
      Query query = _firestore.collection('posts').limit(postLimit);

      if (lastPost != null) {
        query = query.startAfterDocument(lastPost!);
      }

      QuerySnapshot querySnapshot = await query.get();

      if (querySnapshot.docs.isNotEmpty) {
        final userLocation = location; // User's current location
        if (userLocation == null) {
          setState(() {
            isLoading = false;
            hasMore = false; // Prevent infinite loading
          });
          return;
        }

        // Load excluded post IDs from SharedPreferences (for deleted posts)
        final prefs = await SharedPreferences.getInstance();
        final deletedPostIds = prefs.getStringList('deletedPosts') ?? [];
        final excludedPostIds =
            deletedPostIds; // Combining deleted and reported posts

        final fetchedPosts = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Add document ID
          return data;
        }).toList();

        // Filter posts based on the selected chip
        List<Map<String, dynamic>> filteredPosts = [];
        var threshold = 15; // Distance threshold in km

        if (selectedChip == 'For You' ||
            selectedChip == 'Nearby' ||
            selectedChip == 'Recent') {
          // Filter posts based on the distance
          filteredPosts = fetchedPosts.where((post) {
            // Exclude posts that are in shared preferences or have 'reported' set to true
            final postId = post['id'];
            final reported = post['reported'] ?? false;

            if (excludedPostIds.contains(postId) || reported) {
              return false; // Exclude this post
            }

            if (post['location'] is GeoPoint) {
              final postLocation = post['location'] as GeoPoint;
              final distance = Geolocator.distanceBetween(
                    userLocation.latitude,
                    userLocation.longitude,
                    postLocation.latitude,
                    postLocation.longitude,
                  ) /
                  1000; // Convert to km

              // Apply distance filter
              if (selectedChip == 'For You' && distance <= threshold) {
                return true;
              } else if (selectedChip == 'Nearby' && distance <= 7) {
                return true;
              } else if (selectedChip == 'Recent') {
                return distance <= threshold;
              }
            }
            return false;
          }).toList();

          // Sort by descending time for 'Recent'
          if (selectedChip == 'Recent') {
            filteredPosts.sort((a, b) {
              final dateA = a['timestamp'] as Timestamp;
              final dateB = b['timestamp'] as Timestamp;
              return dateB.compareTo(dateA); // Sort by descending time
            });
          }
        }

        setState(() {
          posts = filteredPosts;

          if (filteredPosts.length < postLimit) {
            hasMore = false; // No more posts to fetch
          }

          if (querySnapshot.docs.isNotEmpty) {
            lastPost = querySnapshot.docs.last; // Update last fetched post
          }
        });
      } else {
        setState(() {
          hasMore = false; // No more posts
        });
      }
    } catch (e) {
      print("Error fetching posts: $e");
      setState(() {
        hasMore = false; // Prevent infinite loading
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _refreshPosts(String chipLabel) {
    setState(() {
      selectedChip = chipLabel;
      posts.clear(); // Clear existing posts
      lastPost = null; // Reset last fetched post
      hasMore = true; // Allow fetching more posts
    });
    _fetchPosts(); // Fetch posts based on new selection
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        hasMore &&
        !isLoading) {
      _fetchPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wait until location is determined before showing any UI
    if (!isLocationDetermined) {
      return Scaffold(
        backgroundColor: Colors.white, // Set the background color to whitex
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    // Check if the location is (0.0, 0.0)
    bool isLocationUnverified =
        savedLocation?.latitude == 0.0 && savedLocation?.longitude == 0.0;

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
        appBar: CustomAppBar(
          profilePicture: profilePicture,
          firstName: firstName,
          scaffoldKey: _scaffoldKey,
          currentUserId: currentUserID,
        ),
        drawer: CustomDrawer(
          profilePicture: profilePicture,
          firstName: firstName,
          lastName: lastName,
        ),
        body: Column(
          children: [
            // Display location message if the location is unverified (0, 0)
            if (isLocationUnverified) ...[
              Container(
                padding: EdgeInsets.all(12),
                color: Colors.yellow[100], // Yellowish background color
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Align the row items to the start
                  children: [
                    SizedBox(width: 10),
                    // Image on the left
                    SvgPicture.asset(
                      'assets/images/verify_address.svg',
                      height: 40,
                      width: 40,
                    ),
                    const SizedBox(width: 16), // Space between image and text
                    // Text content on the right
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  "You're almost there! To finish joining your neighborhood, ",
                              style: TextStyle(fontSize: 16),
                            ),
                            TextSpan(
                              text: "verify your address",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration
                                    .underline, // Underline the text
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // Navigate to LocationPicker screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => LocationPicker()),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Chips Row
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: chipLabels.map((label) {
                  bool isSelected = selectedChip == label;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        _refreshPosts(label); // Refresh posts based on chip
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Icons.filter_list_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading && posts.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Center(
        child: Text(
          'No posts available',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: posts.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= posts.length) {
          return Center(child: CircularProgressIndicator());
        }
        return PostWidget(
          postData: posts[index],
          currentUserId: FirebaseAuth.instance.currentUser!.uid,
        );
      },
    );
  }
}
