import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/details.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'package:minute_meeting/models/meetings.dart'; // Adjust path if needed

class MeetingListPage extends StatefulWidget {
  @override
  _MeetingListPageState createState() => _MeetingListPageState();
}

class _MeetingListPageState extends State<MeetingListPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Meeting> _meetings = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMeetingsForDay(_selectedDay!);
   _selectedDate = DateTime.now();

  }

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
              meeting.participants.any((p) => p.email == currentUser.email))
          .toList();

      setState(() {
        _meetings = meetings;
      });
    } catch (e) {
      print('Error fetching meetings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meetings'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add',
            onPressed: () {
              // Pass _selectedDate to the new screen using Navigator.pushNamed
              Navigator.pushNamed(
                context,
                '/meeting/create',
                arguments: _selectedDate, // Pass the selected date as argument
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            headerStyle: HeaderStyle(
              formatButtonVisible:
                  false, // <-- This hides the "2 weeks" format button
            ),
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedDate = selectedDay;
              });
              _fetchMeetingsForDay(selectedDay);
            },
            calendarStyle: CalendarStyle(
              selectedDecoration:
                  BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              todayDecoration:
                  BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Meetings on ${DateFormat.yMMMMd().format(_selectedDay!)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
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
