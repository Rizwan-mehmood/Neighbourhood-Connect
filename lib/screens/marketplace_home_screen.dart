import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:geolocator/geolocator.dart' as geo;

// import 'package:dreamflow/theme.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import '../utils/firebase_mock.dart';
import 'item_detail_screen.dart';
import 'add_edit_listing_screen.dart';
import 'my_listings_screen.dart';
import 'marketplace_chat_screen.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key});

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen>
    with SingleTickerProviderStateMixin {
  final MarketplaceService _marketplaceService = MarketplaceService();
  late TabController _tabController;
  String _selectedCategory = 'all';
  GeoPoint? _userLocation;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getUserLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLoading = true);

    try {
      // 1️⃣ Are the device’s location services on?
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      debugPrint('[getUserLocation] Service enabled? $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('[getUserLocation] Location services are off');
        throw Exception('Location services disabled');
      }

      // 2️⃣ Request / check permission
      geo.LocationPermission permission =
          await geo.Geolocator.requestPermission();
      debugPrint('[getUserLocation] Permission status: $permission');
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[getUserLocation] Permission denied');
        throw Exception('Location permission denied');
      }

      // 3️⃣ Actually fetch the position
      debugPrint('[getUserLocation] Fetching device position...');
      geo.Position pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      debugPrint('[getUserLocation] Got Position → '
          'lat: ${pos.latitude}, lon: ${pos.longitude}');

      // 4️⃣ Set as our GeoPoint
      setState(() {
        _userLocation = GeoPoint(pos.latitude, pos.longitude);
        _isLoading = false;
      });
      return;
    } catch (e, st) {
      debugPrint('[getUserLocation] ERROR: $e\n$st');

      // 5️⃣ Fallback: saved Firebase location
      debugPrint('[getUserLocation] Falling back to Firebase location');
      GeoPoint? savedLoc = await _marketplaceService
          .getUserLocation(FirebaseAuth.instance.currentUser?.uid ?? '');
      debugPrint('[getUserLocation] Firebase returned: $savedLoc');

      setState(() {
        _userLocation = savedLoc ?? const GeoPoint(31.429794, 73.054891);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Marketplace'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MarketplaceChatScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyListingsScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search marketplace...',
                      hintStyle: TextStyle(
                        color: Colors.black45,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.black45,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.black45,
                              ),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
              // Tab bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.black,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black45,
                  tabs: const [
                    Tab(text: 'Buy'),
                    Tab(text: 'Borrow'),
                    Tab(text: 'Free'),
                  ],
                  onTap: (index) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Categories horizontal list
          Container(
            height: 110,
            color: Colors.white,
            child: ListView(
              padding: const EdgeInsets.all(8),
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryItem(theme, 'all', 'All', Icons.apps),
                ...MarketplaceCategory.categories.map(
                  (category) => _buildCategoryItem(
                      theme, category.id, category.name, category.iconData),
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Buy items
                _buildItemsGrid(ListingType.buy),
                // Borrow items
                _buildItemsGrid(ListingType.borrow),
                // Free items
                _buildItemsGrid(ListingType.giveaway),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditListingScreen(),
            ),
          ).then((_) => setState(() {}));
        },
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryItem(
      ThemeData theme, String id, String name, IconData icon) {
    final isSelected = _selectedCategory == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.black45,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.black : Colors.black45,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsGrid(ListingType type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Location services are disabled',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _getUserLocation,
              child: const Text('Enable Location'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<MarketplaceItem>>(
      stream: _searchQuery.isEmpty
          ? _marketplaceService.getNearbyItems(
              _userLocation!,
              category: _selectedCategory == 'all' ? null : _selectedCategory,
              type: type,
            )
          : Stream.fromFuture(_marketplaceService
              .searchMarketplaceItems(_searchQuery)
              .then((items) => items
                  .where((item) =>
                      item.listingType == type &&
                      (_selectedCategory == 'all' ||
                          item.category == _selectedCategory))
                  .toList())),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == ListingType.buy
                      ? Icons.shopping_cart
                      : type == ListingType.borrow
                          ? Icons.access_time
                          : Icons.card_giftcard,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No ${type.name} items found for "$_searchQuery"'
                      : 'No ${type.name} items available nearby',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildItemCard(MarketplaceItem item) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailScreen(itemId: item.id),
          ),
        ).then((_) => setState(() {}));
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.images.isNotEmpty
                      ? Hero(
                          tag: 'item_image_${item.id}',
                          child: CachedNetworkImage(
                            imageUrl: item.images.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 50),
                        ),
                  // Listing type badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.listingType == ListingType.buy
                            ? theme.colorScheme.primary
                            : item.listingType == ListingType.borrow
                                ? theme.colorScheme.tertiary
                                : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.listingType == ListingType.buy
                            ? 'Buy'
                            : item.listingType == ListingType.borrow
                                ? 'Borrow'
                                : 'Free',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Item details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.priceDisplay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.isFree
                          ? Colors.green
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatDistance(item.location),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
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

  String _formatDistance(GeoPoint itemLocation) {
    if (_userLocation == null) {
      debugPrint('[_formatDistance] User location is null');
      return 'Unknown distance';
    }

    // Log both coordinates
    debugPrint('[ _formatDistance ] userLocation: '
        '(${_userLocation!.latitude}, ${_userLocation!.longitude}); '
        'itemLocation: (${itemLocation.latitude}, ${itemLocation.longitude})');

    // Calculate distance (in meters) then convert to km
    final distanceMeters = geo.Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      itemLocation.latitude,
      itemLocation.longitude,
    );
    final distanceKm = distanceMeters / 1000;

    // Log raw distance values
    debugPrint('[ _formatDistance ] distance: '
        '${distanceMeters.toStringAsFixed(2)} m '
        '(${distanceKm.toStringAsFixed(3)} km)');

    if (distanceKm < 1) {
      final inMeters = (distanceKm * 1000).toStringAsFixed(0);
      return '$inMeters m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km away';
    } else {
      return '${distanceKm.toStringAsFixed(0)} km away';
    }
  }
}
