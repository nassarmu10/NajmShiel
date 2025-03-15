import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../providers/location_data_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  
  // Israel and Palestine region center and zoom
  final LatLng countryCenter = const LatLng(31.5, 35.0); // Center between Israel and Palestine
  final double initialZoom = 8.0; // Closer zoom to show the region in detail
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نجم سهيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<LocationDataProvider>(context, listen: false)
                  .refreshLocations();
            },
            tooltip: 'Refresh locations',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
            tooltip: 'Filter locations',
          ),
        ],
      ),
      body: Consumer<LocationDataProvider>(
        builder: (context, locationProvider, child) {
          final locations = locationProvider.filteredLocations;
          
          return FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: countryCenter,
              initialZoom: initialZoom,
            ),
            children: [
              // Base map tiles layer with attribution - English/Arabic language preference
              TileLayer(
                // urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.country_map_explorer',
                maxZoom: 19,
                tileBuilder: (context, widget, tile) {
                  return widget;
                },
                additionalOptions: const {
                  'attribution': '© OpenStreetMap contributors',
                },
              ),
              
              // Location markers
              MarkerLayer(
                markers: locations.map((location) => 
                  Marker(
                    point: location.latLng,
                    child: GestureDetector(
                      onTap: () => _showLocationDetails(location.id),
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _getColorForType(location.type),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconForType(location.type),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  )
                ).toList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_location');
        },
        tooltip: 'Add location',
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }
  
  void _showLocationDetails(String locationId) {
    Navigator.pushNamed(
      context, 
      '/location_details',
      arguments: locationId,
    );
  }
  
  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Consumer<LocationDataProvider>(
          builder: (context, locationProvider, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    'Filter Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Historical filter
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(Icons.history, color: _getColorForType(LocationType.historical)),
                        const SizedBox(width: 8),
                        const Text('Historical Places'),
                      ],
                    ),
                    value: locationProvider.showHistorical,
                    onChanged: (value) => locationProvider.toggleHistorical(),
                    dense: true,
                  ),
                  
                  // Forests filter
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(Icons.forest, color: _getColorForType(LocationType.forest)),
                        const SizedBox(width: 8),
                        const Text('Natural Areas'),
                      ],
                    ),
                    value: locationProvider.showForests,
                    onChanged: (value) => locationProvider.toggleForests(),
                    dense: true,
                  ),
                  
                  // Cities filter
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(Icons.location_city, color: _getColorForType(LocationType.city)),
                        const SizedBox(width: 8),
                        const Text('Cities & Towns'),
                      ],
                    ),
                    value: locationProvider.showCities,
                    onChanged: (value) => locationProvider.toggleCities(),
                    dense: true,
                  ),
                  
                  // Other filter
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(Icons.place, color: _getColorForType(LocationType.other)),
                        const SizedBox(width: 8),
                        const Text('Other Places'),
                      ],
                    ),
                    value: locationProvider.showOther,
                    onChanged: (value) => locationProvider.toggleOther(),
                    dense: true,
                  ),
                  
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => locationProvider.setAllFilters(true),
                        child: const Text('SHOW ALL'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                ],
              ),
            ));
          },
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
