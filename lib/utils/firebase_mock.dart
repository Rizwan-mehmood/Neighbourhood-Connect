import 'package:firebase_auth/firebase_auth.dart' as real_firebase_auth;

class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth._();

  FirebaseAuth._();

  User? get currentUser {
    final realUser = real_firebase_auth.FirebaseAuth.instance.currentUser;
    if (realUser == null) return null;
    return User(uid: realUser.uid);
  }
}

class User {
  final String uid;

  User({required this.uid});
}

// Simplified mock version of FirebaseFirestore
// This will be used for demo purposes without actual Firebase
class FirebaseStorage {
  static final FirebaseStorage instance = FirebaseStorage._();

  FirebaseStorage._();

  Reference ref() {
    return Reference();
  }
}

class Reference {
  Reference child(String path) {
    return Reference();
  }

  Future<TaskSnapshot> putFile(dynamic file) async {
    return TaskSnapshot();
  }

  Future<String> getDownloadURL() async {
    return 'https://picsum.photos/800/600';
  }
}

class TaskSnapshot {}

// Mock implementation of Geolocator for demo
class GeolocatorMock {
  static Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
  }) async {
    // Return a mock position
    return Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  static Future<LocationPermission> checkPermission() async {
    return LocationPermission.always;
  }

  static Future<LocationPermission> requestPermission() async {
    return LocationPermission.always;
  }

  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    // Mock distance calculation
    return 1000.0; // 1 km in meters
  }
}

class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final double speedAccuracy;

  Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
    required this.speedAccuracy,
  });
}

enum LocationAccuracy { lowest, low, medium, high, best, navigation }

enum LocationPermission { denied, deniedForever, whileInUse, always }
