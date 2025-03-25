import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteType {
  like,
  dislike
}

class Vote {
  final String id;
  final String locationId;
  final String userId;
  final VoteType voteType;
  final DateTime createdAt;

  Vote({
    required this.id,
    required this.locationId,
    required this.userId,
    required this.voteType,
    required this.createdAt,
  });

  // Create from Firestore document
  factory Vote.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse vote type
    VoteType type;
    try {
      type = VoteType.values.firstWhere(
        (e) => e.toString() == data['voteType'],
        orElse: () => VoteType.like,
      );
    } catch (_) {
      type = VoteType.like;
    }
    
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }

    return Vote(
      id: doc.id,
      locationId: data['locationId'] ?? '',
      userId: data['userId'] ?? '',
      voteType: type,
      createdAt: createdAtDate,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'userId': userId,
      'voteType': voteType.toString(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

// Vote Summary holds aggregated vote data for a location
class VoteSummary {
  final int likes;
  final int dislikes;
  
  VoteSummary({
    required this.likes,
    required this.dislikes,
  });
  
  int get total => likes + dislikes;
  
  // Calculate percentage for display
  double get likePercentage => total > 0 ? (likes / total * 100) : 0;
}
