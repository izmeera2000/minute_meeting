import 'dart:convert';
import 'package:minute_meeting/models/seed.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String fcmToken;
  List<Seed>? seeds; // seeds is now optional

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.fcmToken,
    this.seeds, // optional
  });

  // Create UserModel from a Map (e.g., from Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
      seeds: (map['seeds'] as List<dynamic>?)
          ?.map((seedMap) => Seed.fromMap(
                (seedMap as Map<String, dynamic>)['seedId'] ?? '',
                seedMap,
              ))
          .toList(),
    );
  }

  // Convert UserModel to a Map (for saving or Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'fcmToken': fcmToken,
      'seeds': seeds?.map((seed) => seed.toMap()).toList(), // handle null
    };
  }

  // Convert UserModel to JSON string
  String toJson() => json.encode(toMap());

  // Create UserModel from JSON string
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source));

  // Save UserModel to SharedPreferences
  static Future<void> saveToPrefs(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cachedUser', user.toJson());
  }

  // Load UserModel from SharedPreferences
  static Future<UserModel?> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('cachedUser');
    if (jsonString == null) return null;
    return UserModel.fromJson(jsonString);
  }

  // Remove cached user from SharedPreferences
  static Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cachedUser');
  }

  // Add a seed to the user's seeds list (if not already there)
  void addSeed(Seed seed) {
    seeds ??= [];
    if (!seeds!.any((existingSeed) => existingSeed.seedId == seed.seedId)) {
      seeds!.add(seed);
    }
  }
}
