import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:neighborhood_connect/screens/chat/chat_screen.dart';
import 'package:neighborhood_connect/screens/createPost/post_creation_screen.dart';
import 'package:neighborhood_connect/screens/events/event_screen.dart';
import 'package:neighborhood_connect/screens/logout/logout.dart';
import 'package:neighborhood_connect/screens/marketplace_home_screen.dart';
import 'package:neighborhood_connect/screens/notification/notification_screen.dart';
import 'package:neighborhood_connect/screens/settings/settings.dart';
import 'screens/welcome/welcome_screen.dart';
import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'screens/profile/profile.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as stream;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'screens/marketplace/marketplace_screen.dart';

final stream.StreamChatClient streamClient =
    stream.StreamChatClient('xvmj3bxbwdkg');

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  bool hasLocationPermission = await requestLocationPermission();
  bool hasContactsPermission = await requestContactsPermission();
  bool hasTelephonyPermission = await requestTelephonyPermission();

  if (!hasLocationPermission ||
      !hasContactsPermission ||
      !hasTelephonyPermission) {
    return;
  }

  await initializeNotifications();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;
  fb.User? currentUser = fb.FirebaseAuth.instance.currentUser;

  if (currentUser != null) {
    await connectStreamChat(currentUser.uid);
  }

  runApp(MyApp(
    hasSeenWelcome: hasSeenWelcome,
    currentUser: currentUser,
    streamClient: streamClient,
  ));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      debugPrint("Notification clicked with payload: ${response.payload}");
      navigatorKey.currentState?.pushNamed('/notifications');
    },
  );

  // Request notification permission.
  PermissionStatus status = await Permission.notification.request();
  if (status.isGranted) {
    debugPrint("Notification permission granted");
  } else if (status.isDenied) {
    debugPrint("Notification permission denied");
  } else if (status.isPermanentlyDenied) {
    debugPrint("Notification permission permanently denied");
    await openAppSettings();
  }
}

Future<bool> requestLocationPermission() async {
  PermissionStatus status = await Permission.location.request();
  if (status.isGranted) {
    debugPrint("Location permission granted");
    return true;
  } else if (status.isDenied) {
    debugPrint("Location permission denied");
    return false;
  } else if (status.isPermanentlyDenied) {
    debugPrint("Location permission permanently denied");
    await openAppSettings();
    return false;
  }
  return false;
}

Future<bool> requestContactsPermission() async {
  PermissionStatus status = await Permission.contacts.request();
  if (status.isGranted) {
    debugPrint("Contacts permission granted");
    return true;
  } else if (status.isDenied) {
    debugPrint("Contacts permission denied");
    return false;
  } else if (status.isPermanentlyDenied) {
    debugPrint("Contacts permission permanently denied");
    await openAppSettings();
    return false;
  }
  return false;
}

Future<bool> requestTelephonyPermission() async {
  PermissionStatus status = await Permission.sms.request();
  if (status.isGranted) {
    debugPrint("Telephony permission granted");
    return true;
  } else if (status.isDenied) {
    debugPrint("Telephony permission denied");
    return false;
  } else if (status.isPermanentlyDenied) {
    debugPrint("Telephony permission permanently denied");
    await openAppSettings();
    return false;
  }
  return false;
}

Future<void> connectStreamChat(String userId) async {
  // If already connected for the same user, simply return.
  if (streamClient.state.currentUser != null &&
      streamClient.state.currentUser!.id == userId) {
    debugPrint('User already connected: $userId');
    return;
  }

  final stream.User user = stream.User(
    id: userId,
  );

  final String tokenEndpoint =
      'https://stream-chat-token.netlify.app/.netlify/functions/generateToken?userId=$userId';
  final http.Response response = await http.get(Uri.parse(tokenEndpoint));

  if (response.statusCode == 200) {
    final Map<String, dynamic> tokenData = jsonDecode(response.body);
    final String token = tokenData['token'] as String;
    await streamClient.connectUser(user, token);
    debugPrint(
        'Stream user successfully connected: ${streamClient.state.currentUser?.id}');
  } else {
    debugPrint('Error fetching token: ${response.statusCode} ${response.body}');
  }
}

class MyApp extends StatelessWidget {
  final bool hasSeenWelcome;
  final fb.User? currentUser;
  final stream.StreamChatClient streamClient;

  const MyApp({
    Key? key,
    required this.hasSeenWelcome,
    this.currentUser,
    required this.streamClient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(primarySwatch: Colors.blue);

    return MaterialApp(
      title: 'Neighborhood Connect',
      theme: theme,
      builder: (context, child) {
        return stream.StreamChat(
          client: streamClient,
          streamChatThemeData: stream.StreamChatThemeData.fromTheme(theme),
          child: child!,
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => hasSeenWelcome
            ? (currentUser != null ? MainScreen() : LoginScreen())
            : WelcomeScreen(),
        '/home': (context) => MainScreen(),
        '/login': (context) => LoginScreen(),
        '/logout': (context) => Logout(),
        '/profile': (context) => ProfileScreen(),
        '/events': (context) => EventsScreen(),
        '/settings': (context) => ScreenEventSettingsScreen(),
        '/goToHome': (context) => GoToHomeScreen(),
        '/refreshScreens': (context) => MainScreen(),
        '/notifications': (context) => NotificationScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class GoToHomeScreen extends StatefulWidget {
  @override
  _GoToHomeScreenState createState() => _GoToHomeScreenState();
}

class _GoToHomeScreenState extends State<GoToHomeScreen> {
  @override
  void initState() {
    super.initState();
    _handleUserLogin();
  }

  Future<void> _handleUserLogin() async {
    fb.User? currentUser = fb.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await connectStreamChat(currentUser.uid);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// New MainScreen Widget with Bottom Navigation and IndexedStack.
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // Default to Home tab.
  bool _isInitialized = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Create your screens and pass the callback to HomeScreen.
    _screens = [
      HomeScreen(onInitialized: _onHomeScreenInitialized),
      EventsScreen(),
      MarketplaceHomeScreen(),
      ChatListScreen(),
    ];
  }

  void _onHomeScreenInitialized() {
    if (!_isInitialized) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Map _currentIndex to bottom navigation bar's index.
    int bottomNavSelectedIndex =
        _currentIndex < 2 ? _currentIndex : _currentIndex + 1;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Overlay the loader until initialization is complete.
          if (!_isInitialized)
            Container(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      // Only show the bottom navigation bar when initialization is complete.
      bottomNavigationBar: _isInitialized
          ? BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              currentIndex: bottomNavSelectedIndex,
              onTap: (index) {
                if (index == 2) {
                  // "Add Post" tapped: push a new instance so it's recreated every time.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PostCreationScreen()),
                  );
                } else {
                  // Map bottom nav index to our preserved _screens index.
                  int newIndex = (index > 2) ? index - 1 : index;
                  setState(() {
                    _currentIndex = newIndex;
                  });
                }
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                  tooltip: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event),
                  label: 'Events',
                  tooltip: 'Events',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add),
                  label: 'Add Post',
                  tooltip: 'Add Post',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.store),
                  label: 'For Sale',
                  tooltip: 'For Sale',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_add),
                  label: 'Chat',
                  tooltip: 'Chat',
                ),
              ],
              selectedLabelStyle: TextStyle(fontSize: 14),
              unselectedLabelStyle: TextStyle(fontSize: 10),
            )
          : null,
    );
  }
}
