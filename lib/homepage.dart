import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:minute_meeting/config/notification.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // for flutterLocalNotificationsPlugin

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> menuItems = [
    {'title': 'Meetings', 'icon': Icons.book, 'route': '/meeting/list'},
    {'title': 'Minute Meeting', 'icon': Icons.note_alt, 'route': '/minute'},
    {'title': 'Calendar', 'icon': Icons.calendar_today, 'route': '/calendar'},
    {'title': 'Setting', 'icon': Icons.settings, 'route': '/settings'},
  ];

  List<Map<String, String>> userMeetings = [];
  late String uid;
  List<Meeting> _meetings = [];
  DateTime _selectedDay = DateTime.now();

  Future<void> _fetchMeetingsForDay(DateTime date) async {
    try {
      UserModel? currentUser = await UserModel.loadFromPrefs();
      if (currentUser == null) return;

      // Fetch the user's document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userSeeds = List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);

      // Get the seed IDs where the user is accepted
      final acceptedSeedIds = userSeeds.map((seed) => seed['seed']).toList();

      if (acceptedSeedIds.isEmpty) {
        setState(() {
          _meetings = [];
        });
        return;
      }

      // Define start and end of the selected day
      DateTime start = DateTime(date.year, date.month, date.day);
      DateTime end = start.add(Duration(days: 1));

      // Query all meetings for that date range
      final snapshot = await FirebaseFirestore.instance
          .collection('meetings')
          .where('startTime', isGreaterThanOrEqualTo: start)
          .where('startTime', isLessThan: end)
          .get();

      final meetings = snapshot.docs
          .map((doc) {
            final meeting = Meeting.fromMap(doc.data());

            // Find the current user's status in the meeting
            String userStatus = 'Not Invited'; // Default value
            for (var participant in meeting.participants) {
              if (participant.email == currentUser.email) {
                userStatus = participant.status ??
                    'Not Invited'; // 'pending', 'accepted', 'declined', etc.
                break;
              }
            }

            // Print debug information
            print('Meeting seed: ${meeting.seed}');
            print('Participants:');
            meeting.participants.forEach((p) {
              print(' - ${p.email} (status: ${p.status})');
            });

            // Add the user status to the meeting object
            meeting.userStatus = userStatus;

            return meeting;
          })
          .where((meeting) =>
              acceptedSeedIds.contains(meeting.seed) &&
              meeting.participants.any((p) => p.email == currentUser.email ))
          .toList();

      setState(() {
        _meetings = meetings;
      });
    } catch (e) {
      print('Error fetching meetings: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // _loadUserMeetings();

    _fetchMeetingsForDay(_selectedDay);
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
              // Sign out from Firebase
              await unsubscribeFromAllTopics();
              await FirebaseAuth.instance.signOut();

              // Clear SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // Navigate to login screen and replace current route
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
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

                ElevatedButton(
                  onPressed: () async {
                    try {
                      UserModel? currentUser = await UserModel.loadFromPrefs();
                      if (currentUser == null) return;
                      uid = currentUser.uid;
                    } catch (e) {
                      print('Failed to subscribe to topic: $e');
                    }

           await sendNotificationTopic(
                        'meeting-5acff35a-bbd4-472b-999e-2e8e538d7a2c', "kata-kata hari ini", "dsasd", "site11");

                  },
                  child: Text("asdas"),
                ),

          // SizedBox(
          //   height: 130,
          //   child: userMeetings.isEmpty
          //       ? const Center(child: Text("No accepted meetings found."))
          //       : ListView.builder(
          //           scrollDirection: Axis.horizontal,
          //           padding: const EdgeInsets.symmetric(horizontal: 16),
          //           itemCount: userMeetings.length,
          //           itemBuilder: (context, index) {
          //             final meeting = userMeetings[index];
          //             final rawDate = meeting['date'] ?? '';
          //             final duration = meeting['duration'] ?? '-';

          //             final dateTime = DateTime.tryParse(rawDate);
          //             final formattedDate = dateTime != null
          //                 ? DateFormat('dd MMM yyyy').format(dateTime)
          //                 : '-';
          //             final formattedTime = dateTime != null
          //                 ? DateFormat('hh:mm a').format(dateTime)
          //                 : '-';

          //             return GestureDetector(
          //               onTap: () {
          //                 // Navigate to detail view
          //               },
          //               child: AnimatedContainer(
          //                 duration: const Duration(milliseconds: 200),
          //                 width: 220,
          //                 margin: const EdgeInsets.only(right: 12),
          //                 padding: const EdgeInsets.all(14),
          //                 decoration: BoxDecoration(
          //                   color: Colors.red.shade50,
          //                   border: Border.all(color: Colors.red.shade200),
          //                   borderRadius: BorderRadius.circular(12),
          //                   boxShadow: [
          //                     BoxShadow(
          //                       color: Colors.red.withOpacity(0.15),
          //                       blurRadius: 6,
          //                       offset: const Offset(0, 3),
          //                     ),
          //                   ],
          //                 ),
          //                 child: Column(
          //                   crossAxisAlignment: CrossAxisAlignment.start,
          //                   children: [
          //                     Text(
          //                       meeting['title'] ?? '-',
          //                       style: const TextStyle(
          //                         fontWeight: FontWeight.bold,
          //                         fontSize: 14,
          //                       ),
          //                     ),
          //                     const SizedBox(height: 6),
          //                     Row(
          //                       children: [
          //                         const Icon(Icons.calendar_today,
          //                             size: 16, color: Colors.grey),
          //                         const SizedBox(width: 6),
          //                         Text(
          //                           formattedDate,
          //                           style: const TextStyle(
          //                             fontSize: 16,
          //                             fontWeight: FontWeight.w600,
          //                             color: Colors.black,
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                     const SizedBox(height: 6),
          //                     Row(
          //                       children: [
          //                         const Icon(Icons.access_time,
          //                             size: 16, color: Colors.grey),
          //                         const SizedBox(width: 6),
          //                         Text(
          //                           formattedTime,
          //                           style: const TextStyle(
          //                             fontSize: 16,
          //                             fontWeight: FontWeight.w600,
          //                             color: Colors.black,
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                     const SizedBox(height: 6),
          //                     Row(
          //                       children: [
          //                         const Icon(Icons.timelapse,
          //                             size: 16, color: Colors.grey),
          //                         const SizedBox(width: 6),
          //                         Text(
          //                           duration,
          //                           style: const TextStyle(
          //                             fontSize: 16,
          //                             fontWeight: FontWeight.w600,
          //                             color: Colors.black,
          //                           ),
          //                         ),
          //                       ],
          //                     ),
          //                   ],
          //                 ),
          //               ),
          //             );
          //           },
          //         ),
          // ),

          SizedBox(
            height: 150,
            child: _meetings.isEmpty
                ? const Center(child: Text('No meetings'))
                : ListView.builder(
                    itemCount: _meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = _meetings[index];
                      return Card(
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(meeting.title),
                              // Display the current user's status
                              if (meeting.userStatus == 'pending')
                                Text(
                                  meeting.userStatus ?? 'No Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors
                                        .orange, // Orange color for "pending" status
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${DateFormat.jm().format(meeting.startTime)} - ${DateFormat.jm().format(meeting.endTime)}\n'
                            'Location: ${meeting.location}',
                          ),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MeetingDetailsScreen(meeting: meeting),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
