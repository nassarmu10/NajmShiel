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

class _AddLocationScreenState extends State<AddLocationScreen> with WidgetsBindingObserver {
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
  bool _isMapInitialized = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize with default location first 
    _selectedLocation = countryCenter;
    
    // Delay the location request to ensure widget tree is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Further delay to ensure map controller is initialized
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _safeGetCurrentLocation();
        }
      });
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isMapInitialized) {
      // Add a delay before trying to get location again
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _safeGetCurrentLocation();
        }
      });
    }
  }
  
  final LatLng countryCenter = const LatLng(31.5, 35.0);

  Future<void> _safeGetCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      _isMapInitialized = true;
      
      // Check if location services are enabled
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        );
      } catch (e) {
        print('Error checking location services: $e');
        serviceEnabled = false;
      }
      
      if (!serviceEnabled) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خدمات الموقع معطلة. يرجى تمكينها في الإعدادات.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _editMapMode = true; // Switch to manual mode
          _selectedLocation = countryCenter; // Set a default location
        });
        return;
      }
      
      // Request permission with timeout
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission().timeout(
          const Duration(seconds: 3),
          onTimeout: () => LocationPermission.denied,
        );
        
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission().timeout(
            const Duration(seconds: 5),
            onTimeout: () => LocationPermission.denied,
          );
        }
      } catch (e) {
        print('Error requesting location permission: $e');
        permission = LocationPermission.denied;
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض إذن الموقع.'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _editMapMode = true;
          _selectedLocation = countryCenter; // Set a default location
        });
        return;
      }
      
      // Get current position with timeout
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        print('Error getting current location: $e');
        if (!mounted) return;
        
        setState(() {
          _isLoadingLocation = false;
          _editMapMode = true;
          _selectedLocation = countryCenter; // Set a default location
        });
        return;
      }
      
      if (!mounted) return;
      
      // Update location in state
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      
      // Wait for map controller to be ready before moving
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Final mounted check before manipulating map
      if (!mounted) return;
      
      // Use safe post-frame callback to move map
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && mapController != null) {
            mapController.move(_selectedLocation!, 13.0);
          }
        } catch (e) {
          print('Error moving map: $e');
          // Even if map movement fails, we've already set the location in state
        }
      });
    } catch (e) {
      print('General error getting location: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الحصول على الموقع: ${e.toString()}'),
        ),
      );
      setState(() {
        _isLoadingLocation = false;
        _editMapMode = true;
        _selectedLocation = countryCenter; // Set a default location
      });
    }
  }

  // Method to pick images from gallery
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage();
      if (images.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الصور: $e')),
      );
    }
  }

  // Method to take a photo
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في التقاط الصورة: $e')),
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
      _safeGetCurrentLocation();
    }
    setState(() {
      _editMapMode = !_editMapMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة موقع جديد'),
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
                const Expanded(
                  child: Text(
                    'الصور (اختياري)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                // Camera button
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _takePhoto,
                  tooltip: 'التقاط صورة',
                ),
                // Gallery button
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  onPressed: _pickImages,
                  tooltip: 'اختيار من المعرض',
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
                    'لم يتم اختيار صور.\nانقر على رمز الكاميرا أو المعرض لإضافة صور.',
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
                        ? 'انقر على الخريطة لتحديد موقع'
                        : 'استخدام موقعك الحالي',
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
                        initialCenter: _selectedLocation ?? countryCenter,
                        initialZoom: 8.0,
                        onTap: (tapPosition, point) {
                          if (_editMapMode && mounted) {
                            setState(() {
                              _selectedLocation = point;
                            });
                          }
                        },
                        interactionOptions: const InteractionOptions(
                          enableMultiFingerGestureRace: true,
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 
                          // Switch to a simpler tile source without retina mode
                          userAgentPackageName: 'com.example.najmshiel',
                          maxZoom: 18,
                          retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
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
                  ? 'استخدام موقعي' 
                  : 'تعديل موقع الخريطة'),
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
                  'يجب تحديد موقع على الخريطة',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
              
            const SizedBox(height: 16),
              
            // Location name
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'اسم الموقع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
                alignLabelWithHint: true,
              ),
              textAlign: TextAlign.right,
              validator: (value) => 
                value == null || value.isEmpty ? 'الرجاء إدخال اسم' : null,
              onChanged: (value) => _name = value,
            ),
              
            const SizedBox(height: 16),
              
            // Location type dropdown
            DropdownButtonFormField<LocationType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع الموقع',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
                alignLabelWithHint: true,
              ),
              items: LocationType.values.map((type) {
                IconData icon;
                String label;
                  
                switch (type) {
                  case LocationType.historical:
                    icon = Icons.history;
                    label = 'موقع تاريخي';
                    break;
                  case LocationType.forest:
                    icon = Icons.forest;
                    label = 'منطقة طبيعية';
                    break;
                  case LocationType.city:
                    icon = Icons.location_city;
                    label = 'منطقة حضرية';
                    break;
                  case LocationType.other:
                    icon = Icons.place;
                    label = 'أخرى';
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
                if (value != null && mounted) {
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
                labelText: 'الوصف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textAlign: TextAlign.right,
              validator: (value) => 
                value == null || value.isEmpty ? 'الرجاء إدخال وصف' : null,
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
                      Text('جاري التحميل...'),
                    ],
                  )
                : const Text('إضافة الموقع'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _submitLocation() async {
    if (!mounted) return;
    
    if (_formKey.currentState?.validate() != true || _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى ملء جميع الحقول وتحديد موقع على الخريطة.',
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'جاري تحميل ${_selectedImages.length} صورة...',
                textAlign: TextAlign.right,
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
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
      if (mounted) {
        await Provider.of<LocationDataProvider>(context, listen: false)
          .addLocation(newLocation);
      }

      // 4. Success handling
      if (mounted) {
        // Hide loading indicator
        setState(() {
          _isUploadingImages = false;
        });
      
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تمت إضافة الموقع بنجاح!',
              textAlign: TextAlign.right,
            ),
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
            content: Text(
              'خطأ: ${e.toString()}',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
