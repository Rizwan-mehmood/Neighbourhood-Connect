import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/marketplace_chat_service.dart';
import '../utils/firebase_mock.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// import 'package:dreamflow/theme.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';
import 'marketplace_chat_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final MarketplaceChatService _chatService = MarketplaceChatService();
  bool _isLoading = true;
  MarketplaceItem? _item;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadItemDetails();
  }

  Future<void> _loadItemDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final item = await _marketplaceService.getItemById(widget.itemId);
      if (item != null) {
        setState(() {
          _item = item;
          _markers.add(
            Marker(
              markerId: MarkerId(item.id),
              position: LatLng(item.latitude, item.longitude),
              infoWindow: InfoWindow(title: item.title),
            ),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startChat() async {
    if (_item == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to chat')),
      );
      return;
    }

    // Don't allow chatting with yourself
    if (currentUserId == _item!.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your own listing')),
      );
      return;
    }

    try {
      final conversationId = await _chatService.getOrCreateConversation(
        _item!.id,
        _item!.sellerId,
      );

      if (conversationId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketplaceChatScreen(
              conversationId: conversationId,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Details')),
        body: const Center(child: Text('Item not found')),
      );
    }

    final item = _item!;
    final isCurrentUserSeller =
        FirebaseAuth.instance.currentUser?.uid == item.sellerId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image carousel
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageCarousel(item),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    // Share functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),

          // Item details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.priceDisplay,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: item.isFree
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getListingTypeColor(item.listingType, theme),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getListingTypeText(item.listingType),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Item details: condition, category, posted date
                  Row(
                    children: [
                      _buildInfoChip(
                          context, 'Condition', item.conditionDisplay),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        context,
                        'Category',
                        MarketplaceCategory.getById(item.category).name,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _buildInfoChip(
                    context,
                    'Posted',
                    timeago.format(item.createdAt),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: theme.textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 24),

                  // Location
                  Text(
                    'Location',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.address.isNotEmpty
                              ? item.address
                              : 'Location available',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(item.latitude, item.longitude),
                          zoom: 14,
                        ),
                        markers: _markers,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Seller info
                  Text(
                    'Seller',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: item.sellerAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(item.sellerAvatar)
                            : null,
                        child: item.sellerAvatar.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.sellerName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Member since ${timeago.format(item.createdAt)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: isCurrentUserSeller
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Edit listing
                          // TODO: Navigate to edit listing screen
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Edit Listing'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Mark as sold/borrowed/given
                          final newStatus =
                              await _showStatusChangeDialog(context, item);
                          if (newStatus != null) {
                            final success =
                                await _marketplaceService.changeItemStatus(
                              item.id,
                              newStatus,
                            );
                            if (success) {
                              setState(() {
                                _item = item.copyWith(status: newStatus);
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Change Status'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _startChat,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.message_outlined),
                            SizedBox(width: 8),
                            Text('Message Seller'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Request to buy/borrow
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                item.listingType == ListingType.giveaway
                                    ? 'Request sent to get this item!'
                                    : item.listingType == ListingType.borrow
                                        ? 'Borrow request sent!'
                                        : 'Buy request sent!',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.listingType == ListingType.giveaway
                                  ? Icons.card_giftcard
                                  : item.listingType == ListingType.borrow
                                      ? Icons.access_time
                                      : Icons.shopping_cart,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.listingType == ListingType.giveaway
                                  ? 'Request Item'
                                  : item.listingType == ListingType.borrow
                                      ? 'Borrow Now'
                                      : 'Buy Now',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(MarketplaceItem item) {
    if (item.images.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        // Images
        PageView.builder(
          controller: _pageController,
          itemCount: item.images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Hero(
              tag: 'item_image_${item.id}',
              child: CachedNetworkImage(
                imageUrl: item.images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error, size: 50),
                ),
              ),
            );
          },
        ),

        // Image indicators
        if (item.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                item.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentImageIndex == index ? 16 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getListingTypeColor(ListingType type, ThemeData theme) {
    switch (type) {
      case ListingType.buy:
        return theme.colorScheme.primary;
      case ListingType.borrow:
        return theme.colorScheme.tertiary;
      case ListingType.giveaway:
        return Colors.green;
    }
  }

  String _getListingTypeText(ListingType type) {
    switch (type) {
      case ListingType.buy:
        return 'For Sale';
      case ListingType.borrow:
        return 'For Rent';
      case ListingType.giveaway:
        return 'Giveaway';
    }
  }

  Future<String?> _showStatusChangeDialog(
      BuildContext context, MarketplaceItem item) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Item Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.status != 'active')
              ListTile(
                title: const Text('Mark as Available'),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () => Navigator.pop(context, 'active'),
              ),
            if (item.status != 'sold')
              ListTile(
                title: const Text('Mark as Sold'),
                leading: const Icon(Icons.monetization_on, color: Colors.amber),
                onTap: () => Navigator.pop(context, 'sold'),
              ),
            if (item.status != 'reserved')
              ListTile(
                title: const Text('Mark as Reserved'),
                leading: const Icon(Icons.bookmark, color: Colors.blue),
                onTap: () => Navigator.pop(context, 'reserved'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
