import 'package:flutter/material.dart';
import '../models/location.dart';

/// Utility class for handling Location Type related operations
class LocationTypeUtils {
  /// Get display name for a location type in Arabic
  static String getDisplayName(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return 'موقع تاريخي';
      case LocationType.forest:
        return 'منطقة طبيعية';
      case LocationType.city:
        return 'منطقة حضرية';
      case LocationType.barbecue:
        return 'أماكن شواء';
      case LocationType.family:
        return 'قعدة عائلية';
      case LocationType.viewpoint:
        return 'مطل';
      case LocationType.beach:
        return 'شاطئ';
      case LocationType.hiking:
        return 'مسار مشي';
      case LocationType.camping:
        return 'مخيم';
      case LocationType.other:
        return 'أخرى';
    }
  }

  /// Get icon for a location type
  static IconData getIcon(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return Icons.history;
      case LocationType.forest:
        return Icons.forest;
      case LocationType.city:
        return Icons.location_city;
      case LocationType.barbecue:
        return Icons.outdoor_grill;
      case LocationType.family:
        return Icons.family_restroom;
      case LocationType.viewpoint:
        return Icons.landscape;
      case LocationType.beach:
        return Icons.beach_access;
      case LocationType.hiking:
        return Icons.hiking;
      case LocationType.camping:
        return Icons.fireplace;
      case LocationType.other:
        return Icons.place;
    }
  }

  /// Get color for a location type
  static Color getColor(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return Colors.brown;
      case LocationType.forest:
        return Colors.green;
      case LocationType.city:
        return Colors.blue;
      case LocationType.barbecue:
        return Colors.deepOrange;
      case LocationType.family:
        return Colors.pink;
      case LocationType.viewpoint:
        return Colors.indigo;
      case LocationType.beach:
        return Colors.amber;
      case LocationType.hiking:
        return Colors.teal;
      case LocationType.camping:
        return Colors.lightGreen;
      case LocationType.other:
        return Colors.purple;
    }
  }
  
  /// Get dropdown items for all location types
  static List<DropdownMenuItem<LocationType>> getDropdownItems() {
    return LocationType.values.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Row(
          children: [
            Icon(getIcon(type)),
            const SizedBox(width: 8),
            Text(getDisplayName(type)),
          ],
        ),
      );
    }).toList();
  }
}
