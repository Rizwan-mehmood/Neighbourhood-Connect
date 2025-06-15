import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:neighborhood_connect/main.dart'; // Adjust import if needed for streamClient

class Logout extends StatefulWidget {
  @override
  _LogoutState createState() => _LogoutState();
}

class _LogoutState extends State<Logout> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _logout();
  }

  Future<void> _logout() async {
    try {
      // Disconnect the Stream Chat user if connected.
      if (streamClient.state.currentUser != null) {
        debugPrint(
            'Disconnecting Stream Chat user: ${streamClient.state.currentUser!.id}');
        await streamClient.disconnectUser();
        // Wait a moment to ensure disconnection is fully processed.
        await Future.delayed(Duration(seconds: 2));
      }

      // Sign out from Firebase Auth.
      await fb.FirebaseAuth.instance.signOut();
      // Small delay to allow Firebase to clear the session.
      await Future.delayed(Duration(seconds: 1));

      // If the user is signed in with Google, disconnect and sign out.
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
        // Wait a moment for GoogleSignIn to fully clear its state.
        await Future.delayed(Duration(seconds: 1));
      }

      // Optionally, clear any stored session or preferences if used.
      // For example:
      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // await prefs.clear();

      // Navigate to the '/login' route.
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A simple loader while the logout process completes.
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
