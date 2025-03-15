import 'package:flutter/material.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/services/location_service.dart';

class LocationDataProvider with ChangeNotifier {
  final FirebaseLocationService _firebaseService = FirebaseLocationService();
  
  List<Location> _locations = [];
  bool _isLoading = true;
  
  // Filter settings
  bool _showHistorical = true;
  bool _showForests = true;
  bool _showCities = true;
  bool _showOther = true;
  
  LocationDataProvider() {
    // Load locations when provider is created
    _loadLocations();
  }
  
  // Getters
  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;
  bool get showHistorical => _showHistorical;
  bool get showForests => _showForests;
  bool get showCities => _showCities;
  bool get showOther => _showOther;
  
  // Get filtered locations
  List<Location> get filteredLocations {
    return _locations.where((location) {
      switch (location.type) {
        case LocationType.historical:
          return _showHistorical;
        case LocationType.forest:
          return _showForests;
        case LocationType.city:
          return _showCities;
        case LocationType.other:
          return _showOther;
      }
    }).toList();
  }
  
  // Load locations from Firebase
  Future<void> _loadLocations() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _locations = await _firebaseService.getLocations();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading locations: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshLocations() async {
    await _loadLocations();
  }
  // Add a new location
  Future<void> addLocation(Location location) async {
    try {
      await _firebaseService.addLocation(location);
      // Reload to get the newly added location
      await _loadLocations();
    } catch (e) {
      print('Error adding location: $e');
      rethrow;
    }
  }
  
  // Toggle filters
  void toggleHistorical() {
    _showHistorical = !_showHistorical;
    notifyListeners();
  }
  
  void toggleForests() {
    _showForests = !_showForests;
    notifyListeners();
  }
  
  void toggleCities() {
    _showCities = !_showCities;
    notifyListeners();
  }
  
  void toggleOther() {
    _showOther = !_showOther;
    notifyListeners();
  }
  
  void setAllFilters(bool value) {
    _showHistorical = value;
    _showForests = value;
    _showCities = value;
    _showOther = value;
    notifyListeners();
  }
}









  // final List<Location> _locations = [
  //   Location(
  //     id: '1',
  //     name: 'Old City of Jerusalem',
  //     description: 'Historic walled area with religious sites including the Western Wall, Church of the Holy Sepulchre, and Dome of the Rock.',
  //     type: LocationType.historical,
  //     latitude: 31.7767,
  //     longitude: 35.2345,
  //     createdAt: DateTime.now().subtract(const Duration(days: 100)),
  //   ),
  //   Location(
  //     id: '2',
  //     name: 'Dead Sea',
  //     description: 'Salt lake bordered by Jordan and Israel/Palestine, known for its buoyancy and mineral-rich mud. Its shores are Earth\'s lowest point on land.',
  //     type: LocationType.forest,
  //     latitude: 31.5497,
  //     longitude: 35.4730,
  //     createdAt: DateTime.now().subtract(const Duration(days: 50)),
  //   ),
  //   Location(
  //     id: '3',
  //     name: 'Tel Aviv',
  //     description: 'Coastal city known for its vibrant culture, beaches, and Bauhaus architecture.',
  //     type: LocationType.city,
  //     latitude: 32.0853,
  //     longitude: 34.7818,
  //     createdAt: DateTime.now().subtract(const Duration(days: 25)),
  //   ),
  //   Location(
  //     id: '4',
  //     name: 'Church of the Nativity',
  //     description: 'Birthplace of Jesus in Bethlehem, one of the oldest operating churches in the world.',
  //     type: LocationType.historical,
  //     latitude: 31.7042,
  //     longitude: 35.2062,
  //     createdAt: DateTime.now().subtract(const Duration(days: 200)),
  //   ),
  //   Location(
  //     id: '5',
  //     name: 'Ein Gedi Nature Reserve',
  //     description: 'Oasis near the Dead Sea with hiking trails, waterfalls, and diverse wildlife.',
  //     type: LocationType.forest,
  //     latitude: 31.4667,
  //     longitude: 35.3833,
  //     createdAt: DateTime.now().subtract(const Duration(days: 75)),
  //   ),
  //   Location(
  //     id: '6',
  //     name: 'Haifa',
  //     description: 'Northern port city built on the slopes of Mount Carmel, home to the Bahá\'í Gardens.',
  //     type: LocationType.city,
  //     latitude: 32.7940,
  //     longitude: 34.9896,
  //     createdAt: DateTime.now().subtract(const Duration(days: 120)),
  //   ),
  //   Location(
  //     id: '7',
  //     name: 'Al-Aqsa Mosque',
  //     description: 'Located on the Temple Mount in Jerusalem, one of the holiest sites in Islam.',
  //     type: LocationType.historical,
  //     latitude: 31.7761,
  //     longitude: 35.2358,
  //     createdAt: DateTime.now().subtract(const Duration(days: 150)),
  //   ),
  //   Location(
  //     id: '8',
  //     name: 'Masada',
  //     description: 'Ancient fortress on a plateau overlooking the Dead Sea, site of the last stand of Jewish rebels against the Romans.',
  //     type: LocationType.historical,
  //     latitude: 31.3158,
  //     longitude: 35.3512,
  //     createdAt: DateTime.now().subtract(const Duration(days: 180)),
  //   ),
  //   Location(
  //     id: '9',
  //     name: 'Gaza City',
  //     description: 'Largest city in the Gaza Strip, located on the Mediterranean coast.',
  //     type: LocationType.city,
  //     latitude: 31.5017,
  //     longitude: 34.4668,
  //     createdAt: DateTime.now().subtract(const Duration(days: 90)),
  //   ),
  //   Location(
  //     id: '10',
  //     name: 'Jericho',
  //     description: 'One of the oldest continuously inhabited cities in the world, located in the West Bank.',
  //     type: LocationType.city,
  //     latitude: 31.8667,
  //     longitude: 35.4500,
  //     createdAt: DateTime.now().subtract(const Duration(days: 110)),
  //   ),
  // ];