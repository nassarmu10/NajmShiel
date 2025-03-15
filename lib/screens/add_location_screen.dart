import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../providers/location_data_provider.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({Key? key}) : super(key: key);

  @override
  _AddLocationScreenState createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final MapController mapController = MapController();
  
  String _name = '';
  String _description = '';
  LocationType _selectedType = LocationType.historical;
  LatLng? _selectedLocation;
  
  // Israel and Palestine center coordinates
  final LatLng countryCenter = const LatLng(31.5, 35.0);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Location'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Instructions
            const Text(
              'Tap on the map to select a location',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            
            // Location selection map
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    center: countryCenter,
                    zoom: 9.0,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.country_map_explorer',
                      additionalOptions: const {
                        'attribution': '© OpenStreetMap contributors',
                      },
                    ),
                    // Show marker if location selected
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: Icon(
                            Icons.location_pin,
                            color: Colors.white,
                            size: 20,
                          ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            if (_selectedLocation == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'A location must be selected on the map',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Location name
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Location Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              validator: (value) => 
                value == null || value.isEmpty ? 'Please enter a name' : null,
              onChanged: (value) => _name = value,
            ),
            
            const SizedBox(height: 16),
            
            // Location type dropdown
            DropdownButtonFormField<LocationType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Location Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: LocationType.values.map((type) {
                IconData icon;
                String label;
                
                switch (type) {
                  case LocationType.historical:
                    icon = Icons.history;
                    label = 'Historical Site';
                    break;
                  case LocationType.forest:
                    icon = Icons.forest;
                    label = 'Natural Area';
                    break;
                  case LocationType.city:
                    icon = Icons.location_city;
                    label = 'Urban Area';
                    break;
                  case LocationType.other:
                    icon = Icons.place;
                    label = 'Other';
                    break;
                }
                
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: (value) => 
                value == null || value.isEmpty ? 'Please enter a description' : null,
              onChanged: (value) => _description = value,
            ),
            
            const SizedBox(height: 24),
            
            // Submit button
            ElevatedButton(
              onPressed: _submitLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ADD LOCATION'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _submitLocation() {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      // Create a new location
      final newLocation = Location(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID
        name: _name,
        description: _description,
        type: _selectedType,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        createdAt: DateTime.now(),
      );
      
      // Add to provider
      Provider.of<LocationDataProvider>(context, listen: false)
          .addLocation(newLocation);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location added successfully!')),
      );
      
      // Return to map
      Navigator.pop(context);
    } else {
      // Show validation error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a location on the map.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
