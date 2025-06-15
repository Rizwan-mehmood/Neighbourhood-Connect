import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firebase_mock.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:flutter/foundation.dart';

// import 'package:geolocator/geolocator.dart';
import '../models/marketplace_item.dart';
import '../widgets/upload_media.dart';

class MarketplaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final fb_storage.FirebaseStorage _storage =
      fb_storage.FirebaseStorage.instance;

  // Reference to marketplace collection
  CollectionReference get _marketplaceRef =>
      _firestore.collection('marketplace');

  // Reference to users collection
  CollectionReference get _usersRef => _firestore.collection('users');

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Get all marketplace items
  Stream<List<MarketplaceItem>> getMarketplaceItems() {
    return _marketplaceRef
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    });
  }

  // Get nearby marketplace items (within 20km radius)
  Stream<List<MarketplaceItem>> getNearbyItems(GeoPoint userLocation,
      {String? category, ListingType? type}) {
    // Calculate bounding box for approximately 20km radius
    // 0.18 degrees is roughly 20km at equator
    const double distance = 0.18;

    double latMin = userLocation.latitude - distance;
    double latMax = userLocation.latitude + distance;
    double lngMin = userLocation.longitude - distance;
    double lngMax = userLocation.longitude + distance;

    Query query = _marketplaceRef
        .where('status', isEqualTo: 'active')
        .where('latitude', isGreaterThanOrEqualTo: latMin)
        .where('latitude', isLessThanOrEqualTo: latMax);

    if (category != null && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    if (type != null) {
      query = query.where('listingType', isEqualTo: type.name);
    }

    return query
        .orderBy('latitude')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      // Filter results further for longitude
      List<MarketplaceItem> items = snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .where((item) => item.longitude >= lngMin && item.longitude <= lngMax)
          .toList();

      // Sort by distance from user
      items.sort((a, b) {
        double distA = _calculateDistance(userLocation.latitude,
            userLocation.longitude, a.latitude, a.longitude);

        double distB = _calculateDistance(userLocation.latitude,
            userLocation.longitude, b.latitude, b.longitude);

        return distA.compareTo(distB);
      });

      return items;
    });
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return GeolocatorMock.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // in km
  }

  // Get items by category
  Stream<List<MarketplaceItem>> getItemsByCategory(String category) {
    return _marketplaceRef
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    });
  }

  // Get items by type (buy, borrow, giveaway)
  Stream<List<MarketplaceItem>> getItemsByType(ListingType type) {
    return _marketplaceRef
        .where('listingType', isEqualTo: type.name)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    });
  }

  // Get user's listings
  Stream<List<MarketplaceItem>> getUserListings(String userId) {
    return _marketplaceRef
        .where('sellerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .toList();
    });
  }

  // Get single item by id
  Future<MarketplaceItem?> getItemById(String itemId) async {
    try {
      DocumentSnapshot doc = await _marketplaceRef.doc(itemId).get();
      if (doc.exists) {
        return MarketplaceItem.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting item: $e');
      return null;
    }
  }

  // Add a new marketplace item
  Future<String?> addMarketplaceItem({
    required String title,
    required String description,
    required double price,
    required String category,
    required ItemCondition condition,
    required List<File> images,
    required GeoPoint location,
    required String address,
    required ListingType listingType,
  }) async {
    try {
      // Fetch current user document
      final userDoc = await _usersRef.doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return null;

      // Upload images to Google Drive
      List<String> imageUrls = [];
      for (var image in images) {
        // Generate a unique filename: you can tweak this as needed
        final fileName =
            'marketplace/${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
        final url = await GoogleDriveService.uploadFile(image, fileName);
        if (url.isNotEmpty) {
          imageUrls.add(url);
        }
      }

      // Build MarketplaceItem
      final docRef = _marketplaceRef.doc();
      final item = MarketplaceItem(
        id: docRef.id,
        title: title,
        description: description,
        price: price,
        category: category,
        condition: condition,
        images: imageUrls,
        location: location,
        address: address,
        latitude: location.latitude,
        longitude: location.longitude,
        sellerId: _currentUserId,
        sellerName:
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
        sellerAvatar: userData['profilePicture'] ?? '',
        listingType: listingType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
      );

      // Persist to Firestore
      await docRef.set(item.toFirestore());
      return docRef.id;
    } catch (e, st) {
      debugPrint('Error adding marketplace item: $e\n$st');
      return null;
    }
  }

  // Update a marketplace item
  Future<bool> updateMarketplaceItem({
    required String itemId,
    required String title,
    required String description,
    required double price,
    required String category,
    required ItemCondition condition,
    List<File>? newImages,
    required List<String> existingImages,
    required GeoPoint location,
    required String address,
    required ListingType listingType,
  }) async {
    try {
      // Fetch the existing item
      final docRef = _marketplaceRef.doc(itemId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final existingItem = MarketplaceItem.fromFirestore(doc);
      if (existingItem.sellerId != _currentUserId) return false;

      // Start with URLs the client already had
      final allImageUrls = List<String>.from(existingImages);

      // Upload any newly added images to Drive
      if (newImages != null && newImages.isNotEmpty) {
        for (var image in newImages) {
          final fileName =
              'marketplace/${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
          final url = await GoogleDriveService.uploadFile(image, fileName);
          if (url.isNotEmpty) {
            allImageUrls.add(url);
          }
        }
      }

      // Build the updated item
      final updatedItem = existingItem.copyWith(
        title: title,
        description: description,
        price: price,
        category: category,
        condition: condition,
        images: allImageUrls,
        location: location,
        address: address,
        latitude: location.latitude,
        longitude: location.longitude,
        listingType: listingType,
        updatedAt: DateTime.now(),
      );

      // Persist updates
      await docRef.update(updatedItem.toFirestore());
      return true;
    } catch (e, st) {
      debugPrint('Error updating marketplace item: $e\n$st');
      return false;
    }
  }

  // Delete a marketplace item
  Future<bool> deleteMarketplaceItem(String itemId) async {
    try {
      // Get the item first to check ownership
      DocumentSnapshot doc = await _marketplaceRef.doc(itemId).get();
      if (!doc.exists) {
        return false;
      }

      MarketplaceItem item = MarketplaceItem.fromFirestore(doc);

      // Check if the current user is the seller
      if (item.sellerId != _currentUserId) {
        return false;
      }

      // Delete the item
      await _marketplaceRef.doc(itemId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting item: $e');
      return false;
    }
  }

  // Change item status (sold, reserved, active)
  Future<bool> changeItemStatus(String itemId, String status) async {
    try {
      // Get the item first to check ownership
      DocumentSnapshot doc = await _marketplaceRef.doc(itemId).get();
      if (!doc.exists) {
        return false;
      }

      MarketplaceItem item = MarketplaceItem.fromFirestore(doc);

      // Check if the current user is the seller
      if (item.sellerId != _currentUserId) {
        return false;
      }

      // Update status
      await _marketplaceRef.doc(itemId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      debugPrint('Error changing item status: $e');
      return false;
    }
  }

  // Upload an image to Firebase Storage
  Future<String> _uploadImage(File image) async {
    try {
      final storageRef = _storage.ref().child(
          'marketplace/${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  // Get current user location
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      LocationPermission permission = await GeolocatorMock.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await GeolocatorMock.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await GeolocatorMock.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Get user saved location from Firestore
  Future<GeoPoint?> getUserLocation(String userId) async {
    print(userId);
    print("object");
    try {
      DocumentSnapshot userDoc = await _usersRef.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('location')) {
          return userData['location'] as GeoPoint;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user location: $e');
      return null;
    }
  }

  // Search marketplace items
  Future<List<MarketplaceItem>> searchMarketplaceItems(String query) async {
    try {
      // Get all active items
      QuerySnapshot snapshot =
          await _marketplaceRef.where('status', isEqualTo: 'active').get();

      // Filter items by title or description containing the query
      return snapshot.docs
          .map((doc) => MarketplaceItem.fromFirestore(doc))
          .where((item) =>
              item.title.toLowerCase().contains(query.toLowerCase()) ||
              item.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Error searching items: $e');
      return [];
    }
  }
}
