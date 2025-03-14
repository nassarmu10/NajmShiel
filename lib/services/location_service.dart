// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:path/path.dart' as path;

// import '../models/location.dart';

// class LocationService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseStorage _storage = FirebaseStorage.instance;
//   final String locationsCollection = 'locations';
  
//   // Get all locations with filtering
//   Future<List<Location>> getLocations({
//     bool includeHistorical = true,
//     bool includeForests = true,
//     bool includeCities = true,
//     bool includeOther = true,
//   }) async {
//     try {
//       // Start with base query
//       Query query = _firestore.collection(locationsCollection);
      
//       // Apply type filters if not all are selected
//       if (!(includeHistorical && includeForests && includeCities && includeOther)) {
//         List<String> typesToInclude = [];
        
//         if (includeHistorical) typesToInclude.add(LocationType.historical.toString());
//         if (includeForests) typesToInclude.add(LocationType.forest.toString());
//         if (includeCities) typesToInclude.add(LocationType.city.toString());
//         if (includeOther) typesToInclude.add(LocationType.other.toString());
        
//         if (typesToInclude.isNotEmpty) {
//           query = query.where('type', whereIn: typesToInclude);
//         } else {
//           // If no types selected, return empty list
//           return [];
//         }
//       }
      
//       // Get the documents
//       final snapshot = await query.get();
      
//       // Convert to Location objects
//       final locations = snapshot.docs.map((doc) {
//         return Location.fromMap(doc.id, doc.data() as Map<String, dynamic>);
//       }).toList();
      
//       return locations;
//     } catch (e) {
//       // In a real app, you might want to log errors properly
//       print('Error fetching locations: $e');
//       rethrow; // Rethrow to allow handling in UI
//     }
//   }
  
//   // Add a new location
//   Future<void> addLocation(Location location, List<XFile> images) async {
//     try {
//       // First upload images if any
//       List<String> imageUrls = [];
      
//       if (images.isNotEmpty) {
//         for (var image in images) {
//           String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
//           Reference ref = _storage.ref().child('location_images').child(fileName);
          
//           await ref.putFile(File(image.path));
//           String downloadUrl = await ref.getDownloadURL();
//           imageUrls.add(downloadUrl);
//         }
//       }
      
//       // Create location with image URLs
//       final locationWithImages = Location(
//         id: location.id,
//         name: location.name,
//         description: location.description,
//         type: location.type,
//         latitude: location.latitude,
//         longitude: location.longitude,
//         addedBy: location.addedBy,
//         createdAt: location.createdAt,
//         images: imageUrls,
//       );
      
//       // Save to Firestore
//       await _firestore.collection(locationsCollection).add(locationWithImages.toMap());
//     } catch (e) {
//       print('Error adding location: $e');
//       rethrow;
//     }
//   }
  
//   // Get a single location
//   Future<Location?> getLocation(String id) async {
//     try {
//       final doc = await _firestore.collection(locationsCollection).doc(id).get();
      
//       if (doc.exists) {
//         return Location.fromMap(doc.id, doc.data()!);
//       }
      
//       return null;
//     } catch (e) {
//       print('Error getting location: $e');
//       rethrow;
//     }
//   }
  
//   // Update an existing location
//   Future<void> updateLocation(Location location) async {
//     try {
//       await _firestore
//           .collection(locationsCollection)
//           .doc(location.id)
//           .update(location.toMap());
//     } catch (e) {
//       print('Error updating location: $e');
//       rethrow;
//     }
//   }
  
//   // Delete a location
//   Future<void> deleteLocation(String locationId) async {
//     try {
//       // Get the location to find associated images
//       final location = await getLocation(locationId);
      
//       if (location != null && location.images.isNotEmpty) {
//         // Delete images from storage
//         for (var imageUrl in location.images) {
//           // Extract the path from the URL
//           final ref = _storage.refFromURL(imageUrl);
//           await ref.delete();
//         }
//       }
      
//       // Delete the document
//       await _firestore.collection(locationsCollection).doc(locationId).delete();
//     } catch (e) {
//       print('Error deleting location: $e');
//       rethrow;
//     }
//   }
  
//   // Get locations added by a specific user
//   Future<List<Location>> getUserLocations(String userId) async {
//     try {
//       final snapshot = await _firestore
//           .collection(locationsCollection)
//           .where('addedBy', isEqualTo: userId)
//           .get();
      
//       return snapshot.docs
//           .map((doc) => Location.fromMap(doc.id, doc.data()))
//           .toList();
//     } catch (e) {
//       print('Error getting user locations: $e');
//       rethrow;
//     }
//   }
  
//   // For demo/testing: Add sample locations
//   Future<void> addSampleLocations() async {
//     // A few sample locations for testing
//     final samples = [
//       Location(
//         id: 'sample1',
//         name: 'Historic Downtown',
//         description: 'A beautiful historic area with buildings from the 1800s.',
//         type: LocationType.historical,
//         latitude: 37.7749,
//         longitude: -122.4194,
//         addedBy: 'system',
//         createdAt: DateTime.now(),
//         images: [],
//       ),
//       Location(
//         id: 'sample2',
//         name: 'National Forest',
//         description: 'Protected forest with diverse wildlife and hiking trails.',
//         type: LocationType.forest,
//         latitude: 37.8651,
//         longitude: -122.2295,
//         addedBy: 'system',
//         createdAt: DateTime.now(),
//         images: [],
//       ),
//       Location(
//         id: 'sample3',
//         name: 'Capital City',
//         description: 'The bustling capital with modern architecture.',
//         type: LocationType.city,
//         latitude: 37.9577,
//         longitude: -121.2908,
//         addedBy: 'system',
//         createdAt: DateTime.now(),
//         images: [],
//       ),
//     ];
    
//     for (var location in samples) {
//       await _firestore.collection(locationsCollection).add(location.toMap());
//     }
//   }
// }
