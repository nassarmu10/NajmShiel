import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_explorer/logger.dart';
import 'package:map_explorer/screens/profile_screen.dart';
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
  final double userLocationZoom =
      14.0; // Closer zoom when user location is available

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLocationReady = false;
  LatLng? _userLocation;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        title: const Text('نجم سهيل'),
        actions: [
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
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'ccom.najmshiel.map',
                        maxZoom: 18,
                        retinaMode: RetinaMode.isHighDensity(context),
                      ),

                      // User location marker (if available)
                      if (_userLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation!,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Location markers
                      MarkerLayer(
                        markers: locations
                            .map((location) => Marker(
                                  point: location.latLng,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showLocationDetails(location.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: BoxDecoration(
                                        color: _getColorForType(location.type),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
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
                                ))
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
                      const Text(
                        'تصفية المواقع',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 16),

                      // Historical filter
                      CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(Icons.history,
                                color:
                                    _getColorForType(LocationType.historical)),
                            const SizedBox(width: 8),
                            const Text(
                              'المواقع التاريخية',
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                        value: locationProvider.showHistorical,
                        onChanged: (value) =>
                            locationProvider.toggleHistorical(),
                        dense: true,
                      ),

                      // Forests filter
                      CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(Icons.forest,
                                color: _getColorForType(LocationType.forest)),
                            const SizedBox(width: 8),
                            const Text(
                              'المناطق الطبيعية',
                              textAlign: TextAlign.right,
                            ),
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
                            Icon(Icons.location_city,
                                color: _getColorForType(LocationType.city)),
                            const SizedBox(width: 8),
                            const Text(
                              'المدن والبلدات',
                              textAlign: TextAlign.right,
                            ),
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
                            Icon(Icons.place,
                                color: _getColorForType(LocationType.other)),
                            const SizedBox(width: 8),
                            const Text(
                              'أماكن أخرى',
                              textAlign: TextAlign.right,
                            ),
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
                            onPressed: () =>
                                locationProvider.setAllFilters(true),
                            child: const Text('عرض الكل'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إغلاق'),
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
