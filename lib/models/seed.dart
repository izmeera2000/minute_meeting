import 'package:minute_meeting/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeedUser {
  final String uid;
  final String role;
  final String status;
  final String email;
  final DateTime? invitedAt;

  SeedUser({
    required this.uid,
    required this.role,
    required this.status,
    required this.email,
    this.invitedAt,
  });

  // Factory method to create a SeedUser from a map
  factory SeedUser.fromMap(Map<String, dynamic> map) {
    return SeedUser(
      uid: map['uid'],
      role: map['role'],
      status: map['status'],
      email: map['email'],
      invitedAt: map['invited_at'] != null
          ? (map['invited_at'] as Timestamp).toDate()
          : null,
    );
  }

  // Method to convert SeedUser to a map if needed for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'status': status,
      'email': email,
      'invited_at': invitedAt != null ? Timestamp.fromDate(invitedAt!) : null,
    };
  }
}




class Seed {
  final String seedId; // doc ID
  final String name;
  final List<SeedUser> users;
  final String? status; // Optional status
  final DateTime? createdAt; // ✅ NEW
  final String? role; // Add this field

  Seed({
    required this.seedId,
    required this.name,
    required this.users,
    this.status,
    this.createdAt, // ✅ NEW
         this.role, // Include role in constructor

  });

  factory Seed.fromMap(String docId, Map<String, dynamic> map, {String? status}) {
    return Seed(
      seedId: docId,
      name: map['name'] ?? '',
      users: (map['users'] as List<dynamic>? ?? [])
          .map((u) => SeedUser.fromMap(u as Map<String, dynamic>))
          .toList(),
      status: status,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(), // ✅ Convert from Firestore Timestamp
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'users': users.map((u) => u.toMap()).toList(),
    'status': status,
    'created_at': createdAt ?? FieldValue.serverTimestamp(), // ✅ Write Firestore Timestamp
  };

  Future<List<UserModel>> fetchUserModels() async {
    try {
      final uids = users.map((u) => u.uid).toList();
      if (uids.isEmpty) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', whereIn: uids)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print("Error fetching user models for seed: $e");
      return [];
    }
  }

  String? getRoleForUser(String uid) {
    return users.firstWhere(
      (u) => u.uid == uid,
      orElse: () => SeedUser(uid: '', role: '',email: '',status:'')
    ).role;
  }

  // Override the toString method to print all relevant data
  @override
  String toString() {
    return 'Seed(seedId: $seedId, name: $name, status: ${status ?? "No status"}, users: ${users.length})';
  }
}
