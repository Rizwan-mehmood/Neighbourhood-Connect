import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/rendering.dart';
import 'package:neighborhood_connect/screens/events/event_screen.dart';
import 'package:neighborhood_connect/screens/home/home_screen.dart';
import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:neighborhood_connect/screens/search/search_screen.dart';
import 'package:neighborhood_connect/screens/createPost/post_creation_screen.dart';
import 'package:neighborhood_connect/screens/notification/notification_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  @override
  _MarketplaceScreenState createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String? _userProfileImageUrl;
  String _userNameInitial = '';
  String _userName = '';
  bool _isSidebarOpen = false;
  int unreadNotifications = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> fetchUnreadNotifications() async {
    try {
      // Get the current user's ID
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        // If no user is logged in, handle gracefully
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }

      final userId = currentUser.uid;
      // Check if the user has a document in the `notifications` collection
      final userNotificationDoc = await FirebaseFirestore.instance
          .collection('notification') // Parent notifications collection
          .doc(userId) // Match docId with current user ID
          .get();
      if (!userNotificationDoc.exists) {
        // If no matching document exists
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }
      // Fetch the nested `notifications` collection
      final nestedNotificationsSnapshot = await FirebaseFirestore.instance
          .collection('notification')
          .doc(userId)
          .collection('notifications') // Nested collection
          .get();

      if (nestedNotificationsSnapshot.docs.isEmpty) {
        // If the nested collection is empty
        setState(() {
          unreadNotifications = 0;
        });
        return;
      }
      // Count notifications where `isRead` is false
      int count = nestedNotificationsSnapshot.docs
          .where((doc) => doc.data()['isRead'] == false)
          .length;

      setState(() {
        unreadNotifications = count;
      });
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        unreadNotifications = 0; // Default to 0 on error
      });
    }
  }

  Future<void> initialize() async {
    await _fetchUserProfile();
    await fetchUnreadNotifications();
  }

  int _currentTabIndex = 0;
  List<String> _tabs = [
    "All Listings",
    "Your Listings",
    "Listings Chat",
    "Saved Listings"
  ];
  List<String> _categories = [
    "All Categories",
    "Electronics",
    "Furniture",
    "Furniture",
    "Furniture",
    "Furniture",
    "Furniture",
    "Clothing",
    "Books",
    "Toys"
  ];
  String _selectedCategory = "All Categories";

  void _showCategoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400, // Fixed height in pixels
          child: Column(
            children: [
              // Draggable Indicator
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // CATEGORIES Heading
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "CATEGORIES",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
              // Categories List
              Expanded(
                child: ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: Icon(
                        Icons.category,
                        color: _categories[index] == _selectedCategory
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      title: Text(
                        _categories[index],
                        style: TextStyle(
                          color: _categories[index] == _selectedCategory
                              ? Colors.blue
                              : Colors.black,
                          fontWeight: _categories[index] == _selectedCategory
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: _categories[index] == _selectedCategory
                          ? Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCategory = _categories[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _userProfileImageUrl = userProfile[
            'profilePicture']; // profilePicture field in user document
        _userNameInitial = userProfile['firstName'].isNotEmpty
            ? userProfile['firstName'][0]
            : '';
        _userName = userProfile['firstName'] + ' ' + userProfile['lastName'];
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _viewProfile() {
    Navigator.pushNamed(context, '/profile');
  }

  void _viewEvents() {
    Navigator.pushNamed(context, '/events');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile Icon (First letter or Profile Picture)
            GestureDetector(
              onTap: _toggleSidebar,
              child: CircleAvatar(
                radius: 20, // Adjusted size
                backgroundImage: _userProfileImageUrl != null &&
                        _userProfileImageUrl!.isNotEmpty
                    ? NetworkImage(_userProfileImageUrl!)
                    : null,
                child: _userProfileImageUrl == null ||
                        _userProfileImageUrl!.isEmpty
                    ? Text(_userNameInitial)
                    : null,
              ),
            ),
            // Search Bar
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(30),
                        right: Radius.circular(30),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  ),
                ),
              ),
            ),
            // Add Connection Icon
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationScreen()));
                  },
                ),
                Positioned(
                  right: 8,
                  // Adjust the position to align with the icon
                  top: 2,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadNotifications > 10
                            ? '10+'
                            : unreadNotifications.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
        automaticallyImplyLeading:
            false, // Make sure the back arrow doesn't appear automatically
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                Container(
                  // height: 70, // Fixed height for tabs
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_tabs.length, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentTabIndex = index;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0), // Horizontal margins
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _currentTabIndex == index
                                          ? Colors.black
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _tabs[index],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _currentTabIndex == index
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                Divider(
                  color: Colors.grey[300],
                  height: 1,
                  thickness: 1,
                ),
                // Spacer to separate tabs and labels
                SizedBox(height: 8),

                // Labels (Chips Row)
                Container(
                  height: 60, // Fixed height for labels
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showCategoryBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 8.0),
                              margin: const EdgeInsets.only(right: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_selectedCategory),
                                  Icon(Icons.arrow_drop_down),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text("Free"),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            margin: const EdgeInsets.only(right: 8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text("Discounted"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(
                  color: Colors.grey[300],
                  height: 1,
                  thickness: 1,
                ),

                // Spacer before products section
                SizedBox(height: 8),

                // Products Section
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('marketplace')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final products = snapshot.data!.docs;
                        return GridView.builder(
                          // This makes the GridView scrollable
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                // Navigate to the product details screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProductDetailScreen(
                                        product: products[index]),
                                  ),
                                );
                              },
                              child: _buildProductItem(
                                  products[index]), // Your existing item widget
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          if (_isSidebarOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 250,
              child: Drawer(
                child: Column(
                  children: [
                    Container(
                      color: Colors.purple,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back,
                                size: 30, color: Colors.white),
                            onPressed: _toggleSidebar,
                          ),
                        ),
                      ),
                    ),
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                      ),
                      currentAccountPicture: CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            _userProfileImageUrl?.isNotEmpty == true
                                ? NetworkImage(_userProfileImageUrl!)
                                : null,
                        child: _userProfileImageUrl == null ||
                                _userProfileImageUrl!.isEmpty
                            ? Text(
                                _userNameInitial,
                                style: TextStyle(
                                    fontSize: 24, color: Colors.white),
                              )
                            : null,
                      ),
                      accountName: Text(
                        _userName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      accountEmail: SizedBox.shrink(),
                    ),
                    ListTile(
                      leading: Icon(Icons.person, color: Colors.black),
                      title: Text('View Profile'),
                      onTap: _viewProfile,
                    ),
                    ListTile(
                      leading: Icon(Icons.event, color: Colors.black),
                      title: Text('Events'),
                      onTap: _viewEvents,
                    ),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.black),
                      title: Text('Settings'),
                      onTap: () {
                        // Navigate to settings screen
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.black),
                      title: Text('Sign Out'),
                      onTap: _signOut,
                    ),
                  ],
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
      //   currentIndex: 3,
      //   onTap: (index) {
      //     if (index == 0) {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (context) => HomeScreen()),
      //       );
      //     }
      //
      //     if (index == 1) {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (context) => EventsScreen()),
      //       );
      //     }
      //     if (index == 2) {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (context) => PostCreationScreen()),
      //       );
      //     }
      //     if (index == 4) {
      //       // Navigator.push(
      //       //   context,
      //       //   MaterialPageRoute(builder: (context) => ChatHomeScreen()),
      //       // );
      //     }
      //   },
      //   selectedLabelStyle: TextStyle(fontSize: 14),
      //   // Selected label style
      //   unselectedLabelStyle: TextStyle(fontSize: 10), // Unselected label style
      // ),
    );
  }

  Widget _buildProductItem(DocumentSnapshot product) {
    // Check if imageUrl array is not empty, else provide a fallback image
    String firstImageUrl = (product['imageUrl'] is List &&
            product['imageUrl'].isNotEmpty)
        ? product['imageUrl'][0]
        : 'https://via.placeholder.com/250'; // Fallback URL if no images are available

    return Container(
      margin: EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              firstImageUrl,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "PKR ${product['price']}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            product['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                "${product['time']} • ${product['distance']} km",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Spacer(),
              Text(
                product['location'],
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final dynamic product; // The product data passed from the previous screen

  ProductDetailScreen({required this.product});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late GoogleMapController mapController;
  late LatLng productLocation;

  @override
  void initState() {
    super.initState();
    productLocation =
        LatLng(31.33, 73.98); // Default location (adjust as needed)
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(product['userId']) // Use the userId as the document ID
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('User data not found.'));
        }

        final user = snapshot.data!.data() as Map<String, dynamic>;

        // Ensure the location field is correctly handled as LatLng
        if (product['location'] != null && product['location'] is List) {
          productLocation = LatLng(
            product['location'][0] is String
                ? double.tryParse(product['location'][0]) ??
                    31.33 // Default value
                : product['location'][0],
            product['location'][1] is String
                ? double.tryParse(product['location'][1]) ??
                    73.98 // Default value
                : product['location'][1],
          );
        }

        // Ensure price and distance are properly handled as double
        double price = product['price'] is String
            ? double.tryParse(product['price']) ?? 0.0
            : product['price'].toDouble();

        double distance = product['distance'] is String
            ? double.tryParse(product['distance']) ?? 0.0
            : product['distance'].toDouble();

        return Scaffold(
          appBar: AppBar(
            title: Text('Product Details'),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context); // Go back to the previous screen
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.favorite_border),
                onPressed: () {
                  // Save listing action
                },
              ),
            ],
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Carousel
                  Stack(
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 300,
                          enlargeCenterPage: true,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          enableInfiniteScroll:
                              true, // Set to true if you want infinite scroll
                        ),
                        items: (product['imageUrl'] is List &&
                                product['imageUrl'].isNotEmpty)
                            ? product['imageUrl'].map<Widget>((item) {
                                return Image.network(
                                  item,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              }).toList()
                            : [
                                // Fallback to a default image if no URLs are found
                                Image.network(
                                  'https://via.placeholder.com/300',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ],
                      ),
                    ],
                  ),

                  // Product Title
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      product['title'],
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Product Price
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'PKR ${price.toString()}',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 40),

                  // User Information
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              NetworkImage(user['profilePicture'] ?? ''),
                          radius: 20,
                        ),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user['firstName']} ${user['lastName']}',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${product['location']} - ${distance.toString()} mi away',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                  // Product Description (with "more" functionality)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      product['description'],
                      style: TextStyle(fontFamily: 'Arial', fontSize: 16),
                    ),
                  ),

                  SizedBox(height: 10),
                  // Listing Time
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${product['time']}',
                      style: TextStyle(color: Colors.black45, fontSize: 18),
                    ),
                  ),

                  SizedBox(height: 20),
                  // Send Message Section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2), // Shadow position
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Send Message Header
                        Row(
                          children: [
                            Icon(Icons.message, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                              'Send ${user['firstName']} a message',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),

                        // TextField with Send Button inside
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(
                                    text: 'Hi, is this still available?'),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () {
                                // Handle sending message
                              },
                              style: ElevatedButton.styleFrom(
                                shape: CircleBorder(),
                                padding: EdgeInsets.all(12),
                                backgroundColor:
                                    Colors.blue, // Background color
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                  // Google Map Section
                  Container(
                    height: 300,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: productLocation,
                        zoom: 14.0,
                      ),
                      mapType: MapType.hybrid, // Set the map type to Hybrid
                      onMapCreated: (GoogleMapController controller) {
                        mapController = controller;
                      },
                      markers: {
                        Marker(
                          markerId: MarkerId('product-location'),
                          position: productLocation,
                          infoWindow: InfoWindow(
                            title: 'Product Location',
                          ),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
