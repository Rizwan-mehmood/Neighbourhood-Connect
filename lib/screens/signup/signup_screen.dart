import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _isGoogleLoading = false;

  // Track error messages for validation
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _firstNameError;
  String? _lastNameError;
  String? _authError;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Password validation regex
  String passwordRegex =
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$';

  Future<void> _onRefresh() async {
    // Simulate a delay for refreshing (you can remove this if it's an immediate operation)
    await Future.delayed(const Duration(seconds: 2));

    // Reset fields and hide loader
    _resetFields();
  }

  void _resetFields() {
    setState(() {
      _emailController.clear();
      _passwordController.clear();
      _emailError = null;
      _passwordError = null;
      _authError = null;
      _isLoading = false;
      _isGoogleLoading = false;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _firstNameError = null;
      _lastNameError = null;
    });
  }

  Future<void> _signUp() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();

    // Reset error messages
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _firstNameError = null;
      _lastNameError = null;
    });

    bool isValid = true;

    // First name validation
    if (firstName.isEmpty) {
      setState(() {
        _firstNameError = 'First name is required';
      });
      isValid = false;
    } else if (!RegExp(r"^[a-zA-Z. ]+$").hasMatch(firstName)) {
      setState(() {
        _firstNameError = 'First name must only contain alphabets and "."';
      });
      isValid = false;
    }

    // Last name validation
    if (lastName.isEmpty) {
      setState(() {
        _lastNameError = 'Last name is required';
      });
      isValid = false;
    } else if (!RegExp(r"^[a-zA-Z ]+$").hasMatch(lastName)) {
      setState(() {
        _lastNameError = 'Last name must only contain alphabets';
      });
      isValid = false;
    }

    // Email validation
    if (email.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      isValid = false;
    } else if (!RegExp(
            r"^[a-zA-Z0-9._%+-]+@(gmail|yahoo|hotmail|outlook)\.com$")
        .hasMatch(email)) {
      setState(() {
        _emailError =
            'Only Gmail, Yahoo, Hotmail, or Outlook emails are allowed';
      });
      isValid = false;
    }

    // Password validation
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
      });
      isValid = false;
    } else if (!RegExp(passwordRegex).hasMatch(password)) {
      setState(() {
        _passwordError = '''
      Password must contain at least:
      • One uppercase letter
      • One lowercase letter
      • One number
      • One special character
      ''';
      });
      isValid = false;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordError = 'Confirm password is required';
      });
      isValid = false;
    } else if (password != confirmPassword) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      isValid = false;
    }

    if (!isValid) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Create user with email and password
      final firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      firebase_auth.User? user = userCredential.user;

      if (user != null) {
        // Create user record in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'userId': userCredential.user!.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'profilePicture': null, // Default empty profile picture
          'location': const GeoPoint(0.0, 0.0), // Default empty location
          'createdAt': FieldValue.serverTimestamp(),
          'bio': '',
          'isActive': true,
        });

        // Send email verification
        await user.sendEmailVerification();
        // Show success message
        Fluttertoast.showToast(
          msg: 'A verification email has been sent. Please verify your email.',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 3,
        );

        // Redirect to login screen
        Navigator.pop(context);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error during sign-up: ${e.message}',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Unexpected error: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    try {
      setState(() {
        _isGoogleLoading = true;
      });

      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final firebase_auth.OAuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      firebase_auth.UserCredential userCredential = await firebase_auth
          .FirebaseAuth.instance
          .signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if user already exists in Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // Create new user in Firestore if not exists
          FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'userId': userCredential.user!.uid,
            'firstName': googleUser.displayName?.split(' ').first ?? '',
            'lastName': googleUser.displayName?.split(' ').last ?? '',
            'email': googleUser.email,
            'profilePicture': googleUser.photoUrl ?? null,
            'location': GeoPoint(0.0, 0.0),
            'bio': '',
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });
        }

        // User is logged in and verified
        setState(() {
          _isGoogleLoading = false;
        });
        await connectStreamChat(userCredential.user!.uid);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on firebase_auth.FirebaseAuthException catch (_) {
      setState(() {
        _isGoogleLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Google sign-in failed',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          // Dismiss the keyboard when tapping outside text fields
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login.png'),
                // Use background image from Code B
                fit: BoxFit.cover,
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              body: Stack(
                children: [
                  // Title Text
                  Container(
                    padding: EdgeInsets.only(left: 35, top: 30),
                    child: Text(
                      'Create\nAccount',
                      style: TextStyle(color: Colors.white, fontSize: 33),
                    ),
                  ),
                  // Scrollable Form
                  SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.only(
                          top: MediaQuery.of(context).size.height * 0.28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 35, right: 35),
                            child: Column(
                              children: [
                                // Centered _authError text above the email field
                                if (_authError !=
                                    null) // Check if there is an error
                                  Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      _authError ?? '',
                                      // Display _authError message
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                SizedBox(height: 10),
                                // First Name TextField
                                _buildTextField(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  errorText: _firstNameError,
                                  prefixIcon: Icons.person,
                                ),
                                SizedBox(height: 10),

                                // Last Name TextField
                                _buildTextField(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  errorText: _lastNameError,
                                  prefixIcon: Icons.person,
                                ),
                                SizedBox(height: 10),

                                // Email TextField
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  errorText: _emailError,
                                  prefixIcon: Icons.email,
                                ),
                                SizedBox(height: 10),

                                // Password TextField
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  errorText: _passwordError,
                                  prefixIcon: Icons.lock,
                                  obscureText: !_passwordVisible,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: 10),

                                // Confirm Password TextField
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  errorText: _confirmPasswordError,
                                  prefixIcon: Icons.lock,
                                  obscureText: !_passwordVisible,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: 20),

                                // Sign Up Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xff4c505b),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 100, vertical: 10),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _isLoading
                                      ? CircularProgressIndicator(
                                          color: Colors.white)
                                      : Text('Sign Up',
                                          style: TextStyle(fontSize: 18)),
                                ),

                                SizedBox(height: 10),
                                // OR Line with Text
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Text(
                                        "or",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),

                                // Google Sign Up Button
                                ElevatedButton(
                                  onPressed: _isGoogleLoading
                                      ? null
                                      : _signUpWithGoogle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    side: const BorderSide(color: Colors.grey),
                                    foregroundColor: Colors.black,
                                  ),
                                  child: _isGoogleLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/images/google_icon.png',
                                              height: 24,
                                              width: 24,
                                            ),
                                            const SizedBox(width: 10),
                                            const Text('Sign up with Google',
                                                style: TextStyle(fontSize: 18)),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  // Helper function to build text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: (_) {
            setState(() {
              // Clear error messages when user starts typing
              if (controller == _emailController) _emailError = null;
              if (controller == _passwordController) _passwordError = null;
              if (controller == _confirmPasswordController)
                _confirmPasswordError = null;
              if (controller == _firstNameController) _firstNameError = null;
              if (controller == _lastNameController) _lastNameError = null;
            });
          },
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: suffixIcon,
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
            errorText: null, // We'll manage error text outside the TextField
          ),
        ),
        // Display error message if it exists
        if (errorText != null && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              softWrap: true, // Ensures long text wraps to the next line
            ),
          ),
      ],
    );
  }
}
