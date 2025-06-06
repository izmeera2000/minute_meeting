import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'main.dart'; // for flutterLocalNotificationsPlugin

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> menuItems = [
    {
      'title': 'Book Room Meeting',
      'icon': Icons.book,
      'route': '/meeting/list'
    },
    {'title': 'Minute Meeting', 'icon': Icons.note_alt, 'route': '/minute'},
    {'title': 'Calendar', 'icon': Icons.calendar_today, 'route': '/calendar'},
    {'title': 'Setting', 'icon': Icons.settings, 'route': '/settings'},
  ];

  List<Map<String, String>> userMeetings = [];

  @override
  void initState() {
    super.initState();
    _loadUserMeetings();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',
              'Default Channel',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📬 Notification opened');
    });
  }

  Future<void> _loadUserMeetings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;
    final ref = FirebaseDatabase.instance.ref().child('calendarEvents');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final List<Map<String, String>> loaded = [];

      data.forEach((eventKey, eventData) {
        if (eventData is Map && eventData.containsKey('hour_0')) {
          final subVal = eventData['hour_0'];

          if (subVal is Map) {
            final rawAttendees = subVal['attendees'];
            final attendees = rawAttendees is List
                ? List<String>.from(rawAttendees)
                : rawAttendees is Map
                    ? List<String>.from(rawAttendees.values)
                    : <String>[];

            if (attendees.contains(email) && subVal['status'] == 'Accepted') {
              loaded.add({
                'title': subVal['title'] ?? '-',
                'date': subVal['date'] ?? '-',
                'duration': subVal['duration']?.toString() ?? '-',
              });
            }
          }
        }
      });

      if (mounted) {
        setState(() {
          userMeetings = loaded;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text("Dashboard"),
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(
                  context, '/login'); // Replace with your login route
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Welcome Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade200, Colors.red],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome to the Meeting System",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Manage minutes, attendance, and calendar seamlessly.",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Grid Menu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
                children: menuItems.map((item) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    splashColor: Colors.red.withOpacity(0.2),
                    onTap: () {
                      Navigator.pushNamed(context, item['route']);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.red.shade100),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item['icon'], size: 40, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(
                            item['title'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Incoming Meetings
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Text(
              "Incoming Meetings",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          SizedBox(
            height: 130,
            child: userMeetings.isEmpty
                ? const Center(child: Text("No accepted meetings found."))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: userMeetings.length,
                    itemBuilder: (context, index) {
                      final meeting = userMeetings[index];
                      final rawDate = meeting['date'] ?? '';
                      final duration = meeting['duration'] ?? '-';

                      final dateTime = DateTime.tryParse(rawDate);
                      final formattedDate = dateTime != null
                          ? DateFormat('dd MMM yyyy').format(dateTime)
                          : '-';
                      final formattedTime = dateTime != null
                          ? DateFormat('hh:mm a').format(dateTime)
                          : '-';

                      return GestureDetector(
                        onTap: () {
                          // Navigate to detail view
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 220,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meeting['title'] ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.timelapse,
                                      size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    duration,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
