import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_explorer/screens/map_screen.dart';
import 'package:provider/provider.dart';
import 'package:map_explorer/providers/location_data_provider.dart';
import 'package:map_explorer/services/auth_service.dart';
import 'package:map_explorer/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Anonymous login
  Future<void> _login() async {
    final name = _nameController.text.trim();
    // Validate name
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'الرجاء إدخال اسمك';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Sign in anonymously
      final userCredential = await authService.signInAnonymously();
      final user = userCredential.user;
      
      if (user != null) {
        // Generate a unique username if needed
        final username = name.isNotEmpty ? name : 'مستخدم_${user.uid.substring(0, 5)}';
        // Set the display name
        await user.updateDisplayName(username);
        // Store user data in Firestore with comprehensive fields
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': username,
          'displayName': username,  // For consistency
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
          'authType': 'anonymous',
          'email': null,  // Anonymous users don't have emails
          'phoneNumber': null,
          'photoURL': null,
          'locations': [],  // Array of created location IDs
          'comments': [],   // Array of comment IDs
          'votes': [],      // Array of vote IDs
          'appVersion': '1.0.0',  // Track which app version they're using
          'deviceInfo': Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Other',
        }, SetOptions(merge: true));

        // Update provider with user ID
        if (mounted) {
          // We use Future.microtask to ensure we're not updating state during build
          Future.microtask(() {
            final provider = Provider.of<LocationDataProvider>(context, listen: false);
            provider.setCurrentUserId(user.uid);
            // Set the username in the provider
            provider.setUserName(username);
            // Navigate to map screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MapScreen()),
              (route) => false,
            );
          });
        }
      }
    } catch (e) {
      logger.e('Login error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google Sign In
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userCredential = await authService.signInWithGoogle();
      
      // User cancelled the sign-in
      if (userCredential == null) {
        setState(() {
          _isGoogleLoading = false;
        });
        return;
      }
      
      final user = userCredential.user;
      if (user != null && mounted) {
        // Update provider with user ID
        Future.microtask(() {
          final provider = Provider.of<LocationDataProvider>(context, listen: false);
          provider.setCurrentUserId(user.uid);
          // Set the username
          if (user.displayName != null) {
            provider.setUserName(user.displayName!);
          }
          // Navigate to map screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MapScreen()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      logger.e('Google Sign-In error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تسجيل الدخول بجوجل: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo/icon
              const Icon(
                Icons.map,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              // App title
              const Text(
                'نجم سهيل',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // App description
              const Text(
                'استكشف المواقع وشارك تجاربك',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Google Sign-In button
              ElevatedButton.icon(
                onPressed: _isGoogleLoading || _isLoading ? null : _signInWithGoogle,
                icon: Image.asset(
                  'assets/images/google_logo.png', // Add this image to your assets
                  height: 24.0,
                ),
                label: _isGoogleLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('تسجيل الدخول بحساب Google'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shadowColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('أو'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              // Name input field
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسمك',
                  hintText: 'أدخل اسمك',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                autofocus: false,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.right,
                  ),
                ),
              const SizedBox(height: 24),
              // Login button
              ElevatedButton(
                onPressed: _isLoading || _isGoogleLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('جاري تسجيل الدخول...'),
                        ],
                      )
                    : const Text(
                        'تسجيل الدخول بدون حساب',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
              const SizedBox(height: 16),
              // Skip for now button
              TextButton(
                onPressed: _isLoading || _isGoogleLoading
                    ? null
                    : () {
                        // Generate random username and continue
                        _nameController.text = 'زائر_${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 13)}';
                        _login();
                      },
                child: const Text(
                  'المتابعة كزائر',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
