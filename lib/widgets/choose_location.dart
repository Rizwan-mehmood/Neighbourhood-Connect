import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationSearchBottomSheet extends StatefulWidget {
  final Function(String, double, double) onLocationSelected;

  LocationSearchBottomSheet({required this.onLocationSelected});

  @override
  _LocationSearchBottomSheetState createState() =>
      _LocationSearchBottomSheetState();
}

class _LocationSearchBottomSheetState extends State<LocationSearchBottomSheet> {
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];

  // Function to fetch location suggestions from Google Maps API
  Future<void> _searchLocations(String query) async {
    final apiKey = 'AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8';
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        searchResults = data['predictions']; // Store suggestions
      });
    } else {
      // Handle error
      print('Failed to load locations');
    }
  }

  // Function to get latitude and longitude of the selected location
  Future<void> _getLocationCoordinates(String placeId) async {
    final apiKey = 'AIzaSyB9irjntPHdEJf024h7H_XKpS11OeW1Nh8';
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['result'];

      double latitude = result['geometry']['location']['lat'];
      double longitude = result['geometry']['location']['lng'];

      widget.onLocationSelected(
        result['formatted_address'], // Address
        latitude, // Latitude
        longitude, // Longitude
      );
    } else {
      // Handle error
      print('Failed to fetch location details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: _searchLocations,
            decoration: InputDecoration(
              labelText: 'Search for a location',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final result = searchResults[index];
                return ListTile(
                  title: Text(result['description']),
                  onTap: () {
                    String placeId = result['place_id'];
                    _getLocationCoordinates(
                        placeId); // Get lat/lng and send to parent
                    Navigator.pop(
                        context); // Close bottom sheet after selection
                  },
                );
              },
              separatorBuilder: (context, index) =>
                  Divider(), // Divider between items
            ),
          ),
        ],
      ),
    );
  }
}
