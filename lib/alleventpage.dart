import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class EventManagementPage extends StatefulWidget {
  @override
  _EventManagementPageState createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('calendarEvents');
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _fetchEvents() async {
    final snapshot = await _dbRef.get();
    if (!mounted) return; // Prevent setState after dispose

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, dynamic>> loaded = [];

      data.forEach((eventKey, value) {
        if (value is Map && value.containsKey('hour_0')) {
          final hour0 = Map<String, dynamic>.from(value['hour_0']);
          hour0['eventKey'] = eventKey;
          loaded.add(hour0);
        }
      });

      if (!mounted) return; // Prevent setState after dispose
      setState(() {
        _events = loaded;
        _isLoading = false;
      });
    } else {
      if (!mounted) return; // Prevent setState after dispose
      setState(() => _isLoading = false);
    }
  }


  Future<void> _updateStatus(String eventKey, String status) async {
    print("🔄 Updating status for eventKey: $eventKey to $status");

    final eventSnapshot = await _dbRef.child(eventKey).get();

    if (!eventSnapshot.exists) {
      print("⚠️ Event with key $eventKey does not exist.");
      return;
    }

    final Map<String, dynamic> eventData =
    Map<String, dynamic>.from(eventSnapshot.value as Map);

    final Map<String, dynamic> updates = {};

    eventData.forEach((key, value) {
      if (key.startsWith('hour_')) {
        updates['$key/status'] = status;
      }
    });

    await _dbRef.child(eventKey).update(updates);
    print("✅ Status updated in database.");
    _fetchEvents();

    if (status == "Accepted") {
      final hour0 = Map<String, dynamic>.from(eventData['hour_0'] ?? {});
      final List attendees = hour0['attendees'] ?? [];

      print("📨 Sending notifications to attendees: $attendees");

      for (String email in attendees) {
        print("🔍 Looking up user with email: $email");

        final usersSnapshot = await FirebaseDatabase.instance
            .ref('users')
            .orderByChild('email')
            .equalTo(email)
            .get();

        if (usersSnapshot.exists) {
          final userMap = Map<String, dynamic>.from(usersSnapshot.value as Map);
          for (final entry in userMap.entries) {
            final user = entry.value;
            final fcmToken = user['fcmToken'];
            print("📦 FCM token for $email: $fcmToken");

            if (fcmToken != null) {
              final rawDate = hour0['date'];
              String formattedDateTime = rawDate;

              try {
                final parsedDate = DateTime.parse(rawDate);
                formattedDateTime =
                "${DateFormat('d MMM y').format(parsedDate)} at ${DateFormat('h:mm a').format(parsedDate)}";
              } catch (e) {
                print("❌ Failed to parse date: $rawDate");
              }

              await _sendFCMNotification(
                token: fcmToken,
                title: hour0['title'] ?? 'Meeting Accepted',
                body:
                "Invited meeting on $formattedDateTime for ${hour0['duration']}.",
              );
            } else {
              print("⚠️ No FCM token found for $email");
            }
          }
        } else {
          print("❌ No user found with email: $email");
        }
      }
    }
  }


  Future<void> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
  }) async {
    try {
      // Load service account credentials
      final jsonString = await rootBundle.loadString('assets/service-accountss.json');
      final credentials = ServiceAccountCredentials.fromJson(jsonString);

      // Define the required scopes for FCM
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

      // Authenticate and obtain an HTTP client
      final client = await clientViaServiceAccount(credentials, scopes);

      final accessToken = client.credentials.accessToken.data;

      // Your Firebase project ID
      final projectId = ' ';

      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      final message = {
        "message": {
          "token": token,
          "notification": {
            "title": title,
            "body": body,
          },
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('✅ Notification sent: ${response.body}');
      } else {
        print('❌ Failed to send notification: ${response.statusCode} ${response.body}');
      }

      client.close();
    } catch (e) {
      print('❌ Notification failed: $e');
    }
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Event Management"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(child: Text("No events found."))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: _events.map((event) {
            final title = event['title'] ?? '-';
            final date = event['date'] ?? '';
            final duration = event['duration'] ?? '-';
            final attendees = List<String>.from(event['attendees'] ?? []);
            final status = event['status'] ?? 'Pending';
            final formattedDate = date.isNotEmpty
                ? DateFormat.yMMMMd().add_jm().format(DateTime.parse(date))
                : '-';

            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Title: $title",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text("Date: $formattedDate"),
                      Text("Duration: $duration"),
                      SizedBox(height: 8),
                      Text("Attendees:",
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      ...attendees.map((email) => Text("- $email")),
                      SizedBox(height: 16),
                      if (status == 'Pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(event['eventKey'], 'Accepted'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text("Accept"),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateStatus(event['eventKey'], 'Rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text("Reject"),
                              ),
                            ),
                          ],
                        )
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            "Status: $status",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: status == 'Accepted' ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
