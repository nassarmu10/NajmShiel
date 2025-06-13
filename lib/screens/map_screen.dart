import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/screens/add_location_screen.dart';
import 'package:map_explorer/screens/profile_screen.dart';
import 'package:map_explorer/utils/location_type_utils.dart';
import 'package:map_explorer/widgets/filter_option_widget.dart';
import 'package:map_explorer/widgets/location_preview_widget.dart';
import 'package:map_explorer/widgets/location_search_delegate.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import '../models/location.dart';
import '../providers/location_data_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final MapController mapController = MapController();

  final LatLng defaultCenter = const LatLng(31.5, 35.0);
  final double initialZoom = 8.0;
  final double userLocationZoom =
      14.0; // Closer zoom when user location is available

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLocationReady = false;
  LatLng? _userLocation;
  String _errorMessage = '';
  double _currentZoom = 8.0;
  double _currentHeading = 0.0; // For storing the compass heading
  StreamSubscription<Position>?
      _positionStreamSubscription; // For continuous updates
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _hasCompass = false; // Start as false until we confirm availability
  Location? _selectedLocation;
  bool _isSearchVisible = false;
  bool _hasUserMovedMap = false;

  String get _mapUrlTemplate {
    final deviceLanguage = Platform.localeName.split('_')[0];
    return deviceLanguage == 'he'
        ? 'https://israelhiking.osm.org.il/Tiles/{z}/{x}/{y}.png'
        : 'https://israelhiking.osm.org.il/English/Tiles/{z}/{x}/{y}.png';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize data first
    _initializeDataSafely().then((_) {
      if (!mounted) return;
      
      // Initialize location services in the background
      _initializeLocationServices();
    });

    // Listen for map events
    mapController.mapEventStream.listen((MapEvent event) {
      if (event is MapEventMoveEnd && mounted) {
        setState(() {
          _currentZoom = event.camera.zoom;
          _hasUserMovedMap = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _selectedLocation = null;
    // Cancel the position stream when disposing the screen
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Initialize compass with proper error handling
  Future<void> _initializeCompass() async {
    try {
      // First check if the device has a compass
      final hasCompass = await FlutterCompass.events?.first
              .then((_) => true)
              .catchError((_) => false) ??
          false;

      if (!hasCompass) {
        logger.i('Device does not have a compass');
        if (mounted) {
          setState(() {
            _hasCompass = false;
          });
        }
        return;
      }

      // Request motion permission on iOS
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        try {
          // First check if we already have permission
          final status = await Permission.sensors.status;
          if (status.isDenied) {
            // Request permission only if not already granted
            final result = await Permission.sensors.request();
            if (result.isDenied) {
              logger.i('Motion permission denied on iOS');
              if (mounted) {
                setState(() {
                  _hasCompass = false;
                });
              }
              return;
            }
          }
        } catch (e) {
          logger.e('Error requesting motion permission: $e');
          if (mounted) {
            setState(() {
              _hasCompass = false;
            });
          }
          return;
        }
      }

      // Start compass listener
      _startCompassListener();

      if (mounted) {
        setState(() {
          _hasCompass = true;
        });
      }
    } catch (e) {
      logger.e('Error initializing compass: $e');
      if (mounted) {
        setState(() {
          _hasCompass = false;
        });
      }
    }
  }

  // Start compass listener to get heading updates
  void _startCompassListener() async {
    try {
      // Subscribe to compass events
      _compassSubscription = FlutterCompass.events?.listen(
        (CompassEvent event) {
          if (event.heading != null && mounted) {
            setState(() {
              _currentHeading = event.heading!;
            });
          }
        },
        onError: (error) {
          logger.e('Error in compass stream: $error');
          if (mounted) {
            setState(() {
              _hasCompass = false;
            });
          }
        },
      );
    } catch (e) {
      logger.e('Error starting compass listener: $e');
      if (mounted) {
        setState(() {
          _hasCompass = false;
        });
      }
    }
  }

  // Method to start real-time location updates
  Future<void> _startPositionStream() async {
    // Check permission first
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return; // Can't start stream without permission
    }

    // Define location settings with more frequent updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Update every 2 meters of movement
      timeLimit: null, // No time limit
    );

    // Cancel any existing subscription first
    await _positionStreamSubscription?.cancel();

    try {
      // Start the position stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          if (mounted) {
            final newLocation = LatLng(position.latitude, position.longitude);
            setState(() {
              _userLocation = newLocation;
              // Update heading if available
              if (position.heading != 0) {
                _currentHeading = position.heading;
              }
            });

            // If this is the first location update or user hasn't manually moved the map
            if (!_hasUserMovedMap) {
              mapController.move(newLocation, _currentZoom);
            }
          }
        },
        onError: (error) {
          logger.e('Error in position stream: $error');
          // Try to restart the stream after a delay if there's an error
          if (mounted) {
            Future.delayed(const Duration(seconds: 5), () {
              _startPositionStream();
            });
          }
        },
      );
    } catch (e) {
      logger.e('Error starting position stream: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app is resumed, refresh data if needed
      if (!mounted) return;
      final provider =
          Provider.of<LocationDataProvider>(context, listen: false);
      provider.refreshLocations();

      // Also refresh location if we don't have it yet
      if (_userLocation == null) {
        _getCurrentLocation();
      }
    }
  }

  // Enhanced getCurrentLocation method with heading information
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    logger.i("Getting current location with heading");

    try {
      // Check if we already have location - if so, just center on it
      if (_userLocation != null) {
        // Center map on user location without reloading
        mapController.move(_userLocation!, userLocationZoom);
        return;
      }
      setState(() {
        _isLoading = true; // Use existing _isLoading variable
        _isLocationReady = false;
      });

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
          _isLoading = false;
          _isLocationReady = false;
          _userLocation = defaultCenter; // Use existing defaultCenter
        });
        return;
      }

      // Request permission
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
          _isLoading = false;
          _isLocationReady = false;
          _userLocation = defaultCenter;
        });
        return;
      }

      // Get current position with timeout
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
          // desiredAccuracy: LocationAccuracy.high,
          // timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        logger.e('Error getting current location: $e');
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _isLocationReady = false;
          _userLocation = defaultCenter;
        });
        return;
      }

      if (!mounted) return;

      // Update location and heading in state
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);

        // Update heading if available and not zero
        if (position.heading > 0.0) {
          _currentHeading = position.heading;
          logger.i('Initial heading: $_currentHeading');
        }

        _isLoading = false;
        _isLocationReady = true;
      });

      // Wait for map controller to be ready before moving
      await Future.delayed(const Duration(milliseconds: 500));

      // Final mounted check before manipulating map
      if (!mounted) return;

      // Use safe post-frame callback to move map
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && _userLocation != null) {
            mapController.move(_userLocation!, userLocationZoom);
          }
        } catch (e) {
          logger.e('Error moving map camera: $e');
        }
      });
    } catch (e) {
      logger.e('General error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحصول على الموقع: ${e.toString()}'),
          ),
        );
        setState(() {
          _isLoading = false;
          _isLocationReady = false;
          _userLocation = defaultCenter;
        });
      }
    }
  }

  // Initialize data safely without triggering rebuild during build
  Future<void> _initializeDataSafely() async {
    try {
      // Set a temporary user ID without triggering notifications
      final provider =
          Provider.of<LocationDataProvider>(context, listen: false);

      // Set default user ID without triggering rebuild
      provider.setCurrentUserId('anonymous_user', notify: false);

      // Initialize data silently
      await provider.silentInitialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeLocationServices() async {
    try {
      // Check location services without showing UI yet
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.i('Location services disabled');
        return;
      }

      // Check permission status without requesting
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        // Get initial position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
            _isLocationReady = true;
          });

          // Move map to current location
          mapController.move(_userLocation!, userLocationZoom);
        }

        // Start continuous updates
        _startPositionStream();
      }

      // Initialize compass in background
      _initializeCompass();
    } catch (e) {
      logger.e('Error initializing location services: $e');
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _isLocationReady = false;
      _userLocation = null;
    });
    _initializeDataSafely();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/applogononame.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'نجم سهيل',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              final provider =
                  Provider.of<LocationDataProvider>(context, listen: false);
              showSearch(
                context: context,
                delegate: LocationSearchDelegate(
                  locations: provider.locations,
                  onLocationSelected: (location) {
                    mapController.move(location.latLng, userLocationZoom);
                    setState(() {
                      _selectedLocation = location;
                    });
                  },
                ),
              );
            },
            tooltip: 'بحث',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'الملف الشخصي',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
            tooltip: 'تصفية المواقع',
          ),
        ],
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
      ),
      body: Stack(
        children: [
          _buildMainContent(),
          if (_selectedLocation != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: 0,
              child: LocationPreviewWidget(
                location: _selectedLocation!,
                onTap: () => _showLocationDetails(_selectedLocation!.id),
                onClose: () {
                  setState(() {
                    _selectedLocation = null;
                  });
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "location",
            onPressed: () {
              _getCurrentLocation();
              setState(() {
                _selectedLocation = null;
                _hasUserMovedMap = false;
              });
            },
            mini: true,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });
              final provider =
                  Provider.of<LocationDataProvider>(context, listen: false);
              await provider.refreshLocations();
              setState(() {
                _isLoading = false;
              });
            },
            mini: true,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "add",
            onPressed: () {
              // Navigate to add location without initial location (original behavior)
              Navigator.pushNamed(context, '/add_location');
            },
            child: const Icon(Icons.add_location_alt),
          ),
          SizedBox(height: _selectedLocation != null ? 160 : 0),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الخريطة...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return _buildMap();
  }

  // Calculate marker size based on zoom level
  double _getMarkerSize(double zoom) {
    // Base size at minimum zoom
    const double minSize = 12.0;
    // Maximum size at maximum zoom
    const double maxSize = 32.0;
    // Minimum zoom level for size calculation
    const double minZoom = 5.0;
    // Maximum zoom level for size calculation
    const double maxZoom = 18.0;

    // Clamp zoom level between min and max
    zoom = zoom.clamp(minZoom, maxZoom);

    // Calculate size using exponential scaling for more natural growth
    double scale = (zoom - minZoom) / (maxZoom - minZoom);
    double size = minSize + (maxSize - minSize) * math.pow(scale, 0.7);

    return size;
  }

  // Get icon size based on current zoom
  double get _iconSize {
    return _getMarkerSize(_currentZoom) * 0.7;
  }

  // Get circle size based on current zoom (slightly larger than icon for touch target)
  double get _circleSize {
    return _getMarkerSize(_currentZoom);
  }

  Widget _buildMap() {
    return Consumer<LocationDataProvider>(
      builder: (context, locationProvider, child) {
        final locations = locationProvider.filteredLocations;
        final initialCenter = _userLocation ?? defaultCenter;
        final initialZoomLevel = _userLocation != null ? userLocationZoom : initialZoom;

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoomLevel,
                maxZoom: 18.0,
                minZoom: 8.0,
                onMapReady: () {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                onTap: (_, __) {
                  setState(() {
                    _selectedLocation = null;
                  });
                },
                // Add long press handler
                onLongPress: (tapPosition, point) {
                  _showAddLocationDialog(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapUrlTemplate,
                  maxZoom: 18.0,
                  minZoom: 8.0,
                  keepBuffer: 2,
                  backgroundColor: Colors.white,
                  userAgentPackageName: 'il.org.osm.israelhiking',
                  tileProvider: const FMTCStore('hiking_map').getTileProvider(),
                  additionalOptions: const {
                    'attribution': '© Israel Hiking Map contributors',
                  },
                ),
                // User location marker (if available)
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: _getMarkerSize(_currentZoom) * 1.5,
                        height: _getMarkerSize(_currentZoom) * 1.5,
                        point: _userLocation!,
                        child: Transform.rotate(
                          angle: _hasCompass
                              ? (_currentHeading * (math.pi / 180))
                              : 0,
                          child: Container(
                            child: Icon(
                              Icons.navigation,
                              color: Colors.blue,
                              size: _getMarkerSize(_currentZoom) * 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                // Location markers
                MarkerLayer(
                  markers: locations.map((location) {
                    final markerSize = _getMarkerSize(_currentZoom);
                    return Marker(
                      width: markerSize,
                      height: markerSize,
                      point: location.latLng,
                      child: GestureDetector(
                        onTap: () {
                          logger.i('Marker tapped: ${location.id}');
                          setState(() {
                            _selectedLocation = location;
                          });
                          // Optionally center the map on the selected location
                          mapController.move(location.latLng,
                              _currentZoom > 12 ? _currentZoom : 12);
                        },
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Stack(
                                children: [
                                  // Shadow effect
                                  Container(
                                    height: markerSize,
                                    width: markerSize,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        // Highlight the selected location marker
                                        color: _selectedLocation?.id ==
                                                location.id
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.2),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      LocationTypeUtils.getIcon(
                                          location.type),
                                      color: Colors.white,
                                      size: markerSize * 0.6,
                                    ),
                                  ),
                                  // Marker background
                                  Container(
                                    height: markerSize - 2,
                                    width: markerSize - 2,
                                    decoration: BoxDecoration(
                                      color: LocationTypeUtils.getColor(
                                          location.type),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: GestureDetector(
                                      child: Icon(
                                        LocationTypeUtils.getIcon(
                                            location.type),
                                        color: Colors.white,
                                        size: markerSize * 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // Show loading indicator while map is initializing
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        );
      },
    );
  }

  void _showAddLocationDialog(LatLng point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'إضافة موقع جديد',
            textAlign: TextAlign.right,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'هل تريد إضافة موقع جديد في هذا المكان؟',
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Text(
                'الإحداثيات: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToAddLocation(point);
              },
              child: const Text('إضافة موقع'),
            ),
          ],
        );
      },
    );
  }

  // Add this method to MapScreen class
  void _navigateToAddLocation(LatLng point) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLocationScreen(
          initialLocation: point,
        ),
      ),
    );
  }

  void _showLocationDetails(String locationId) {
    // Clear the selection when navigating to details
    setState(() {
      _selectedLocation = null;
    });

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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'تصفية المواقع',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.right,
                            ),
                          ),

                          // Quick action buttons
                          TextButton(
                            onPressed: () {
                              setState(() {
                                locationProvider.setAllFilters(true);
                              });
                            },
                            child: const Text('الكل'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                locationProvider.setAllFilters(false);
                              });
                            },
                            child: const Text('لا شيء'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Historical filter
                      FilterOptionWidget(
                        locationType: LocationType.historical,
                        isSelected: locationProvider.showHistorical,
                        onChanged: (value) =>
                            locationProvider.toggleHistorical(),
                      ),

                      // Forests filter
                      FilterOptionWidget(
                        locationType: LocationType.forest,
                        isSelected: locationProvider.showForests,
                        onChanged: (value) => locationProvider.toggleForests(),
                      ),

                      // Cities filter
                      FilterOptionWidget(
                        locationType: LocationType.city,
                        isSelected: locationProvider.showCities,
                        onChanged: (value) => locationProvider.toggleCities(),
                      ),

                      FilterOptionWidget(
                        locationType: LocationType.barbecue,
                        isSelected: locationProvider.showBarbecue,
                        onChanged: (value) => locationProvider.toggleBarbecue(),
                      ),

                      // Family filter
                      FilterOptionWidget(
                        locationType: LocationType.family,
                        isSelected: locationProvider.showFamily,
                        onChanged: (value) => locationProvider.toggleFamily(),
                      ),

                      // Viewpoint filter
                      FilterOptionWidget(
                        locationType: LocationType.viewpoint,
                        isSelected: locationProvider.showViewpoint,
                        onChanged: (value) =>
                            locationProvider.toggleViewpoint(),
                      ),

                      // Beach filter
                      FilterOptionWidget(
                        locationType: LocationType.beach,
                        isSelected: locationProvider.showBeach,
                        onChanged: (value) => locationProvider.toggleBeach(),
                      ),

                      // Hiking filter
                      FilterOptionWidget(
                        locationType: LocationType.hiking,
                        isSelected: locationProvider.showHiking,
                        onChanged: (value) => locationProvider.toggleHiking(),
                      ),

                      // Camping filter
                      FilterOptionWidget(
                        locationType: LocationType.camping,
                        isSelected: locationProvider.showCamping,
                        onChanged: (value) => locationProvider.toggleCamping(),
                      ),
                      // Water Spring filter
                      FilterOptionWidget(
                        locationType: LocationType.waterSpring,
                        isSelected: locationProvider.showWaterSpring,
                        onChanged: (value) =>
                            locationProvider.toggleWaterSpring(),
                      ),

                      // Mosque filter
                      FilterOptionWidget(
                        locationType: LocationType.mosque,
                        isSelected: locationProvider.showMosque,
                        onChanged: (value) => locationProvider.toggleMosque(),
                      ),

                      // Church filter
                      FilterOptionWidget(
                        locationType: LocationType.church,
                        isSelected: locationProvider.showChurch,
                        onChanged: (value) => locationProvider.toggleChurch(),
                      ),

                      // Other filter
                      FilterOptionWidget(
                        locationType: LocationType.other,
                        isSelected: locationProvider.showOther,
                        onChanged: (value) => locationProvider.toggleOther(),
                      ),

                      // Actions
                      Center(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('تطبيق الفلتر'),
                        ),
                      ),
                    ],
                  ),
                ));
          },
        );
      },
    );
  }
}
