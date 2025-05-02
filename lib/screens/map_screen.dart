import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/screens/profile_screen.dart';
import 'package:map_explorer/utils/location_type_utils.dart';
import 'package:map_explorer/widgets/filter_option_widget.dart';
import 'package:provider/provider.dart';

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
  final double userLocationZoom = 14.0; // Closer zoom when user location is available

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLocationReady = false;
  LatLng? _userLocation;
  String _errorMessage = '';
  double _currentZoom = 8.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Add listener for zoom changes
    mapController.mapEventStream.listen((MapEvent event) {
      if (event is MapEventMoveEnd) {
        if (mounted) {
          setState(() {
            _currentZoom = event.camera.zoom;
          });
        }
      }
    });

    // Load data first, then get location
    _initializeDataSafely().then((_) {
      // Add a delay before getting location to ensure map is ready
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _getCurrentLocation();
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

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    logger.i("here in _getCurrentLocation");

    try {
      setState(() {
        _isLocationReady = false;
      });

      // Check if location services are enabled
      bool serviceEnabled = false;
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
        if (mounted) {
          setState(() {
            _isLocationReady = true;
          });
        }
        return;
      }
      // Check permission
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
        logger.e('Error checking permissions: $e');
        if (mounted) {
          setState(() {
            _isLocationReady = true;
          });
        }
        return;
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocationReady = true;
          });
        }
        return;
      }

      // Get position
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        if (!mounted) return;

        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLocationReady = true;
        });

        // Wait a moment to ensure the map is ready before moving
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if widget is still mounted and map controller is still valid
        if (mounted && _userLocation != null) {
          // Add extra safety check for postFrameCallback
          bool isMapControllerDisposed = false;
          try {
            // Try to access a property of the map controller to see if it's disposed
            var _ = mapController.camera.zoom;
          } catch (e) {
            isMapControllerDisposed = true;
            logger.e('Map controller is disposed or invalid: $e');
          }

          if (!isMapControllerDisposed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Double-check mounted status again inside callback
              if (!mounted) return;

              try {
                // Check controller state once more
                try {
                  var _ = mapController.camera.zoom;
                } catch (e) {
                  logger.e('Map controller became invalid: $e');
                  return;
                }

                if (mapController.camera.zoom != 0) {
                  mapController.move(_userLocation!, userLocationZoom);
                } else {
                  // If camera not ready, try again after a delay
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (!mounted) return;

                    try {
                      // Final check before moving
                      var _ = mapController.camera.zoom;
                      mapController.move(_userLocation!, userLocationZoom);
                      setState(() {
                        _currentZoom = userLocationZoom;
                      });
                    } catch (e) {
                      logger.e('Delayed move failed, controller invalid: $e');
                    }
                  });
                }
              } catch (e) {
                logger.e('Error moving map camera: $e');
              }
            });
          }
        }
      } catch (e) {
        logger.e('Error getting position: $e');
        if (mounted) {
          setState(() {
            _isLocationReady = true;
          });
        }
      }
    } catch (e) {
      logger.e('General error getting location: $e');
      if (mounted) {
        setState(() {
          _isLocationReady = true;
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align to right for Arabic
          children: [
            const Text(
              'نجم سهيل',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 34,
              width: 34,
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
          ],
        ),
        actions: [
          // Note: In RTL layouts, 'actions' appear on the left side
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
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'موقعي الحالي',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider =
                  Provider.of<LocationDataProvider>(context, listen: false);
              provider.refreshLocations();
            },
            tooltip: 'تحديث المواقع',
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
      body: _buildMainContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_location');
        },
        tooltip: 'إضافة موقع',
        child: const Icon(Icons.add_location_alt),
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

  //  Calculate marker size based on zoom level
  double _getMarkerSize(double zoom) {
    // At zoom <= 8, use small markers
    if (zoom <= 8) return 10;
    // At zoom >= 14, use larger markers
    if (zoom >= 14) return 24;
    // In between, linearly interpolate sizes
    return 10 + ((zoom - 8) / 6) * 14; // Linear interpolation between 10 and 24
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

        // For initial center, use user location if available, otherwise use default
        final initialCenter = _userLocation ?? defaultCenter;
        final initialMapZoom =
            _userLocation != null ? userLocationZoom : initialZoom;

        return Stack(
          children: [
            Builder(
              builder: (context) {
                try {
                  return FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: initialMapZoom,
                      interactionOptions: const InteractionOptions(
                        enableMultiFingerGestureRace: true,
                        enableScrollWheel: true,
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      // TileLayer(
                      //   urlTemplate:
                      //       'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                      //   subdomains: const ['a', 'b', 'c'],
                      //   userAgentPackageName: 'com.najmshiel.map',
                      //   maxZoom: 18,
                      //   retinaMode: RetinaMode.isHighDensity(context),
                      // ),
                      // TileLayer(
                      //   urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                      //   subdomains: const ['a', 'b', 'c'],
                      //   userAgentPackageName: 'com.najmshiel.map',
                      //   maxZoom: 17,
                      //   retinaMode: RetinaMode.isHighDensity(context),
                      //   additionalOptions: const {
                      //     // 'attribution': '© OpenTopoMap (CC-BY-SA)',
                      //     "attribution": "Map data: © <a href=\"https://openstreetmap.org/copyright\">OpenStreetMap</a> contributors, SRTM | Map display: © <a href=\"http://opentopomap.org\">OpenTopoMap</a> (<a href=\"https://creativecommons.org/licenses/by-sa/3.0/\">CC-BY-SA</a>)"
                      //   },
                      // ),
                      TileLayer(
                        urlTemplate: 'https://israelhiking.osm.org.il/English/Tiles/{z}/{x}/{y}.png',
                        // urlTemplate: 'https://israelhiking.osm.org.il/Tiles/{z}/{x}/{y}.png',
                        maxZoom: 20,
                        userAgentPackageName: 'com.najmshiel.map',
                        retinaMode: RetinaMode.isHighDensity(context),
                        additionalOptions: const {
                          'attribution': '© Israel Hiking Map contributors',
                        },
                      ),

                      // User location marker (if available)
                      if (_userLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: _getMarkerSize(_currentZoom) * 1.5, // Slightly larger than location markers
                              height: _getMarkerSize(_currentZoom) * 1.5,
                              point: _userLocation!,
                              child: Container(
                                // padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: _getMarkerSize(_currentZoom) * 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Location markers
                      MarkerLayer(
                        markers: locations
                          .map((location) {
                            final markerSize = _getMarkerSize(_currentZoom);
                            return Marker(
                              width: markerSize,
                              height: markerSize,
                              point: location.latLng,
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
                                            color: Colors.black.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Marker background
                                        Container(
                                          height: markerSize - 2,
                                          width: markerSize - 2,
                                          decoration: BoxDecoration(
                                            color: LocationTypeUtils.getColor(location.type),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap: () => _showLocationDetails(location.id),
                                            child: Icon(
                                              LocationTypeUtils.getIcon(location.type),
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
                            );
                          })
                          .toList(),
                      ),
                    ],
                  );
                } catch (e) {
                  logger.e('Error building map: $e');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text('خطأ في تحميل الخريطة: $e'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _retry,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),

            // Current zoom indicator (can be removed in production)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Zoom: ${_currentZoom.toStringAsFixed(1)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Loading indicator while waiting for location
            if (!_isLocationReady)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('جاري تحديد الموقع...'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
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
                    onChanged: (value) =>
                        locationProvider.toggleForests(),
                  ),

                  // Cities filter
                  FilterOptionWidget(
                    locationType: LocationType.city,
                    isSelected: locationProvider.showCities,
                    onChanged: (value) =>
                        locationProvider.toggleCities(),
                  ),
                  
                  FilterOptionWidget(
                    locationType: LocationType.barbecue,
                    isSelected: locationProvider.showBarbecue,
                    onChanged: (value) =>
                        locationProvider.toggleBarbecue(),
                  ),
                  
                  // Family filter
                  FilterOptionWidget(
                    locationType: LocationType.family,
                    isSelected: locationProvider.showFamily,
                    onChanged: (value) =>
                        locationProvider.toggleFamily(),
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
                    onChanged: (value) =>
                        locationProvider.toggleBeach(),
                  ),

                  // Hiking filter
                  FilterOptionWidget(
                    locationType: LocationType.hiking,
                    isSelected: locationProvider.showHiking,
                    onChanged: (value) =>
                        locationProvider.toggleHiking(),
                  ),

                  // Camping filter
                  FilterOptionWidget(
                    locationType: LocationType.camping,
                    isSelected: locationProvider.showCamping,
                    onChanged: (value) =>
                        locationProvider.toggleCamping(),
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
                    onChanged: (value) =>
                        locationProvider.toggleMosque(),
                  ),

                  // Church filter
                  FilterOptionWidget(
                    locationType: LocationType.church,
                    isSelected: locationProvider.showChurch,
                    onChanged: (value) =>
                        locationProvider.toggleChurch(),
                  ),

                  // Other filter
                  FilterOptionWidget(
                    locationType: LocationType.other,
                    isSelected: locationProvider.showOther,
                    onChanged: (value) =>
                        locationProvider.toggleOther(),
                  ),

                  // Actions
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  // IconData _getIconForType(LocationType type) {
  //   switch (type) {
  //     case LocationType.historical:
  //       return Icons.history;
  //     case LocationType.forest:
  //       return Icons.forest;
  //     case LocationType.city:
  //       return Icons.location_city;
  //     case LocationType.barbecue:
  //       return Icons.outdoor_grill;
  //     case LocationType.family:
  //       return Icons.family_restroom;
  //     case LocationType.viewpoint:
  //       return Icons.landscape;
  //     case LocationType.beach:
  //       return Icons.beach_access;
  //     case LocationType.hiking:
  //       return Icons.hiking;
  //     case LocationType.camping:
  //       return Icons.fireplace;
  //     case LocationType.other:
  //       return Icons.place;
  //   }
  // }

  // // Update the _getColorForType method
  // Color _getColorForType(LocationType type) {
  //   switch (type) {
  //     case LocationType.historical:
  //       return Colors.brown;
  //     case LocationType.forest:
  //       return Colors.green;
  //     case LocationType.city:
  //       return Colors.blue;
  //     case LocationType.barbecue:
  //       return Colors.deepOrange;
  //     case LocationType.family:
  //       return Colors.pink;
  //     case LocationType.viewpoint:
  //       return Colors.indigo;
  //     case LocationType.beach:
  //       return Colors.amber;
  //     case LocationType.hiking:
  //       return Colors.teal;
  //     case LocationType.camping:
  //       return Colors.lightGreen;
  //     case LocationType.other:
  //       return Colors.purple;
  //   }
  // }
}
