import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;    // Added name
  final String role;
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,  // Added name here
    required this.role,
    required this.fcmToken,
  });

  // Create UserModel from a Map (e.g. from Firestore)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',        // Added here
      role: map['role'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
    );
  }

  // Convert UserModel to a Map (for saving or Firestore)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,                  // Added here
      'role': role,
      'fcmToken': fcmToken,
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
}
