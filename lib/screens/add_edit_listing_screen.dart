import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:geocoding/geocoding.dart'
    show Placemark, placemarkFromCoordinates;

import 'package:geolocator/geolocator.dart' as geo;

import '../utils/firebase_mock.dart' show GeolocatorMock;

import 'package:image_picker/image_picker.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_service.dart';

class AddEditListingScreen extends StatefulWidget {
  final String? itemId;

  const AddEditListingScreen({super.key, this.itemId});

  @override
  State<AddEditListingScreen> createState() => _AddEditListingScreenState();
}

class _AddEditListingScreenState extends State<AddEditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final MarketplaceService _marketplaceService = MarketplaceService();

  bool _isLoading = false;
  bool _isEditing = false;
  MarketplaceItem? _existingItem;

  String _selectedCategory = MarketplaceCategory.categories.first.id;
  ItemCondition _selectedCondition = ItemCondition.good;
  ListingType _selectedListingType = ListingType.buy;
  List<File> _imageFiles = [];
  List<String> _existingImages = [];
  GeoPoint _location = const GeoPoint(0, 0);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.itemId != null;
    if (_isEditing) {
      _loadExistingItem();
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingItem() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final item = await _marketplaceService.getItemById(widget.itemId!);
      if (item != null) {
        setState(() {
          _existingItem = item;
          _titleController.text = item.title;
          _descriptionController.text = item.description;
          _priceController.text = item.price.toString();
          _addressController.text = item.address;
          _selectedCategory = item.category;
          _selectedCondition = item.condition;
          _selectedListingType = item.listingType;
          _existingImages = List.from(item.images);
          _location = item.location;
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

  Future<void> _getCurrentLocation() async {
    try {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever ||
          permission == geo.LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permissions are denied.\n'
              'Please enable them from your device settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: geo.Geolocator.openAppSettings,
            ),
          ),
        );
        return;
      }

      // 🛰️ 2️⃣ Get Position
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      // 🗺️ 3️⃣ Reverse‑geocode
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw Exception('No address found for the coordinates.');
      }
      final place = placemarks.first;
      final fullAddress = [
        if (place.name?.isNotEmpty ?? false) place.name,
        if (place.street?.isNotEmpty ?? false) place.street,
        if (place.locality?.isNotEmpty ?? false) place.locality,
        if (place.administrativeArea?.isNotEmpty ?? false)
          place.administrativeArea,
        if (place.country?.isNotEmpty ?? false) place.country,
      ].join(', ');

      // 📝 4️⃣ Update UI
      setState(() {
        _location = GeoPoint(position.latitude, position.longitude);
        _addressController.text = fullAddress;
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (var pickedFile in pickedFiles) {
            _imageFiles.add(File(pickedFile.path));
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_existingImages.isEmpty && _imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final price = double.tryParse(_priceController.text) ?? 0.0;

      if (_isEditing) {
        // Update existing item
        final success = await _marketplaceService.updateMarketplaceItem(
          itemId: widget.itemId!,
          title: _titleController.text,
          description: _descriptionController.text,
          price: price,
          category: _selectedCategory,
          condition: _selectedCondition,
          newImages: _imageFiles,
          existingImages: _existingImages,
          location: _location,
          address: _addressController.text,
          listingType: _selectedListingType,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update item')),
          );
        }
      } else {
        // Add new item
        final itemId = await _marketplaceService.addMarketplaceItem(
          title: _titleController.text,
          description: _descriptionController.text,
          price: price,
          category: _selectedCategory,
          condition: _selectedCondition,
          images: _imageFiles,
          location: _location,
          address: _addressController.text,
          listingType: _selectedListingType,
        );

        if (itemId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item added successfully')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add item')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Listing' : 'Add Listing'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Listing type selection
                    Text(
                      'Listing Type',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ListingType>(
                      segments: const [
                        ButtonSegment(
                          value: ListingType.buy,
                          label: Text('Sell'),
                          icon: Icon(Icons.monetization_on),
                        ),
                        ButtonSegment(
                          value: ListingType.borrow,
                          label: Text('Rent'),
                          icon: Icon(Icons.access_time),
                        ),
                        ButtonSegment(
                          value: ListingType.giveaway,
                          label: Text('Give Away'),
                          icon: Icon(Icons.card_giftcard),
                        ),
                      ],
                      selected: {_selectedListingType},
                      onSelectionChanged: (Set<ListingType> selected) {
                        setState(() {
                          _selectedListingType = selected.first;
                          // Clear price if giveaway
                          if (_selectedListingType == ListingType.giveaway) {
                            _priceController.text = '0';
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        backgroundColor: theme.colorScheme.surface,
                        selectedForegroundColor: theme.colorScheme.onPrimary,
                        selectedBackgroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Images
                    Text(
                      'Photos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(8),
                        children: [
                          // Add image button
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: theme.colorScheme.outline),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Photos',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Existing images
                          ..._existingImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final imageUrl = entry.value;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeExistingImage(index),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),

                          // New images
                          ..._imageFiles.asMap().entries.map((entry) {
                            final index = entry.key;
                            final file = entry.value;
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: FileImage(file),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeNewImage(index),
                                  child: Container(
                                    margin: const EdgeInsets.all(4),
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'At least one photo required. First photo will be the cover image.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: _selectedListingType == ListingType.borrow
                            ? 'Price per day'
                            : 'Price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                        prefixText: _selectedListingType != ListingType.giveaway
                            ? ''
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      enabled: _selectedListingType != ListingType.giveaway,
                      validator: (value) {
                        if (_selectedListingType != ListingType.giveaway &&
                            (value == null || value.isEmpty)) {
                          return 'Please enter a price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Category
                    Text(
                      'Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: MarketplaceCategory.categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Condition
                    Text(
                      'Condition',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ItemCondition>(
                      value: _selectedCondition,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.star),
                      ),
                      items: ItemCondition.values.map((condition) {
                        String displayName;
                        switch (condition) {
                          case ItemCondition.brandNew:
                            displayName = 'New';
                            break;
                          case ItemCondition.likeNew:
                            displayName = 'Like New';
                            break;
                          case ItemCondition.good:
                            displayName = 'Good';
                            break;
                          case ItemCondition.fair:
                            displayName = 'Fair';
                            break;
                          case ItemCondition.poor:
                            displayName = 'Poor';
                            break;
                        }
                        return DropdownMenuItem(
                          value: condition,
                          child: Text(displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCondition = value;
                          });
                        }
                      },
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
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _getCurrentLocation,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _isEditing ? 'Update Listing' : 'Post Listing',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
