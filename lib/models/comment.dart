import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String locationId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;
  final String? imageUrl; // Optional image for the comment

  Comment({
    required this.id,
    required this.locationId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
    this.imageUrl,
  });

  // Create from Firestore document
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    DateTime createdAtDate;
    if (data['createdAt'] is Timestamp) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }

    return Comment(
      id: doc.id,
      locationId: data['locationId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      content: data['content'] ?? '',
      createdAt: createdAtDate,
      imageUrl: data['imageUrl'],
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'userId': userId,
      'username': username,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    };
  }
}
