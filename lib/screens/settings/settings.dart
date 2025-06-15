import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_switch/flutter_switch.dart';

class ScreenEventSettingsScreen extends StatefulWidget {
  @override
  _ScreenEventSettingsScreenState createState() =>
      _ScreenEventSettingsScreenState();
}

class _ScreenEventSettingsScreenState extends State<ScreenEventSettingsScreen> {
  // Mapping titles to corresponding icons
  final Map<String, IconData> titleToIcon = {
    "Location Settings": Icons.location_on,
    "Notification Preferences": Icons.notifications,
    "Privacy Settings": Icons.lock,
    "App Preferences": Icons.settings,
    "Account Settings": Icons.account_circle,
    "Help & Support": Icons.help,
    "Security Settings": Icons.security,
    "Data & Storage": Icons.storage,
    "SOS Settings": Icons.phone_in_talk, // Added SOS icon
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2), // Shadow color
                blurRadius: 8.0, // Blur effect
                offset: Offset(0, 2), // Offset of shadow (X, Y)
              ),
            ],
          ),
          child: AppBar(
            title: Text("Settings"),
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black),
            elevation: 0,
            // Remove default elevation to avoid double shadow
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          _buildSettingsTile(
              context, "Location Settings", LocationSettingsScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(context, "Notification Preferences",
              NotificationPreferencesScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(
              context, "Privacy Settings", PrivacySettingsScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(
              context, "App Preferences", AppPreferencesScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(
              context, "Account Settings", AccountSettingsScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(context, "Help & Support", HelpSupportScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(
              context, "Security Settings", SecuritySettingsScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(context, "Data & Storage", DataStorageScreen()),
          _buildCustomDivider(),
          _buildSettingsTile(context, "SOS Settings", SOSSettingsScreen()),
          // SOS settings added
          _buildCustomDivider(),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildSettingsTile(BuildContext context, String title,
      Widget destinationScreen) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: Icon(
        titleToIcon[title], // Fetching icon based on the title
        size: 24,
        color: Colors.black,
      ),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, size: 24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
    );
  }

  Widget _buildCustomDivider() {
    return Divider(
      thickness: 1,
      height: 0, // No additional space between divider and content
      color: Colors.grey[200],
    );
  }
}

// Placeholder screens for each section
class LocationSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Location Settings")),
      body: Center(child: Text("Location settings go here")),
    );
  }
}

class NotificationPreferencesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notification Preferences")),
      body: Center(child: Text("Notification preferences go here")),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Privacy Settings")),
      body: Center(child: Text("Privacy settings go here")),
    );
  }
}

class AppPreferencesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("App Preferences")),
      body: Center(child: Text("App preferences go here")),
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Account Settings")),
      body: Center(child: Text("Account settings go here")),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Help & Support")),
      body: Center(child: Text("Help & support options go here")),
    );
  }
}

class SecuritySettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Security Settings")),
      body: Center(child: Text("Security settings go here")),
    );
  }
}

class DataStorageScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Data & Storage")),
      body: Center(child: Text("Data and storage settings go here")),
    );
  }
}

class SOSSettingsScreen extends StatefulWidget {
  @override
  _SOSSettingsScreenState createState() => _SOSSettingsScreenState();
}

class _SOSSettingsScreenState extends State<SOSSettingsScreen> {
  bool isSOSEnabled = false;
  List<Contact> contacts = [];
  List<String> selectedNumbers = [];
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool isLoading = true; // Track loading state

  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSOSStatus();
    _fetchData();
  }

  // Fetch both contacts and Firebase data together
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    await _fetchContacts();
    await _fetchSelectedContacts();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadSOSStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isSOSEnabled = prefs.getBool('isSOSEnabled') ?? false;
    });
  }

  Future<void> _saveSOSStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSOSEnabled', value);
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final List<Contact> contactList = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      setState(() {
        contacts = contactList;
      });
    }
  }

  Future<void> _fetchSelectedContacts() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('phone_numbers')
        .doc(currentUserId)
        .get();
    if (doc.exists) {
      setState(() {
        selectedNumbers = List<String>.from(doc['numbers'] ?? []);
      });
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text("SOS Settings Help"),
          content: Text(
              "Enable SOS: When you turn your screen on and off 5 times quickly within 3 seconds, an emergency SOS alert will be sent to your selected contacts. You can select up to 5 contacts. Along with the SOS alert, your current location and a help message will be sent to ensure quick assistance during emergencies or dangerous situations."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleContact(String phoneNumber, bool enable) async {
    if (enable) {
      if (selectedNumbers.length >= 5) return;
      selectedNumbers.add(phoneNumber);
    } else {
      selectedNumbers.remove(phoneNumber);
    }

    await FirebaseFirestore.instance
        .collection('phone_numbers')
        .doc(currentUserId)
        .set({'numbers': selectedNumbers}, SetOptions(merge: true));

    setState(() {});
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            scrolledUnderElevation: 0,
            title: Text("SOS Settings"),
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.black),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.help_outline, color: Colors.black),
                onPressed: () {
                  _showHelpDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Enable Toggle
            Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(
                  'Enable SOS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text(
                  'Enable SOS feature for emergencies.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: SizedBox(
                  width: 70,
                  child: FlutterSwitch(
                    width: 35.0,
                    height: 20.0,
                    toggleSize: 15.0,
                    value: isSOSEnabled,
                    borderRadius: 30.0,
                    padding: 4.0,
                    activeColor: Colors.green,
                    inactiveColor: Colors.redAccent,
                    onToggle: (bool value) async {
                      try {
                        const channel = MethodChannel(
                            'com.example.neighborhood_connect/screen_events');
                        await channel.invokeMethod(
                            'toggleScreenEvent', {'enable': value});
                        setState(() => isSOSEnabled = value);
                        await _saveSOSStatus(value);
                      } on PlatformException catch (e) {
                        setState(() => isSOSEnabled = !value);
                      }
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),

            if (isSOSEnabled) ...[
              // Tabs for SMS and App Notification
              DefaultTabController(
                length: 2,
                child: Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: [
                          Tab(text: "SMS"),
                          Tab(text: "App Notification"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildSMSContacts(), // SMS tab
                            _buildAppNotification(), // Empty for now
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// SMS Contacts Tab (Same as before)
  Widget _buildSMSContacts() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey[300],
        ),
      ],
    );
  }

// Placeholder for App Notification Tab
  Widget _buildAppNotification() {
    return Center(
      child: Text(
        "App Notification settings will be added here.",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}
