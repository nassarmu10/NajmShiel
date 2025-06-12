import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/utils/image_utils.dart';
import 'package:map_explorer/utils/location_type_utils.dart';
import 'package:provider/provider.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:google_places_flutter/model/place_type.dart';
import '../models/location.dart';
import '../providers/location_data_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddLocationScreen extends StatefulWidget {
  const AddLocationScreen({super.key});

  @override
  AddLocationScreenState createState() => AddLocationScreenState();
}

class AddLocationScreenState extends State<AddLocationScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final MapController mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode(); // Add focus node for description

  String _name = '';
  String _description = '';
  LocationType _selectedType = LocationType.historical;
  LatLng? _selectedLocation;
  bool _isLoadingLocation = true;
  bool _editMapMode = false;
  // For image handling
  final List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;
  bool _isMapInitialized = false;
  Set<LocationType> _selectedTags = {};

  // Google Places API key - replace with your actual API key
  final String _apiKey = 'AIzaSyDyTiCCwe5jFJQOL3nv8TRJ2OonydYI6Zs';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize with default location first
    _selectedLocation = countryCenter;

    // Add focus listener for search
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        // Scroll to the search field when it gets focus
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent * 0.3,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Add focus listener for description field
    _descriptionFocusNode.addListener(() {
      if (_descriptionFocusNode.hasFocus) {
        // Scroll to the bottom when description field gets focus
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

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
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _descriptionFocusNode.dispose(); // Dispose description focus node
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
        logger.e('Error checking location services: $e');
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
        logger.e('Error requesting location permission: $e');
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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        logger.e('Error getting current location: $e');
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
          logger.e('Error moving map: $e');
          // Even if map movement fails, we've already set the location in state
        }
      });
    } catch (e) {
      logger.e('General error getting location: $e');
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
    try {
      final newImages = await ImageUtils.pickAndCompressMultipleImages(context);
      if (newImages.isNotEmpty && mounted) {
        setState(() {
          _selectedImages.addAll(newImages);
        });
      }
    } catch (e) {
      logger.e('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصور: $e')),
        );
      }
    }
  }

  // Method to take a photo
  Future<void> _takePhoto() async {
    try {
      final photo = await ImageUtils.takeAndCompressPhoto(context);
      if (photo != null && mounted) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      logger.e('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التقاط الصورة: $e')),
        );
      }
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

  // Add this method after the existing methods
  Widget _buildTagSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'العلامات (يمكن اختيار أكثر من علامة):',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LocationType.values.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? LocationTypeUtils.getColor(tag).withOpacity(0.2)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? LocationTypeUtils.getColor(tag)
                        : Colors.grey[400]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LocationTypeUtils.getIcon(tag),
                      size: 16,
                      color: isSelected
                          ? LocationTypeUtils.getColor(tag)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      LocationTypeUtils.getDisplayName(tag),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? LocationTypeUtils.getColor(tag)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove resizeToAvoidBottomInset: false to allow keyboard adjustment
      appBar: AppBar(
        title: const Text('إضافة موقع جديد'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView( // Change from ListView to SingleChildScrollView
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column( // Change from children to child with Column
            children: [
              // Location name - always show this
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'اسم الموقع',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                  alignLabelWithHint: true,
                  helperText: 'أدخل اسم الموقع كما تريد أن يظهر في التطبيق',
                ),
                textAlign: TextAlign.right,
                validator: (value) =>
                    value == null || value.isEmpty ? 'الرجاء إدخال اسم' : null,
                onChanged: (value) => _name = value,
              ),

              const SizedBox(height: 16),

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
                              decoration: const BoxDecoration(
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
                    border: Border.all(
                        color: Colors.grey.shade400, style: BorderStyle.solid),
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
                  color: _editMapMode
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
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

              // Google Places Autocomplete - only show when in edit mode
              if (_editMapMode)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GooglePlaceAutoCompleteTextField(
                    googleAPIKey: _apiKey,
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    countries: const ["il", "ps"],
                    inputDecoration: const InputDecoration(
                      labelText: 'ابحث عن موقع على الخريطة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      alignLabelWithHint: true,
                      hintText: 'اسم الموقع',
                    ),
                    debounceTime: 800,
                    isLatLngRequired: true,
                    isCrossBtnShown: true,
                    containerHorizontalPadding: 10,
                    placeType: PlaceType.geocode,
                    getPlaceDetailWithLatLng: (Prediction prediction) {
                      if (prediction.lat != null && prediction.lng != null) {
                        setState(() {
                          _selectedLocation = LatLng(
                            double.parse(prediction.lat!),
                            double.parse(prediction.lng!),
                          );
                        });
                        // Move map to selected location
                        mapController.move(_selectedLocation!, 14.0);
                      }
                    },
                    itemClick: (Prediction prediction) {
                      _searchController.text = prediction.description ?? '';
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(
                            offset: prediction.description?.length ?? 0),
                      );
                    },
                    itemBuilder: (context, index, Prediction prediction) {
                      // Format the description to remove "Israel" and clean up the text
                      String formattedDescription =
                          prediction.description ?? '';
                      formattedDescription = formattedDescription
                          .replaceAll(', Israel', '')
                          .replaceAll('Israel', '')
                          .replaceAll('ישראל', '')
                          .trim();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formattedDescription,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    seperatedBuilder: const Divider(height: 1),
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
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.najmshiel.map',
                            maxZoom: 18,
                            retinaMode: RetinaMode.isHighDensity(context),
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
                  icon: Icon(
                      _editMapMode ? Icons.my_location : Icons.edit_location),
                  label:
                      Text(_editMapMode ? 'استخدام موقعي' : 'تعديل موقع الخريطة'),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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

              // tag selection
              _buildTagSelection(),
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
                items: LocationTypeUtils.getDropdownItems(),
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
                focusNode: _descriptionFocusNode, // Add focus node
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                  helperText: 'يمكنك إضافة روابط مثل: https://example.com',
                  helperMaxLines: 2,
                ),
                maxLines: 5,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('جاري التحميل...'),
                        ],
                      )
                    : const Text('إضافة الموقع'),
              ),
              
              // Add extra padding at the bottom to ensure submit button is visible
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitLocation() async {
    if (!mounted) return;

    if (_formKey.currentState?.validate() != true ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى ملء جميع الحقول المطلوبة وتحديد موقع على الخريطة.',
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
      // Get the location provider to access user data
      final locationProvider =
          Provider.of<LocationDataProvider>(context, listen: false);

      // Get current username
      final username = await locationProvider.getUserName();

      // 1. Upload images to Cloudinary (if any)
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        // Show progress message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'جاري تحميل ${_selectedImages.length} صورة...',
                textAlign: TextAlign.right,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Upload each image
        for (var image in _selectedImages) {
          final imageUrl = await ImageUtils.uploadToCloudinary(
            image,
            context: context,
            cloudName: 'dchx2vghg',
            uploadPreset: 'location_images',
            folder: 'locations',
          );

          if (imageUrl != null) {
            imageUrls.add(imageUrl);
          }
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
        createdBy: locationProvider.currentUserId,
        creatorName: username,
        tags: _selectedTags.toList(),
      );

      // Add to provider
      if (mounted) {
        // We're now using the enhanced model with GeoPoint
        await locationProvider.addLocation(newLocation);

        if (mounted) {
          // 4. Success handling
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
      }
    } catch (e) {
      // 5. Error handling
      logger.e('Error submitting location: $e');

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
