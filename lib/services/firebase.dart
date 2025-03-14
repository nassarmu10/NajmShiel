// import 'dart:io';
// import 'dart:ui';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:map_explorer/models/location.dart';

// class LocationService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseStorage _storage = FirebaseStorage.instance;
  
//   // Get all locations
//   Stream<List<Location>> getLocations({
//     bool includeHistorical = true,
//     bool includeForests = true,
//     bool includeCities = true,
//   }) {
//     return _firestore.collection('locations').snapshots().map((snapshot) {
//       return snapshot.docs
//           .map((doc) => Location.fromMap(doc.id, doc.data()))
//           .where((location) {
//             if (location.type == LocationType.historical && !includeHistorical) {
//               return false;
//             }
//             if (location.type == LocationType.forest && !includeForests) {
//               return false;
//             }
//             if (location.type == LocationType.city && !includeCities) {
//               return false;
//             }
//             return true;
//           })
//           .toList();
//     });
//   }
  
//   // Add a new location
//   Future<void> addLocation(Location location, List<XFile> images) async {
//     // First upload images if any
//     List<String> imageUrls = [];
    
//     if (images.isNotEmpty) {
//       for (var image in images) {
//         String fileName = '${DateTime.now().millisecondsSinceEpoch}_${Path.basename(image.path)}';
//         Reference ref = _storage.ref().child('location_images').child(fileName);
        
//         await ref.putFile(File(image.path));
//         String downloadUrl = await ref.getDownloadURL();
//         imageUrls.add(downloadUrl);
//       }
//     }
    
//     // Create location with image URLs
//     final locationWithImages = Location(
//       id: location.id,
//       name: location.name,
//       description: location.description,
//       type: location.type,
//       latitude: location.latitude,
//       longitude: location.longitude,
//       addedBy: location.addedBy,
//       createdAt: location.createdAt,
//       images: imageUrls,
//     );
    
//     // Save to Firestore
//     await _firestore.collection('locations').add(locationWithImages.toMap());
//   }
  
//   // Get a single location
//   Future<Location?> getLocation(String id) async {
//     final doc = await _firestore.collection('locations').doc(id).get();
    
//     if (doc.exists) {
//       return Location.fromMap(doc.id, doc.data()!);
//     }
    
//     return null;
//   }
// }
