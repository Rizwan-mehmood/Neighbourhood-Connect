import 'dart:core';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ListingType { buy, borrow, giveaway }

enum ItemCondition { brandNew, likeNew, good, fair, poor }

class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final ItemCondition condition;
  final List<String> images;
  final GeoPoint location;
  final String address;
  final double latitude;
  final double longitude;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final ListingType listingType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // active, sold, reserved

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.condition,
    required this.images,
    required this.location,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.listingType,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory MarketplaceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketplaceItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      condition: ItemCondition.values.firstWhere(
            (e) => e.name == data['condition'],
        orElse: () => ItemCondition.good,
      ),
      images: List<String>.from(data['images'] ?? []),
      location: data['location'] ?? const GeoPoint(0, 0),
      address: data['address'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      sellerAvatar: data['sellerAvatar'] ?? '',
      listingType: ListingType.values.firstWhere(
            (e) => e.name == data['listingType'],
        orElse: () => ListingType.buy,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'condition': condition.name,
      'images': images,
      'location': location,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'listingType': listingType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
    };
  }

  MarketplaceItem copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? category,
    ItemCondition? condition,
    List<String>? images,
    GeoPoint? location,
    String? address,
    double? latitude,
    double? longitude,
    String? sellerId,
    String? sellerName,
    String? sellerAvatar,
    ListingType? listingType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return MarketplaceItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      images: images ?? this.images,
      location: location ?? this.location,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatar: sellerAvatar ?? this.sellerAvatar,
      listingType: listingType ?? this.listingType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  String get priceDisplay {
    if (listingType == ListingType.giveaway) {
      return 'Free';
    } else if (listingType == ListingType.borrow) {
      return price > 0 ? 'PKR ${price.toStringAsFixed(2)}/day' : 'Free to borrow';
    } else {
      return 'PKR ${price.toStringAsFixed(2)}';
    }
  }

  String get conditionDisplay {
    switch (condition) {
      case ItemCondition.brandNew:
        return 'New';
      case ItemCondition.likeNew:
        return 'Like New';
      case ItemCondition.good:
        return 'Good';
      case ItemCondition.fair:
        return 'Fair';
      case ItemCondition.poor:
        return 'Poor';
      default:
        return 'Unknown';
    }
  }

  bool get isFree => price <= 0 || listingType == ListingType.giveaway;
}

// Category definition
class MarketplaceCategory {
  final String id;
  final String name;
  final IconData iconData; // ← const IconData

  const MarketplaceCategory({
    required this.id,
    required this.name,
    required this.iconData,
  });

  static const List<MarketplaceCategory> categories = [
    MarketplaceCategory(
      id: 'electronics',
      name: 'Electronics',
      iconData: Icons.phone_android,
    ),
    MarketplaceCategory(
      id: 'furniture',
      name: 'Furniture',
      iconData: Icons.chair,
    ),
    MarketplaceCategory(
      id: 'clothing',
      name: 'Clothing',
      iconData: Icons.checkroom,
    ),
    MarketplaceCategory(
      id: 'books',
      name: 'Books',
      iconData: Icons.menu_book,
    ),
    MarketplaceCategory(
      id: 'toys',
      name: 'Toys & Games',
      iconData: Icons.toys,
    ),
    MarketplaceCategory(
      id: 'sports',
      name: 'Sports',
      iconData: Icons.sports_basketball,
    ),
    MarketplaceCategory(
      id: 'home',
      name: 'Home & Garden',
      iconData: Icons.home,
    ),
    MarketplaceCategory(
      id: 'vehicles',
      name: 'Vehicles',
      iconData: Icons.directions_car,
    ),
    MarketplaceCategory(
      id: 'others',
      name: 'Others',
      iconData: Icons.more_horiz,
    ),
  ];

  static MarketplaceCategory getById(String id) {
    return categories.firstWhere(
          (c) => c.id == id,
      orElse: () => categories.last,
    );
  }
}
