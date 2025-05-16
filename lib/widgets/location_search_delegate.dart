import 'package:flutter/material.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/utils/location_type_utils.dart';

class LocationSearchDelegate extends SearchDelegate<Location?> {
  final List<Location> locations;
  final Function(Location) onLocationSelected;

  LocationSearchDelegate({
    required this.locations,
    required this.onLocationSelected,
  });

  @override
  String get searchFieldLabel => 'ابحث عن موقع...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(
    fontSize: 16,
  );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    // If query is empty, show a message instead of results
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'ابدأ بالكتابة للبحث عن المواقع',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    final filteredLocations = locations.where((location) {
      final lowercaseQuery = query.toLowerCase();
      final lowercaseName = location.name.toLowerCase();
      final lowercaseDescription = location.description.toLowerCase();
      
      return lowercaseName.contains(lowercaseQuery) || 
             lowercaseDescription.contains(lowercaseQuery);
    }).toList();

    // If no results found, show a message
    if (filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredLocations.length,
      itemBuilder: (context, index) {
        final location = filteredLocations[index];
        return ListTile(
          title: Text(
            location.name,
            textDirection: TextDirection.rtl,
          ),
          subtitle: Text(
            location.description,
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: Icon(
            LocationTypeUtils.getIcon(location.type),
            color: Theme.of(context).primaryColor,
          ),
          onTap: () {
            onLocationSelected(location);
            close(context, location);
          },
        );
      },
    );
  }
} 