import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neighborhood_connect/screens/events/event_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/view_event.dart';

class AllEvents extends StatefulWidget {
  @override
  _AllEventsState createState() => _AllEventsState();
}

class _AllEventsState extends State<AllEvents> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _events = [];
  bool _isLoading = false;

  // Search and filter state
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedEventType = 'All';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _sortOrder = 'Ascending'; // "Ascending" or "Descending"

  // Filter options
  final List<String> _categories = [
    'All',
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
    'Travel'
  ];

  final List<String> _eventTypes = ['All', 'Free', 'Paid'];
  final List<String> _sortOrders = ['Ascending', 'Descending'];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot = await _firestore.collection('events').get();
      setState(() {
        _events = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching events: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshEvents() async {
    await _fetchEvents();
  }

  // Show filter options in a modal bottom sheet with extended options.
  void _showFilterOptions() {
    // Temporary filter variables
    String tempCategory = _selectedCategory;
    String tempEventType = _selectedEventType;
    DateTime? tempStartDate = _selectedStartDate;
    DateTime? tempEndDate = _selectedEndDate;
    String tempSortOrder = _sortOrder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Allow the modal to expand when keyboard appears.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Filter Events',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    // Category Filter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Category:', style: TextStyle(fontSize: 16)),
                        DropdownButton<String>(
                          value: tempCategory,
                          items: _categories
                              .map((cat) => DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setModalState(() {
                              tempCategory = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Event Type Filter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Event Type:', style: TextStyle(fontSize: 16)),
                        DropdownButton<String>(
                          value: tempEventType,
                          items: _eventTypes
                              .map((type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setModalState(() {
                              tempEventType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Date Range Filters
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Start Date:', style: TextStyle(fontSize: 16)),
                        TextButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempStartDate = picked;
                              });
                            }
                          },
                          child: Text(
                            tempStartDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(tempStartDate!)
                                : 'Any',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('End Date:', style: TextStyle(fontSize: 16)),
                        TextButton(
                          onPressed: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: tempEndDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempEndDate = picked;
                              });
                            }
                          },
                          child: Text(
                            tempEndDate != null
                                ? DateFormat('MMM dd, yyyy')
                                    .format(tempEndDate!)
                                : 'Any',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Sort Order Filter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sort by Date:', style: TextStyle(fontSize: 16)),
                        DropdownButton<String>(
                          value: tempSortOrder,
                          items: _sortOrders
                              .map((order) => DropdownMenuItem<String>(
                                    value: order,
                                    child: Text(order),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setModalState(() {
                              tempSortOrder = value!;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    // Apply and Reset Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _selectedEventType = tempEventType;
                              _selectedStartDate = tempStartDate;
                              _selectedEndDate = tempEndDate;
                              _sortOrder = tempSortOrder;
                            });
                            Navigator.pop(context);
                          },
                          child: Text('Apply Filters'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300]),
                          onPressed: () {
                            setModalState(() {
                              tempCategory = 'All';
                              tempEventType = 'All';
                              tempStartDate = null;
                              tempEndDate = null;
                              tempSortOrder = 'Ascending';
                            });
                          },
                          child: Text(
                            'Reset',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Build a professional event card with a white background.
  Widget _buildEventCard(DocumentSnapshot event) {
    String title = event['title'] ?? 'No Title';
    Timestamp timestamp = event['timestamp'];
    DateTime eventDate = timestamp.toDate();
    String formattedDate = DateFormat('MMM dd, yyyy').format(eventDate);
    String address = event['address'] ?? 'No Address';
    String category = event['category'] ?? 'General';
    String eventType = event['eventType'] ?? 'Free';
    String price = event['price'] ?? 'N/A';
    List<dynamic> pictures = event['pictures'] ?? [];
    String imageUrl = pictures.isNotEmpty ? pictures[0] : '';

    return Card(
      color: Colors.white,
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ViewEvent(eventId: event.id, isPersonal: false),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image/header
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Icon(Icons.event, size: 80, color: Colors.grey[400]),
              ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event title
                  Text(
                    title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  // Date
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(formattedDate,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Address
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(address,
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Category, Event Type & Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(category,
                            style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.blue,
                      ),
                      Text(
                        eventType,
                        style: TextStyle(
                          color: eventType.toLowerCase() == "free"
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (eventType.toLowerCase() != "free")
                        Text(price,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Apply search, filter, and date range criteria, then sort the events.
  List<DocumentSnapshot> _getFilteredEvents() {
    List<DocumentSnapshot> filtered = _events.where((event) {
      final title = (event['title'] ?? '').toString().toLowerCase();
      final queryMatch = title.contains(_searchQuery.toLowerCase());
      final categoryMatch = _selectedCategory == 'All'
          ? true
          : (event['category'] ?? '') == _selectedCategory;
      final eventTypeMatch = _selectedEventType == 'All'
          ? true
          : (event['eventType'] ?? '') == _selectedEventType;
      DateTime eventDate = event['timestamp'].toDate();
      final startDateMatch = _selectedStartDate == null
          ? true
          : eventDate.isAfter(_selectedStartDate!.subtract(Duration(days: 1)));
      final endDateMatch = _selectedEndDate == null
          ? true
          : eventDate.isBefore(_selectedEndDate!.add(Duration(days: 1)));
      return queryMatch &&
          categoryMatch &&
          eventTypeMatch &&
          startDateMatch &&
          endDateMatch;
    }).toList();

    // Sort the filtered events by date
    filtered.sort((a, b) {
      DateTime dateA = a['timestamp'].toDate();
      DateTime dateB = b['timestamp'].toDate();
      return _sortOrder == 'Ascending'
          ? dateA.compareTo(dateB)
          : dateB.compareTo(dateA);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: Offset(0, 4),
                    blurRadius: 8),
              ],
            ),
            child: AppBar(
              backgroundColor: Colors.white,
              scrolledUnderElevation: 0,
              title: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_list, color: Colors.grey[800]),
                  onPressed: _showFilterOptions,
                ),
                Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon:
                        Icon(Icons.add_circle_outline, color: Colors.grey[800]),
                    iconSize: 30,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CreateEventScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshEvents,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredEvents.isEmpty
                  ? ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 100),
                        Center(child: Text('No events found.')),
                      ],
                    )
                  : ListView.builder(
                      physics: AlwaysScrollableScrollPhysics(),
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(filteredEvents[index]);
                      },
                    ),
        ),
      ),
    );
  }
}
