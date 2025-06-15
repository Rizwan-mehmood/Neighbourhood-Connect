import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import 'package:neighborhood_connect/widgets/choose_location.dart';
import 'package:neighborhood_connect/widgets/create_event.dart';
import 'package:neighborhood_connect/widgets/post_creation_helper.dart';

class CreateEventScreen extends StatefulWidget {
  @override
  _CreateEventScreenState createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  bool isCreateEnabled = false;
  List<String> images = []; // List to store image paths
  TextEditingController eventNameController = TextEditingController();
  TextEditingController locationController =
      TextEditingController(); // Controller for the location field
  TextEditingController dateController =
      TextEditingController(); // Date Controller
  TextEditingController timeController =
      TextEditingController(); // Time Controller
  TextEditingController priceController =
      TextEditingController(); // Price Controller

  // Dropdown values for event type and category
  String? selectedEventType;
  String? selectedCategory;
  late GeoPoint selectedLocationGeoPoint;

  List<String> eventTypes = ['Free', 'Paid'];
  List<String> categories = [
    'Art',
    'Business',
    'Charity',
    'Conferences',
    'Conventions',
    'Crafts',
    'Dance',
    'Education',
    'Exhibitions',
    'Fashion',
    'Festivals',
    'Food',
    'Fundraisers',
    'Gaming',
    'Health & Fitness',
    'Literature',
    'Movies',
    'Music',
    'Networking',
    'Sports',
    'Tech',
    'Theater',
    'Workshops',
    'Travel',
  ];

  // Dummy function to enable the button after a condition (e.g., form filled)
  void _toggleCreateButton() {
    setState(() {
      isCreateEnabled = eventNameController.text.isNotEmpty &&
          locationController.text.isNotEmpty &&
          dateController.text.isNotEmpty &&
          selectedTime != null &&
          selectedEventType != null &&
          selectedCategory != null &&
          (selectedEventType == 'Free' || priceController.text.isNotEmpty) &&
          images
              .isNotEmpty; // Check if all fields are filled and at least one image is uploaded
    });
  }

  // Function to pick multiple images
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedImages = await picker.pickMultiImage();

    if (pickedImages != null) {
      setState(() {
        images.addAll(pickedImages.map((e) => e.path)); // Add images
      });
      _toggleCreateButton(); // Recheck the button state
    }
  }

  void _removeImage(int index) {
    setState(() {
      images.removeAt(index); // Remove image from list
    });
    _toggleCreateButton(); // Recheck the button state
  }

  // Function to open bottom sheet for location selection
  void _openLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Container(
          height: 600, // Custom height for the bottom sheet
          child: LocationSearchBottomSheet(
            onLocationSelected: (selectedLocation, latitude, longitude) {
              setState(() {
                locationController.text =
                    selectedLocation; // Update location field
                selectedLocationGeoPoint =
                    GeoPoint(latitude, longitude); // Save GeoPoint
              });
              Navigator.pop(context); // Close bottom sheet after selection
            },
          ),
        );
      },
    );
  }

  // Function to pick date
  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blue,
            colorScheme:
                ColorScheme.light(primary: Colors.blue, secondary: Colors.blue),
            // Update to colorScheme
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            dialogBackgroundColor:
                Colors.white, // Correct parameter for background color
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        dateController.text =
            "${selectedDate.toLocal()}".split(' ')[0]; // Format date to display
      });
    }
  }

  void _createEvent() {
    // Collect all the data from the input fields and selections
    final eventName = eventNameController.text;
    final address = locationController.text;
    final date = dateController.text;
    final time = selectedTime;
    final eventType = selectedEventType;
    final category = selectedCategory;
    final price = (eventType == 'Paid') ? priceController.text : null;
    final imagesList = images;

    // Ensure all required fields are filled
    if (eventName.isEmpty ||
        address.isEmpty ||
        date.isEmpty ||
        time == null ||
        eventType == null ||
        category == null ||
        (eventType == 'Paid' && price == null) ||
        imagesList.isEmpty) {
      // Show error if any field is missing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all the fields and upload images')),
      );
      return;
    }

    // Prepare the data to be passed to the helper widget
    final eventData = {
      'eventName': eventName,
      'address': address,
      'location': selectedLocationGeoPoint,
      'date': date,
      'time': time,
      'eventType': eventType,
      'category': category,
      'price': price,
      'images': imagesList,
    };

    // Pass the data to the helper widget (replace `HelperWidget()` with your actual widget)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateEventHelper(eventData: eventData), // Pass the data here
      ),
    );
  }

  // Function to select time from dropdown
  String? selectedTime;
  List<String> times = [
    "12:00 AM",
    "01:00 AM",
    "02:00 AM",
    "03:00 AM",
    "04:00 AM",
    "05:00 AM",
    "06:00 AM",
    "07:00 AM",
    "08:00 AM",
    "09:00 AM",
    "10:00 AM",
    "11:00 AM",
    "12:00 PM",
    "01:00 PM",
    "02:00 PM",
    "03:00 PM",
    "04:00 PM",
    "05:00 PM",
    "06:00 PM",
    "07:00 PM",
    "08:00 PM",
    "09:00 PM",
    "10:00 PM",
    "11:00 PM"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context); // Implement back navigation
              },
            ),
            title: Text('Create Event'),
            actions: [
              TextButton(
                onPressed: isCreateEnabled ? _createEvent : null,
                child: Text(
                  'Create',
                  style: TextStyle(
                    color: isCreateEnabled
                        ? Colors.white
                        : Colors.grey, // Text color
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isCreateEnabled
                      ? Colors.blue
                      : Colors.grey[200], // Background color
                ),
              ),
              SizedBox(width: 20),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          Focus.of(context).unfocus();
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Upload Container
                Container(
                  width: double.infinity,
                  height: images.isEmpty ? 200 : 250,
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (images.isEmpty) ...[
                        Icon(
                          Icons.upload_file,
                          size: 40,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Click and upload images',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 16),
                      ],
                      if (images.isNotEmpty) ...[
                        Container(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(File(images[index])),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    width: 150,
                                    height: 150,
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: -5,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      if (images.isNotEmpty)
                        ElevatedButton(
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white),
                          child: Text('Add More Images'),
                        ),
                      if (images.isEmpty)
                        ElevatedButton(
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white),
                          child: Text('Upload Images'),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Event Name Input
                // For text fields like Event Name, Location, Description, etc.
                TextField(
                  controller: eventNameController,
                  onChanged: (_) => _toggleCreateButton(),
                  // This triggers the validation check
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: 'Event Name',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                ),

                SizedBox(height: 16),
                // Location Input
                TextField(
                  controller: locationController,
                  readOnly: true,
                  onTap: _openLocationBottomSheet,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                // Row for Date and Time
                Row(
                  children: [
                    // Date Field
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: TextField(
                            controller: dateController,
                            decoration: InputDecoration(
                              labelText: 'Select Date',
                              prefixIcon: Icon(Icons.calendar_today),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Time Field (Dropdown)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedTime,
                        onChanged: (newValue) {
                          setState(() {
                            selectedTime = newValue!;
                          });
                          _toggleCreateButton();
                        },
                        items: times
                            .map((time) => DropdownMenuItem<String>(
                                  value: time,
                                  child: Text(time),
                                ))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: 'Select Time',
                          prefixIcon: Icon(Icons.access_time),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        dropdownColor: Colors.white,
                        isExpanded: true,
                        // Ensures the dropdown takes the full width
                        menuMaxHeight:
                            200, // Set the height of the dropdown list
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Event Type Selection
                DropdownButtonFormField<String>(
                  value: selectedEventType,
                  onChanged: (newValue) {
                    setState(() {
                      selectedEventType = newValue;
                    });
                    _toggleCreateButton();
                  },
                  items: eventTypes
                      .map((eventType) => DropdownMenuItem<String>(
                            value: eventType,
                            child: Text(eventType),
                          ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: 'Event Type',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: Colors.white,
                ),
                SizedBox(height: 16),
                // Price Input (if Paid event is selected)
                if (selectedEventType == 'Paid') ...[
                  TextField(
                    controller: priceController,
                    onChanged: (_) => _toggleCreateButton(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price (PKR)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                // Category Selection
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  onChanged: (newValue) {
                    setState(() {
                      selectedCategory = newValue;
                    });
                    _toggleCreateButton();
                  },
                  items: categories
                      .map((category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  // Custom height for dropdown list
                  menuMaxHeight:
                      300, // Adjust this value to change the height of the dropdown list
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
