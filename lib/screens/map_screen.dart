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

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final MapController mapController = MapController();
  
  // Israel and Palestine region center and zoom
  final LatLng countryCenter = const LatLng(31.5, 35.0); 
  final double initialZoom = 8.0; 
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeDataSafely();
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
      final provider = Provider.of<LocationDataProvider>(context, listen: false);
      provider.refreshLocations();
    }
  }
  
  // Initialize data safely without triggering rebuild during build
  Future<void> _initializeDataSafely() async {
    try {
      // Set a temporary user ID without triggering notifications
      final provider = Provider.of<LocationDataProvider>(context, listen: false);
      
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
      print('Error initializing data: $e');
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
    });
    _initializeDataSafely();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نجم سهيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = Provider.of<LocationDataProvider>(context, listen: false);
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
        
        return FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: countryCenter,
            initialZoom: initialZoom,
            // Keep these minimal to avoid performance issues
          ),
          children: [
            // Base map tiles layer
            TileLayer(
              // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_labels_under/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c'],
              // Using a simpler tile source can improve performance
              userAgentPackageName: 'com.example.najmshiel',
              maxZoom: 18,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 16),
                  
                  // Historical filter
                  CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(Icons.history, color: _getColorForType(LocationType.historical)),
                        const SizedBox(width: 8),
                        const Text(
                          'المواقع التاريخية',
                          textAlign: TextAlign.right,
                        ),
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
                        Icon(Icons.location_city, color: _getColorForType(LocationType.city)),
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
                        Icon(Icons.place, color: _getColorForType(LocationType.other)),
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
                        onPressed: () => locationProvider.setAllFilters(true),
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
