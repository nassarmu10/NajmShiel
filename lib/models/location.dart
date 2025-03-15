import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Create from Firestore document
  factory Location.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse the type from string
    LocationType locationType;
    try {
      locationType = LocationType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => LocationType.other,
      );
    } catch (_) {
      locationType = LocationType.other;
    }
    
    // Handle timestamp from Firestore
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }
    
    return Location(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Location',
      description: data['description'] ?? '',
      type: locationType,
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      createdAt: createdAtDate,
    );
  }
}
