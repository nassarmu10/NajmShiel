import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../utils/location_type_utils.dart';

enum LocationType {
  historical,
  forest,
  city,
  barbecue,
  family,
  viewpoint,
  beach,
  hiking,
  camping,
  waterSpring,
  mosque,
  church,
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
  final List<String> images;
  final String? createdBy;
  final String? creatorName;
  final List<LocationType> tags;

  Location({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.images = const [],
    this.createdBy,
    this.creatorName,
    this.tags = const [],
  });

  // Convenience getter for LatLng
  LatLng get latLng => LatLng(latitude, longitude);
  
  // Convenience getter for GeoPoint
  GeoPoint get geoPoint => GeoPoint(latitude, longitude);

  // Display name for the type, uses utility class
  String get typeDisplayName => LocationTypeUtils.getDisplayName(type);

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
    
    // Parse tags from list of strings
    List<LocationType> tags = [];
    if (data['tags'] != null && data['tags'] is List) {
      for (String tagString in List<String>.from(data['tags'])) {
        try {
          LocationType tag = LocationType.values.firstWhere(
            (e) => e.toString() == tagString,
          );
          tags.add(tag);
        } catch (_) {
          // Skip invalid tags
        }
      }
    }
    // Handle timestamp from Firestore
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }
    
    // Extract image URLs from Firestore
    List<String> images = [];
    if (data['images'] != null) {
      images = List<String>.from(data['images']);
    }

    // Handle GeoPoint data
    double latitude;
    double longitude;
    
    if (data['location'] is GeoPoint) {
      // If stored as a GeoPoint
      GeoPoint geoPoint = data['location'] as GeoPoint;
      latitude = geoPoint.latitude;
      longitude = geoPoint.longitude;
    } else {
      // Fallback to separate latitude/longitude fields
      latitude = data['latitude'] ?? 0.0;
      longitude = data['longitude'] ?? 0.0;
    }

    return Location(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Location',
      description: data['description'] ?? '',
      type: locationType,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAtDate,
      images: images,
      createdBy: data['createdBy'],
      creatorName: data['creatorName'],
      tags: tags,
    );
  }
  
  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type.toString(),
      'location': GeoPoint(latitude, longitude), // Store as GeoPoint
      'createdAt': FieldValue.serverTimestamp(),
      'images': images,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'tags': tags.map((tag) => tag.toString()).toList(),
    };
  }
}
