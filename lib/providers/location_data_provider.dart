import 'package:flutter/material.dart';
import 'package:map_explorer/models/location.dart';

class LocationDataProvider with ChangeNotifier {
  // Sample locations in the Middle East
  final List<Location> _locations = [
    Location(
      id: '1',
      name: 'Petra',
      description: 'Ancient city carved into rose-colored rock faces, dating back to around 300 B.C. One of the new Seven Wonders of the World.',
      type: LocationType.historical,
      latitude: 30.3285,
      longitude: 35.4444,
      createdAt: DateTime.now().subtract(const Duration(days: 100)),
    ),
    Location(
      id: '2',
      name: 'Wadi Rum',
      description: 'Dramatic desert landscape with massive sandstone mountains and red sand valleys. Known as the Valley of the Moon.',
      type: LocationType.forest,
      latitude: 29.5833,
      longitude: 35.4167,
      createdAt: DateTime.now().subtract(const Duration(days: 50)),
    ),
    Location(
      id: '3',
      name: 'Dubai',
      description: 'Ultramodern city known for luxury shopping, futuristic architecture, and vibrant nightlife.',
      type: LocationType.city,
      latitude: 25.2048,
      longitude: 55.2708,
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    Location(
      id: '4',
      name: 'Pyramids of Giza',
      description: 'Ancient Egyptian pyramids built as tombs for the pharaohs, the only surviving structures of the Seven Wonders of the Ancient World.',
      type: LocationType.historical,
      latitude: 29.9773,
      longitude: 31.1325,
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
    ),
    Location(
      id: '5',
      name: 'Dead Sea',
      description: 'Salt lake bordered by Jordan and Israel, known for its buoyancy and mineral-rich mud. At 430.5 meters below sea level, its shores are Earth\'s lowest point on land.',
      type: LocationType.forest,
      latitude: 31.5000,
      longitude: 35.5000,
      createdAt: DateTime.now().subtract(const Duration(days: 75)),
    ),
    Location(
      id: '6',
      name: 'Jerusalem',
      description: 'Historic city considered holy by three major Abrahamic religions: Judaism, Christianity, and Islam.',
      type: LocationType.city,
      latitude: 31.7683,
      longitude: 35.2137,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    Location(
      id: '7',
      name: 'Burj Khalifa',
      description: 'At 828 meters, it\'s the world\'s tallest building and a global icon.',
      type: LocationType.other,
      latitude: 25.1972,
      longitude: 55.2744,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Location(
      id: '8',
      name: 'Istanbul',
      description: 'Transcontinental city straddling Europe and Asia across the Bosphorus Strait, known for its rich history and cultural heritage.',
      type: LocationType.city,
      latitude: 41.0082,
      longitude: 28.9784,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  // Filter settings
  bool _showHistorical = true;
  bool _showForests = true;
  bool _showCities = true;
  bool _showOther = true;

  // Getters
  List<Location> get locations => _locations;
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

  // Add a new location
  void addLocation(Location location) {
    _locations.add(location);
    notifyListeners();
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

  // Set all filters
  void setAllFilters(bool value) {
    _showHistorical = value;
    _showForests = value;
    _showCities = value;
    _showOther = value;
    notifyListeners();
  }
}
