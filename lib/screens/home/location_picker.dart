import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../home/home_screen.dart';

class LocationPicker extends StatefulWidget {
  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng _selectedLocation =
      LatLng(31.5204, 73.8567); // Default: Faisalabad, Pakistan
  String _googleMapsApiKey =
      "AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8"; // Replace with your actual API key
  bool _showLocationPicker = true;
  bool _isLocationSelected = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Fetch the current location when the widget is initialized
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If location services are not enabled, use default location
      setState(() {
        _selectedLocation = LatLng(31.5204, 73.8567); // Faisalabad, Pakistan
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return; // Permission denied, use default location
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return; // Permissions are permanently denied
    }

    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      // Update the camera position to the current location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 18),
      );
    } catch (e) {
      print("Error fetching current location: $e");
      // Fallback to default location in case of failure
      setState(() {
        _selectedLocation = LatLng(31.5204, 73.8567); // Faisalabad, Pakistan
      });
    }
  }

  Future<List<String>> _getSuggestions(String query) async {
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_googleMapsApiKey");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return (data['predictions'] as List)
            .map((item) => item['description'] as String)
            .toList();
      }
    }
    return [];
  }

  Future<LatLng> _getCoordinatesFromAddress(String address) async {
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?address=$address&key=$_googleMapsApiKey");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        return LatLng(location['lat'], location['lng']);
      }
    }
    throw Exception("Failed to get coordinates for address");
  }

  Future<void> _saveLocationToFirebase(LatLng location) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.update({
          "location": GeoPoint(location.latitude, location.longitude),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location updated successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not authenticated.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving location: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Location Picker"),
      ),
      body: _showLocationPicker
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TypeAheadField<String>(
                    suggestionsCallback: _getSuggestions,
                    itemBuilder: (context, suggestion) {
                      return ListTile(
                        title: Text(suggestion),
                      );
                    },
                    onSelected: (suggestion) async {
                      // Update the selected suggestion in the controller, which will reflect in the text field.
                      _searchController.text = suggestion;
                      _searchController.selection = TextSelection.collapsed(
                          offset: _searchController.text.length);

                      // Get coordinates for the selected suggestion
                      LatLng coordinates =
                          await _getCoordinatesFromAddress(suggestion);
                      setState(() {
                        _selectedLocation = coordinates;
                        _isLocationSelected = true;

                        // Move the map camera to the selected coordinates
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(coordinates),
                        );
                      });
                    },
                    builder: (context, controller, focusNode) {
                      // We can directly use the controller passed to builder instead of _searchController
                      return TextField(
                        controller: controller,
                        // Use the controller passed by TypeAheadField
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search for a location',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    mapType: MapType.hybrid,
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 14.0,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    markers: {
                      Marker(
                        markerId: MarkerId("selected-location"),
                        position: _selectedLocation,
                      )
                    },
                    onCameraMove: (position) {
                      setState(() {
                        _selectedLocation = position.target;
                        _isLocationSelected = true;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _isLocationSelected
                        ? () async {
                            await _saveLocationToFirebase(_selectedLocation);
                            setState(() {
                              _showLocationPicker = false;
                            });

                            // Navigate to HomeScreen after location is saved
                            Navigator.pushNamed(context, '/refreshScreens');
                          }
                        : null, // Disable button if location is not selected
                    child: Text("Select Location"),
                  ),
                )
              ],
            )
          : Container(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _getCurrentLocation(); // Fetch current location when button is pressed
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation, 18),
          );
        },
        child: Icon(Icons.my_location), // Location icon similar to Google Maps
      ),
    );
  }
}
