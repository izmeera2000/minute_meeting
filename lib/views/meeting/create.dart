import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For file picker (e.g., images)
import 'dart:io';

import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/details.dart'; // For the File type and Meeting model

class CreateMeetingPage extends StatefulWidget {
  @override
  _CreateMeetingPageState createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _titleController = TextEditingController();
  final _participantsController = TextEditingController();
  final _locationController = TextEditingController(); // For location input
  final _attachmentUrls = <Attachment>[]; // List of attachments
  List<String> _selectedParticipants = [];
  List<String> _allUsers = [];
  User? _currentUser;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0); // Default start time
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0); // Default end time
  TimeOfDay _startTime2 = TimeOfDay(hour: 14, minute: 0); // Default start time2
  TimeOfDay _endTime2 = TimeOfDay(hour: 15, minute: 0); // Default end time2

  String _role = 'attendee'; // Default role for participants

  // Convert TimeOfDay to DateTime
  DateTime _timeToDateTime(TimeOfDay time) {
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
        time.hour, time.minute);
  }

  Future<void> _fetchUsers() async {
    try {
      // Get the current logged-in user
      print("fetch");
      UserModel? currentUser = await UserModel.loadFromPrefs();

      if (currentUser != null) {
        // Fetch all users from Firestore, excluding the current user
        final usersQuery =
            await FirebaseFirestore.instance.collection('users').get();
        setState(() {
          _allUsers = usersQuery.docs
              .map((doc) => doc['email'] as String)
              .where((email) => email != currentUser.email)
              .toSet() // remove duplicates
              .toList();
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  // Create a meeting and store it in Firestore
  void _createMeeting() async {
    if (_titleController.text.isEmpty ||
        _selectedParticipants.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    // Convert times to DateTime objects
    DateTime startDateTime = _timeToDateTime(_startTime);
    DateTime endDateTime = _timeToDateTime(_endTime);

    UserModel? currentUser = await UserModel.loadFromPrefs();

    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    List<Participant> participants = [];

    // Add participants from selected emails
// Fetch all users once
    var allUsersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

// Map email to user data for quick lookup
    final Map<String, QueryDocumentSnapshot> emailToUserDoc = {
      for (var doc in allUsersSnapshot.docs) (doc.data()['email'] ?? ''): doc
    };

    for (String email in _selectedParticipants) {
      if (emailToUserDoc.containsKey(email)) {
        var userDoc = emailToUserDoc[email]!;
        var data = userDoc.data() as Map<String, dynamic>; // cast here

        participants.add(
          Participant(
            uid: userDoc.id,
            email: email,
            name: data['name'] ?? '', // now safe
            role: 'participant',
            status: 'pending',
          ),
        );
      }
    }

    // Add current user as 'host' if not already included
    if (!_selectedParticipants.contains(currentUser.email)) {
      participants.add(
        Participant(
          uid: currentUser.uid,
          email: currentUser.email,
          name: currentUser.name,
          role: 'host',
          status: 'accepted', // Host is accepted by default
        ),
      );
    }

    // Create the meeting object WITHOUT id yet
    final meeting = Meeting(
      title: _titleController.text,
      startTime: startDateTime,
      endTime: endDateTime,
      date: _selectedDate,
      createdBy: [
        Creator(
          uid: currentUser.uid,
          name: currentUser.name,
          email: currentUser.email,
        ),
      ],
      participants: participants,
      attachments: _attachmentUrls, // Assuming this is List<Attachment>
      location: _locationController.text,
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('meetings')
          .add(meeting.toMap());

      // Save Firestore doc ID inside the document itself
      await docRef.update({'id': docRef.id});

      final meetingWithId = Meeting(
        id: docRef.id,
        title: meeting.title,
        startTime: meeting.startTime,
        endTime: meeting.endTime,
        startTime2: meeting.startTime2,
        endTime2: meeting.endTime2,
        date: meeting.date,
        createdBy: meeting.createdBy,
        participants: meeting.participants,
        attachments: meeting.attachments,
        location: meeting.location,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting created successfully')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MeetingDetailsScreen(meeting: meetingWithId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create meeting: $e')),
      );
    }
  }

  

  @override
  void initState() {
    super.initState();
    _fetchUsers(); // Load users when the page is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Meeting'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Meeting Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Meeting Title'),
            ),
            // Participants (emails)

            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Select Participants'),
              value: null, // Keep this null to avoid conflicts
              items: _allUsers.map((String email) {
                return DropdownMenuItem<String>(
                  value: email,
                  child: Text(email),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null && !_selectedParticipants.contains(value)) {
                  setState(() {
                    _selectedParticipants.add(value);
                  });
                }
              },
              hint: Text("Select participant(s)"),
            ),
            SizedBox(height: 16),
            // Selected Participants
            Wrap(
              children: _selectedParticipants.map((email) {
                return Chip(
                  label: Text(email),
                  onDeleted: () {
                    setState(() {
                      _selectedParticipants.remove(email);
                    });
                  },
                );
              }).toList(),
            ),
            // Meeting Location
            TextField(
              controller: _locationController,
              decoration:
                  InputDecoration(labelText: 'Location (Physical or Virtual)'),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                  style: TextStyle(fontSize: 16),
                ),
                ElevatedButton(
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now()
                          .subtract(Duration(days: 365)), // one year back
                      lastDate: DateTime.now()
                          .add(Duration(days: 365)), // one year forward
                    );
                    if (pickedDate != null && pickedDate != _selectedDate) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                  child: Text('Pick Date'),
                ),
              ],
            ),

            // Start Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start Time: ${_startTime.format(context)}'),
                ElevatedButton(
                  onPressed: () async {
                    TimeOfDay? pickedStartTime = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (pickedStartTime != null &&
                        pickedStartTime != _startTime) {
                      setState(() {
                        _startTime = pickedStartTime;
                      });
                    }
                  },
                  child: Text('Pick Start Time'),
                ),
              ],
            ),
            // End Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('End Time: ${_endTime.format(context)}'),
                ElevatedButton(
                  onPressed: () async {
                    TimeOfDay? pickedEndTime = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (pickedEndTime != null && pickedEndTime != _endTime) {
                      setState(() {
                        _endTime = pickedEndTime;
                      });
                    }
                  },
                  child: Text('Pick End Time'),
                ),
              ],
            ),

            DropdownButton<String>(
              value: _role,
              onChanged: (String? newValue) {
                setState(() {
                  _role = newValue!;
                });
              },
              items: <String>['attendee', 'host']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                    value: value, child: Text(value));
              }).toList(),
            ),
            SizedBox(height: 16),
            // Upload Attachment Button
 
            SizedBox(height: 16),
            // Create Meeting Button
            ElevatedButton(
              onPressed: _createMeeting,
              child: Text('Create Meeting'),
            ),
          ],
        ),
      ),
    );
  }
}
