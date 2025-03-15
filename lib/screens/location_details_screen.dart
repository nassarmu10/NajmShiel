import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/location.dart';
import '../providers/location_data_provider.dart';

class LocationDetailsScreen extends StatelessWidget {
  final String locationId;
  
  const LocationDetailsScreen({Key? key, required this.locationId}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<LocationDataProvider>(
      builder: (context, locationProvider, child) {
        // Find the location by ID
        final location = locationProvider.locations.firstWhere(
          (loc) => loc.id == locationId,
          orElse: () => throw Exception('Location not found'),
        );
        
        return Scaffold(
          appBar: AppBar(
            title: Text(location.name),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Map view at the top
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: FlutterMap(
                    options: MapOptions(
                      center: location.latLng,
                      zoom: 12,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.country_map_explorer',
                        additionalOptions: const {
                          'attribution': '© OpenStreetMap contributors',
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: location.latLng,
                            width: 40,
                            height: 40,
                            child: Icon(
                          _getIconForType(location.type),
                          color: Colors.white,
                          size: 20,
                        ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Location details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getColorForType(location.type),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIconForType(location.type),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              location.typeDisplayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        location.description,
                        style: const TextStyle(fontSize: 16),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Date added
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Added on ${DateFormat('MMM d, yyyy').format(location.createdAt)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Coordinates text
                      Text(
                        'Coordinates: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Color _getColorForType(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return Colors.brown;
      case LocationType.forest:
        return Colors.green;
      case LocationType.city:
        return Colors.blue;
      case LocationType.other:
        return Colors.purple;
    }
  }
  
  IconData _getIconForType(LocationType type) {
    switch (type) {
      case LocationType.historical:
        return Icons.history;
      case LocationType.forest:
        return Icons.forest;
      case LocationType.city:
        return Icons.location_city;
      case LocationType.other:
        return Icons.place;
    }
  }
}
