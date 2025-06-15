import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class LocationSelectionScreen extends StatefulWidget {
  @override
  _LocationSelectionScreenState createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _suggestions = [];
  final List<String> _placeIds = [];
  LatLng _currentLocation = LatLng(31.5204, 73.8567); // Default location
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;

  final String apiKey = 'AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
    }

    // Check if permission is granted
    if (permission == LocationPermission.deniedForever) {
      // Handle the case when permission is denied permanently
      print(
          "Location permission is permanently denied. Please enable it in settings.");
      return;
    }

    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
      // Fetch the current position
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _zoomToLocation(_currentLocation);
    } catch (e) {
      // Handle error if location fetch fails
      print("Error getting location: $e");
      setState(() {
        _currentLocation = LatLng(31.4504, 73.1350); // Default to Faisalabad
      });
      _zoomToLocation(_currentLocation);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _zoomToLocation(_currentLocation);
  }

  void _zoomToLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 18.0));
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isNotEmpty) {
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:pk';

      try {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _suggestions.clear();
            _placeIds.clear();
            for (var prediction in data['predictions']) {
              _suggestions.add(prediction['description']);
              _placeIds.add(prediction['place_id']);
            }
          });
        } else {
          print('Failed to fetch suggestions');
        }
      } catch (e) {
        print('Error fetching suggestions: $e');
      }
    } else {
      setState(() {
        _suggestions.clear();
        _placeIds.clear();
      });
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['result']['geometry']['location'];
        LatLng newLocation = LatLng(location['lat'], location['lng']);
        setState(() {
          _selectedLocation = newLocation;
        });
        _zoomToLocation(newLocation);
      } else {
        print('Failed to fetch place details');
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }

  void _confirmLocation() {
    LatLng? location = _selectedLocation ?? null;
    Fluttertoast.showToast(
      msg: 'Location Saved.',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
    Navigator.pop(context, location);
  }

  void _zoomToCurrentLocation() {
    _zoomToLocation(_currentLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 14.0,
            ),
            onMapCreated: _onMapCreated,
            mapType: MapType.hybrid,
            onCameraMove: (position) {
              setState(() {
                _selectedLocation = position.target;
              });
            },
          ),
          Center(
            child: Icon(
              Icons.location_pin,
              color: Colors.red,
              size: 40.0,
            ),
          ),
          Positioned(
            top: 16.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for an address...',
                    fillColor: Colors.white,
                    // White background for the search field
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _suggestions.clear();
                      });
                    } else {
                      _fetchSuggestions(value);
                    }
                  },
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    color: Colors.white,
                    height: 200.0,
                    // Set a fixed height for the suggestions list
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_suggestions[index]),
                          onTap: () {
                            _getPlaceDetails(_placeIds[index]);
                            setState(() {
                              _searchController.text = _suggestions[index];
                              _suggestions.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 80.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: _zoomToCurrentLocation,
              child: Icon(Icons.my_location),
              backgroundColor: Colors.blue,
            ),
          ),
          Positioned(
            bottom: 16.0,
            left: 16.0,
            right: 16.0,
            child: ElevatedButton(
              onPressed: _confirmLocation,
              child: Text('Confirm Location'),
            ),
          ),
        ],
      ),
    );
  }
}
