import 'package:map_explorer/models/location.dart';
import 'package:map_explorer/models/comment.dart';
import 'package:map_explorer/models/vote.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String locationsCollection = 'locations';
  final String commentsCollection = 'comments';
  final String votesCollection = 'votes';
  
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
  
  // Add a new location with username
  Future<void> addLocation(Location location, String userId, String username) async {
    try {
      await _firestore.collection(locationsCollection).add({
        'name': location.name,
        'description': location.description,
        'type': location.type.toString(),
        'latitude': location.latitude,
        'longitude': location.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'creatorName': username,
        'images': location.images,
      });
      
      // Update user document to add this location
      await _firestore.collection('users').doc(userId).update({
        'locations': FieldValue.arrayUnion([location.id]),
        'lastActivity': FieldValue.serverTimestamp(),
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

  // COMMENT RELATED METHODS

  // Add a comment to a location
  Future<void> addComment(Comment comment) async {
    try {
      await _firestore.collection(commentsCollection).add(comment.toMap());
    } catch (e) {
      print('Error adding comment: $e');
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
      print('Error fetching comments: $e');
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
      print('Error adding/updating vote: $e');
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
      print('Error removing vote: $e');
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
      print('Error getting vote summary: $e');
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
      print('Error getting user vote: $e');
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
}
