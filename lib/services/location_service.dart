import 'package:map_explorer/models/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class FirebaseLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String locationsCollection = 'locations';
  
  // Fetch all locations with filtering
  Future<List<Location>> getLocations({
    bool includeHistorical = true,
    bool includeForests = true,
    bool includeCities = true,
    bool includeOther = true,
  }) async {
    try {
      // Start building the query
      Query query = _firestore.collection(locationsCollection);
      
      // Apply type filters if needed
      if (!(includeHistorical && includeForests && includeCities && includeOther)) {
        List<String> typesToInclude = [];
        
        if (includeHistorical) typesToInclude.add(LocationType.historical.toString());
        if (includeForests) typesToInclude.add(LocationType.forest.toString());
        if (includeCities) typesToInclude.add(LocationType.city.toString());
        if (includeOther) typesToInclude.add(LocationType.other.toString());
        
        if (typesToInclude.isNotEmpty) {
          query = query.where('type', whereIn: typesToInclude);
        }
      }
      
      // Get the documents
      final snapshot = await query.get();
      
      // Convert to Location objects
      return snapshot.docs.map((doc) {
        return Location.fromFirestore(doc);
      }).toList();
    } catch (e) {
      print('Error fetching locations: $e');
      return [];
    }
  }
  
  // Add a new location
  Future<void> addLocation(Location location) async {
    try {
      await _firestore.collection(locationsCollection).add({
        'name': location.name,
        'description': location.description,
        'type': location.type.toString(),
        'latitude': location.latitude,
        'longitude': location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'anonymous',
        'images': location.images,
      });
    } catch (e) {
      print('Error adding location: $e');
      throw e;
    }
  }
  
  // Get a single location by ID
  Future<Location?> getLocation(String id) async {
    try {
      final doc = await _firestore.collection(locationsCollection).doc(id).get();
      if (doc.exists) {
        return Location.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }
}
