import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minute_meeting/models/seed.dart';

class Room {
  final String roomId; // Firestore doc ID
  final String name;
  final Seed seed;
  final DateTime? createdAt; // ✅ NEW

  Room({
    required this.roomId,
    required this.name,
    required this.seed,
    this.createdAt, // ✅ NEW
  });

  // Factory method to create Room from Firestore document data
  factory Room.fromMap(String docId, Map<String, dynamic> map) {
    final seedId = map['seed'] as String? ?? '';
    final createdAtTimestamp = map['created_at']; // Firestore Timestamp

    return Room(
      roomId: docId,
      name: map['name'] ?? '',
      createdAt: createdAtTimestamp != null
          ? (createdAtTimestamp as Timestamp).toDate() // Convert Firestore Timestamp to DateTime
          : null,
      seed: Seed(
        seedId: seedId,
        name: '', // You can fetch the seed name later if needed
        users: [], // Empty list of users initially
      ),
    );
  }

  // Convert Room object back to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'seed': seed.toMap(), // Assuming seed has a toMap method for Firestore
      'created_at': createdAt ?? FieldValue.serverTimestamp(), // Firestore Timestamp
    };
  }
}

