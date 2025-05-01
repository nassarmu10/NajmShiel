import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:map_explorer/screens/location_details_screen.dart';
import 'package:provider/provider.dart';

import 'providers/location_data_provider.dart';
import 'screens/map_screen.dart';
import 'screens/add_location_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'logger.dart';

void main() {
  // Show a loading screen immediately
  runApp(const LoadingApp());
  
  // Then initialize Firebase and the main app
  initializeApp();
}

// Simple loading screen to show immediately
class LoadingApp extends StatelessWidget {
  const LoadingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Just use an icon instead of trying to load an asset
              Icon(
                Icons.map,
                size: 120,
                color: Colors.blue,
              ),
              SizedBox(height: 24),
              Text(
                'نجم سهيل',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

// Initialize Firebase and the app in the background
Future<void> initializeApp() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    // Create auth service
    final authService = AuthService();
    // Replace loading app with the real app
    runApp(MyApp(authService: authService));
  } catch (e) {
    // Show error screen if initialization fails
    logger.e('Error initializing app: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

// The main app
class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({Key? key, required this.authService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Create provider without loading data immediately
        ChangeNotifierProvider(create: (context) => LocationDataProvider()),
        // Add auth service provider
        Provider<AuthService>.value(value: authService),
      ],
      child: MaterialApp(
        title: 'نجم سهيل',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: AuthWrapper(),
        routes: {
          '/add_location': (context) => const AddLocationScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/location_details') {
            final locationId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => LocationDetailsScreen(locationId: locationId),
            );
          }
          return null;
        },
      ),
    );
  }
}

// Auth wrapper to handle authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  AuthWrapperState createState() => AuthWrapperState();
}

class AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          // Update the user ID in the provider after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final locationProvider = Provider.of<LocationDataProvider>(context, listen: false);
            locationProvider.setCurrentUserId(user.uid);
          });
          // Return the map screen
          return const MapScreen();
        }
        // If not logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}

// Error screen in case initialization fails
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'حدث خطأ أثناء تهيئة التطبيق',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Attempt to restart the app
                    initializeApp();
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
