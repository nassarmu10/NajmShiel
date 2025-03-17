import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
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
  bool _isLoadingLocation = true;
  bool _editMapMode = false;
  // For image handling
  List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;
  
  @override
  void initState() {
    super.initState();
    // Get current location when screen loads
    _getCurrentLocation();
  }
  final LatLng countryCenter = const LatLng(31.5, 35.0);

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable in settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _editMapMode = true; // Switch to manual mode
        });
        return;
      }
      
      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied.'),
              duration: Duration(seconds: 3),
            ),
          );
          setState(() {
            _isLoadingLocation = false;
            _editMapMode = true;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions permanently denied.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _editMapMode = true;
        });
        return;
      }
      
      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      
      // Center map on current location
      mapController.move(_selectedLocation!, 13.0);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
        ),
      );
      setState(() {
        _isLoadingLocation = false;
        _editMapMode = true; // Default to manual mode
      });
    }
  }

  // Method to pick images from gallery
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  // Method to take a photo
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }

  // Method to remove an image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }


  // Method to toggle between modes
  void _toggleEditMapMode() {
    if (_editMapMode == true) {
      _getCurrentLocation();
    }
    setState(() {
      _editMapMode = !_editMapMode;
    });
  }

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
          // Image section header
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Images (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Camera button
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: _takePhoto,
                tooltip: 'Take a photo',
              ),
              // Gallery button
              IconButton(
                icon: const Icon(Icons.photo_library),
                onPressed: _pickImages,
                tooltip: 'Select from gallery',
              ),
            ],
          ),

          // Display selected images
          if (_selectedImages.isNotEmpty)
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedImages[index].path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: 0,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: () => _removeImage(index),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          else
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
              ),
              child: const Center(
                child: Text(
                  'No images selected.\nTap the camera or gallery icon to add images.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _editMapMode ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _editMapMode ? Icons.edit_location : Icons.my_location,
                  color: _editMapMode ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _editMapMode 
                      ? 'Tap on the map to select a location'
                      : 'Using your current location',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: _editMapMode ? Colors.blue : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Location selection map
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: countryCenter,
                      initialZoom: 9.0,
                      onTap: (tapPosition, point) {
                        if (_editMapMode) {
                          setState(() {
                            _selectedLocation = point;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
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
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Add loading indicator overlay
                if (_isLoadingLocation)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.7),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Toggle button below the map
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            child: OutlinedButton.icon(
              onPressed: _toggleEditMapMode,
              icon: Icon(_editMapMode ? Icons.my_location : Icons.edit_location),
              label: Text(_editMapMode 
                ? 'Use my location' 
                : 'Edit map location'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              onPressed: _isUploadingImages ? null : _submitLocation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isUploadingImages
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Uploading...'),
                    ],
                  )
                : const Text('ADD LOCATION'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _submitLocation() async {
    if (_formKey.currentState!.validate() && _selectedLocation != null) {
      setState(() {
        _isUploadingImages = true;
      });

      try {
        // 1. Upload images to Cloudinary (if any)
        List<String> imageUrls = [];
        if (_selectedImages.isNotEmpty) {
          // Initialize Cloudinary with your cloud name and upload preset
          final cloudinary = CloudinaryPublic(
            'dchx2vghg',  // Replace with your cloud name
            'location_images',  // Replace with your upload preset name
            cache: false,
          );
          
          // Show progress message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uploading ${_selectedImages.length} image(s)...'),
              duration: Duration(seconds: 2),
            ),
          );
          // Upload each image
          for (var image in _selectedImages) {
            // Create a CloudinaryFile from the image path
            final cloudinaryFile = CloudinaryFile.fromFile(
              image.path,
              folder: 'locations', // Optional folder name in Cloudinary
              resourceType: CloudinaryResourceType.Image,
            );
            
            // Upload to Cloudinary
            final response = await cloudinary.uploadFile(cloudinaryFile);
            
            // Add secure URL to our list
            imageUrls.add(response.secureUrl);
          }
        }

        // Create a new location
        final newLocation = Location(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID
          name: _name,
          description: _description,
          type: _selectedType,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          createdAt: DateTime.now(),
          images: imageUrls, // Cloudinary URLs
        );
        
        // Add to provider
        Provider.of<LocationDataProvider>(context, listen: false)
            .addLocation(newLocation);

        // 4. Success handling
        if (mounted) {
          // Hide loading indicator
          setState(() {
            _isUploadingImages = false;
          });
        
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        
          // Return to map
          Navigator.pop(context);
        }
      } catch (e) {
        // 5. Error handling
        print('Error submitting location: $e');
        
        if (mounted) {
          // Hide loading indicator
          setState(() {
            _isUploadingImages = false;
          });
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
