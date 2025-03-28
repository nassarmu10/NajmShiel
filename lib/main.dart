import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:map_explorer/screens/location_details_screen.dart';
import 'package:provider/provider.dart';

import 'providers/location_data_provider.dart';
import 'screens/map_screen.dart';
import 'screens/add_location_screen.dart';

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
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icon.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.map,
                  size: 120,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'نجم سهيل',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
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
    
    // Replace loading app with the real app
    runApp(const MyApp());
  } catch (e) {
    // Show error screen if initialization fails
    print('Error initializing app: $e');
    runApp(ErrorApp(error: e.toString()));
  }
}

// The main app
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Create provider without loading data immediately
      create: (context) => LocationDataProvider(),
      child: MaterialApp(
        title: 'نجم سهيل',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const MapScreen(),
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
