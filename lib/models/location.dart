import 'package:latlong2/latlong.dart';

enum LocationType {
  historical,
  forest,
  city,
  other
}

class Location {
  final String id;
  final String name;
  final String description;
  final LocationType type;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  Location({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  // Convenience getter for LatLng
  LatLng get latLng => LatLng(latitude, longitude);

  // Display name for the type
  String get typeDisplayName {
    switch (type) {
      case LocationType.historical:
        return 'Historical Site';
      case LocationType.forest:
        return 'Natural Area';
      case LocationType.city:
        return 'Urban Area';
      case LocationType.other:
        return 'Other';
    }
  }
}
