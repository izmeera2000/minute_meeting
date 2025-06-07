import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String roomId; // Firestore doc ID
  final String name;
  final String seedId; // Just the seed ID (no need to store the whole Seed object initially)
  final DateTime? createdAt; // Created time

  Room({
    required this.roomId,
    required this.name,
    required this.seedId,
    this.createdAt,
  });

  // Factory method to create a Room object from Firestore document data
  factory Room.fromMap(String docId, Map<String, dynamic> map) {
    final createdAtTimestamp = map['created_at']; // Firestore Timestamp

    return Room(
      roomId: docId,
      name: map['name'] ?? '',
      seedId: map['seed'] ?? '',
      createdAt: createdAtTimestamp != null
          ? (createdAtTimestamp as Timestamp).toDate() // Convert Firestore Timestamp to DateTime
          : null,
    );
  }

  // Convert Room object back to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'seed': seedId, // Just store the seedId
      'created_at': createdAt ?? FieldValue.serverTimestamp(), // Firestore Timestamp
    };
  }
}
