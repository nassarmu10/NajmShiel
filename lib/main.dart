import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:map_explorer/screens/location_details_screen.dart';
import 'package:provider/provider.dart';

import 'models/comment.dart';
import 'models/vote.dart';
import 'providers/location_data_provider.dart';
import 'screens/map_screen.dart';
import 'screens/add_location_screen.dart';
import 'widgets/comment_list_widget.dart';
import 'widgets/add_comment_widget.dart';
import 'widgets/vote_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LocationDataProvider(),
      child: MaterialApp(
        title: 'NajmShiel Explorer',
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
