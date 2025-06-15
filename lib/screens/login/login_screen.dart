import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../main.dart';
import '../home/home_screen.dart';
import '../signup/signup_screen.dart';
import 'package:stream_chat/stream_chat.dart' as stream;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _authError;

  Future<void> _onRefresh() async {
    // Simulate a delay for refreshing (you can remove this if it's an immediate operation)
    await Future.delayed(const Duration(seconds: 2));

    // Reset fields and hide loader
    _resetFields();
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _resetFields() {
    setState(() {
      FocusScope.of(context).requestFocus(FocusNode());
      _emailController.clear();
      _passwordController.clear();
      _emailError = null;
      _passwordError = null;
      _authError = null;
      _isLoading = false;
      _isGoogleLoading = false;
    });
  }

  bool _validateFields() {
    bool isValid = true;
    setState(() {
      if (_emailController.text.isEmpty) {
        _emailError = 'Email is required';
        isValid = false;
      } else if (!_emailController.text.contains('@')) {
        _emailError = 'Enter a valid email';
        isValid = false;
      } else {
        _emailError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = 'Password is required';
        isValid = false;
      } else {
        _passwordError = null;
      }
    });
    return isValid;
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }

      // Obtain authentication details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      setState(() {
        _isGoogleLoading = false;
      });

      if (user != null) {
        // Check if user exists in Firestore; if not, create a new record.
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'userId': user.uid,
            'firstName': googleUser.displayName?.split(' ').first ?? '',
            'lastName': googleUser.displayName?.split(' ').last ?? '',
            'email': user.email ?? '',
            'profilePicture': user.photoURL ?? '',
            'location': const GeoPoint(0.0, 0.0),
            'bio': '',
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });
        }

        await connectStreamChat(user.uid);
        // Navigate to the Home screen.
        Navigator.pushReplacementNamed(context, '/goToHome');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in failed. Please try again.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGoogleLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'An error occurred during Google sign-in. Please try again.'),
        ),
      );
    }
  }

  Future<void> _login() async {
    if (_validateFields()) {
      try {
        setState(() {
          _isLoading = true;
        });

        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (userCredential.user != null) {
          User user = userCredential.user!;

          if (user.emailVerified) {
            await connectStreamChat(user.uid);
            Navigator.pushReplacementNamed(context, '/goToHome');
          } else {
            _showVerificationDialog(user);
          }
        }
      } on FirebaseAuthException catch (_) {
        setState(() {
          _isLoading = false;
          _authError = 'Email or password is incorrect';
        });
      }
    }
  }

  void _showVerificationDialog(User user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Your email is not verified. Please check your inbox and verify your email address.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await user.sendEmailVerification();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Verification email sent! Check your inbox.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Send Verification Email Again'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendPasswordRecoveryEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Navigator.pop(context); // Close the popup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If the email is registered, a password reset link will be sent.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    String? emailError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Forgot Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Enter your email',
                      errorText: emailError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        emailError = null;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final email = emailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      setState(() {
                        emailError = 'Enter a valid email';
                      });
                    } else {
                      _sendPasswordRecoveryEmail(email);
                    }
                  },
                  child: const Text('Send Recovery Email'),
                ),
              ],
            );
          },
        );
      },
    );
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
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Title Text
                Container(
                  padding: EdgeInsets.only(left: 35, top: 130),
                  child: Text(
                    'Welcome\nBack',
                    style: TextStyle(color: Colors.white, fontSize: 33),
                  ),
                ),
                // Scrollable Login Form
                SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * 0.42),
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

                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                errorText: _emailError,
                                prefixIcon: Icons.email,
                                onChanged: (text) {
                                  setState(() {
                                    _emailError = null;
                                  });
                                },
                              ),
                              SizedBox(height: 20),

                              // Password Text Field
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
                                onChanged: (text) {
                                  setState(() {
                                    _passwordError = null;
                                  });
                                },
                              ),
                              SizedBox(height: 10),

                              // Login Button
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sign in',
                                    style: TextStyle(
                                        fontSize: 27,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Color(0xff4c505b),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : IconButton(
                                            color: Colors.white,
                                            onPressed:
                                                _isLoading ? null : _login,
                                            icon: Icon(
                                              Icons.arrow_forward,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),

                              // Forgot Password and SignUp Links
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Sign Up',
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          color: Color(0xff4c505b),
                                          fontSize: 18),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: Text(
                                      'Forgot Password',
                                      style: TextStyle(
                                        decoration: TextDecoration.underline,
                                        color: Color(0xff4c505b),
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
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
                              SizedBox(height: 20),

                              // Google SignIn Button
                              ElevatedButton(
                                onPressed:
                                    _isGoogleLoading ? null : _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
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
                                          const Text('Sign in with Google',
                                              style: TextStyle(fontSize: 18)),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 30)
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    IconData? prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        errorText: errorText,
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
        ),
      ),
    );
  }
}
