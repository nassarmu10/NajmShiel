import 'package:map_explorer/logger.dart';
import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/models/vote.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String locationsCollection = 'locations';
  final String commentsCollection = 'comments';
  final String votesCollection = 'votes';
  
  // Optimized location fetching with Firebase compound queries
  Future<List<Location>> getLocations({
    bool includeHistorical = true,
    bool includeForests = true,
    bool includeCities = true,
    bool includeOther = true,
  }) async {
    try {
      // Check if we need to filter at all
      if (includeHistorical && includeForests && includeCities && includeOther) {
        // No filtering needed, get all locations
        final snapshot = await _firestore.collection(locationsCollection).get();
        return snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList();
      }
      
      // Create a list of queries for each type that should be included
      List<Query> queries = [];
      
      if (includeHistorical) {
        queries.add(_firestore.collection(locationsCollection)
            .where('type', isEqualTo: LocationType.historical.toString()));
      }
      
      if (includeForests) {
        queries.add(_firestore.collection(locationsCollection)
            .where('type', isEqualTo: LocationType.forest.toString()));
      }
      
      if (includeCities) {
        queries.add(_firestore.collection(locationsCollection)
            .where('type', isEqualTo: LocationType.city.toString()));
      }
      
      if (includeOther) {
        queries.add(_firestore.collection(locationsCollection)
            .where('type', isEqualTo: LocationType.other.toString()));
      }
      
      // If no types are selected, return empty list
      if (queries.isEmpty) {
        logger.w('No location types selected for filtering');
        return [];
      }
      
      // Execute all queries in parallel
      final snapshots = await Future.wait(queries.map((query) => query.get()));
      
      // Combine results
      List<Location> locations = [];
      for (final snapshot in snapshots) {
        locations.addAll(
          snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList()
        );
      }
      
      return locations;
    } catch (e) {
      logger.e('Error fetching locations: $e');
      return [];
    }
  }
  
  // Add a new location with username
  Future<void> addLocation(Location location, String userId, String username) async {
    try {
      final locationData = {
        'name': location.name,
        'description': location.description,
        'type': location.type.toString(),
        'location': GeoPoint(location.latitude, location.longitude), // Store as GeoPoint
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'creatorName': username,
        'images': location.images,
      };
      
      // Add legacy fields for backward compatibility if needed
      // Comment these out if you're sure all code uses the GeoPoint field
      locationData['latitude'] = location.latitude;
      locationData['longitude'] = location.longitude;
      
      final docRef = await _firestore.collection(locationsCollection).add(locationData);
      
      // Update user document to add this location
      await _firestore.collection('users').doc(userId).update({
        'locations': FieldValue.arrayUnion([docRef.id]),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.e('Error adding location: $e');
      rethrow;
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
      logger.e('Error getting location: $e');
      return null;
    }
  }

  // COMMENT RELATED METHODS

  // Add a comment to a location
  Future<void> addComment(Comment comment) async {
    try {
      await _firestore.collection(commentsCollection).add(comment.toMap());
    } catch (e) {
      logger.e('Error adding comment: $e');
      throw e;
    }
  }

  // Get all comments for a location
  Future<List<Comment>> getCommentsForLocation(String locationId) async {
    try {
      final snapshot = await _firestore
          .collection(commentsCollection)
          .where('locationId', isEqualTo: locationId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
    } catch (e) {
      logger.e('Error fetching comments: $e');
      return [];
    }
  }

  // Stream comments for a location (for real-time updates)
  Stream<List<Comment>> streamCommentsForLocation(String locationId) {
    return _firestore
        .collection(commentsCollection)
        .where('locationId', isEqualTo: locationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList();
    });
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      await _firestore.collection(commentsCollection).doc(commentId).delete();
    } catch (e) {
      logger.e('Error deleting comment: $e');
      throw e;
    }
  }

  // VOTE RELATED METHODS

  // Add or update a vote
  Future<void> addOrUpdateVote(Vote vote) async {
    try {
      // Check if user already voted for this location
      final existingVote = await _firestore
          .collection(votesCollection)
          .where('locationId', isEqualTo: vote.locationId)
          .where('userId', isEqualTo: vote.userId)
          .get();

      if (existingVote.docs.isNotEmpty) {
        // Update existing vote
        final docId = existingVote.docs.first.id;
        await _firestore.collection(votesCollection).doc(docId).update({
          'voteType': vote.voteType.toString(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Add new vote
        await _firestore.collection(votesCollection).add(vote.toMap());
      }
    } catch (e) {
      logger.e('Error adding/updating vote: $e');
      throw e;
    }
  }

  // Remove a vote
  Future<void> removeVote(String locationId, String userId) async {
    try {
      final existingVote = await _firestore
          .collection(votesCollection)
          .where('locationId', isEqualTo: locationId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingVote.docs.isNotEmpty) {
        final docId = existingVote.docs.first.id;
        await _firestore.collection(votesCollection).doc(docId).delete();
      }
    } catch (e) {
      logger.e('Error removing vote: $e');
      throw e;
    }
  }

  // Get vote summary for a location
  Future<VoteSummary> getVoteSummary(String locationId) async {
    try {
      final snapshot = await _firestore
          .collection(votesCollection)
          .where('locationId', isEqualTo: locationId)
          .get();

      int likes = 0;
      int dislikes = 0;
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String voteTypeStr = data['voteType'] ?? '';
        
        if (voteTypeStr == VoteType.like.toString()) {
          likes++;
        } else if (voteTypeStr == VoteType.dislike.toString()) {
          dislikes++;
        }
      }
      return VoteSummary(likes: likes, dislikes: dislikes);
    } catch (e) {
      logger.e('Error getting vote summary: $e');
      return VoteSummary(likes: 0, dislikes: 0);
    }
  }

  // Get user's vote for a location
  Future<VoteType?> getUserVote(String locationId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(votesCollection)
          .where('locationId', isEqualTo: locationId)
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        Map<String, dynamic> data = snapshot.docs.first.data();
        String voteTypeStr = data['voteType'] ?? '';
        
        try {
          return VoteType.values.firstWhere(
            (e) => e.toString() == voteTypeStr,
          );
        } catch (_) {
          return null;
        }
      }
      
      return null; // User hasn't voted
    } catch (e) {
      logger.e('Error getting user vote: $e');
      return null;
    }
  }

  // Stream vote summary for a location (for real-time updates)
  Stream<VoteSummary> streamVoteSummary(String locationId) {
    return _firestore
        .collection(votesCollection)
        .where('locationId', isEqualTo: locationId)
        .snapshots()
        .map((snapshot) {
      int likes = 0;
      int dislikes = 0;

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String voteTypeStr = data['voteType'] ?? '';
        
        if (voteTypeStr == VoteType.like.toString()) {
          likes++;
        } else if (voteTypeStr == VoteType.dislike.toString()) {
          dislikes++;
        }
      }
      return VoteSummary(likes: likes, dislikes: dislikes);
    });
  }

  // Update a comment
  Future<void> updateComment(Comment comment) async {
    try {
      // Find the comment document by its ID
      await _firestore
          .collection(commentsCollection)
          .doc(comment.id)
          .update({
        'content': comment.content,
        'imageUrl': comment.imageUrl,
        // We don't update other fields like userId, username, locationId, createdAt
      });
    } catch (e) {
      logger.e('Error updating comment: $e');
      throw e;
    }
  }
  
  // Update a location
  Future<void> updateLocation(Location location) async {
    try {
      final locationData = {
        'name': location.name,
        'description': location.description,
        'type': location.type.toString(),
        'location': GeoPoint(location.latitude, location.longitude),
        'images': location.images,
        // Don't update createdBy, createdAt, etc.
      };
      
      // For backwards compatibility
      locationData['latitude'] = location.latitude;
      locationData['longitude'] = location.longitude;
      
      await _firestore
          .collection(locationsCollection)
          .doc(location.id)
          .update(locationData);
          
    } catch (e) {
      logger.e('Error updating location: $e');
      throw e;
    }
  }
}
