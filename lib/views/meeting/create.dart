import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For file picker (e.g., images)
import 'dart:io';

import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/room.dart';
import 'package:minute_meeting/models/seed.dart';
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
  List<String> _allUsers = [];
  List<Seed> _seeds = []; // This should be a list of Seed objects
  List<Room> _rooms = []; // To store rooms under the selected seed
  String? _selectedSeed;
  String? _selectedRoom;

  User? _currentUser;
  List<String> _selectedParticipants = []; // This will now store emails + roles
  Map<String, String> _participantRoles = {}; // Maps emails to their roles

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0); // Default start time
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0); // Default end time

  // Convert TimeOfDay to DateTime
  DateTime _timeToDateTime(TimeOfDay time) {
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
        time.hour, time.minute);
  }

  // Fetch all users from Firestore and the user's seeds
  Future<void> _fetchUsersAndSeeds() async {
    try {
      UserModel? currentUser = await UserModel.loadFromPrefs();

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final seedsFromDoc =
            List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);

        setState(() {
          // Map to get both seed name and seed ID
          _seeds = seedsFromDoc
              .map((seed) => Seed(
                    name: seed['name'] as String,
                    seedId: seed['seed'] as String,
                     users: [],
                  ))
              .toList();
        });
      }
    } catch (e) {
      print("Error fetching users and seeds: $e");
    }
  }

  Future<void> _selectParticipantRole(String email) async {
    String? selectedRole = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Role for $email"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("Host"),
                onTap: () {
                  Navigator.of(context).pop('host');
                },
              ),
              ListTile(
                title: Text("Moderator"),
                onTap: () {
                  Navigator.of(context).pop('moderator');
                },
              ),
              ListTile(
                title: Text("Attendee"),
                onTap: () {
                  Navigator.of(context).pop('attendee');
                },
              ),
            ],
          ),
        );
      },
    );

    // If a role was selected, add the participant with the selected role
    if (selectedRole != null) {
      setState(() {
        _participantRoles[email] = selectedRole; // Store the role for the email
        if (!_selectedParticipants.contains(email)) {
          _selectedParticipants.add(email); // Add the email to the list
        }
      });
    }
  }

 Future<void> _fetchRoomsForSeed(String seed) async {
  try {
    final roomsSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .where('seedId', isEqualTo: seed)
        .get();

    setState(() {
      _rooms = roomsSnapshot.docs
          .map((doc) => Room.fromMap(doc.id, doc.data()))
          .toList();
    });
  } catch (e) {
    print("Error fetching rooms for seed: $e");
  }
}

  // Create a meeting and store it in Firestore
  void _createMeeting() async {
    if (_titleController.text.isEmpty ||
        _selectedParticipants.isEmpty ||
        _selectedSeed == null ||
        _selectedRoom == null) {
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
    var allUsersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

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
      location: _selectedRoom!, // Now using selected room instead of text
      seed: _selectedSeed!, // Save the selected seed as part of the meeting
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
        date: meeting.date,
        createdBy: meeting.createdBy,
        participants: meeting.participants,
        attachments: meeting.attachments,
        location: meeting.location,
        seed: meeting.seed,
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
    _fetchUsersAndSeeds(); // Load users and seeds when the page is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Meeting'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Meeting Title
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Meeting Title'),
              ),
              // Seed Dropdown
              DropdownButton<String>(
                value: _selectedSeed,
                hint: Text("Select Seed"),
                onChanged: (value) {
                  setState(() {
                    _selectedSeed = value;
                    _rooms.clear(); // Clear previous room selections
                  });
                  if (value != null) {
                    _fetchRoomsForSeed(
                        value); // Fetch rooms when a seed is selected
                    print(value);
                  }
                },
                items: _seeds.map((seed) {
                  return DropdownMenuItem<String>(
                    value:
                        seed.seedId, // Use seedId as the value for the dropdown
                    child: Text(seed.name), // Display the seed name
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              // Room Dropdown (for selected seed)
              // Room Dropdown
              DropdownButton<String>(
                value: _selectedRoom,
                hint: Text(
                    "Select Room"), // Display this hint when no room is selected
                onChanged: (value) {
                  setState(() {
                    _selectedRoom = value; // Update selected room
                  });
                },
items: _rooms.map((room) {
  return DropdownMenuItem<String>(
    value: room.roomId,   // Use unique ID or name as string
    child: Text(room.name), // Show the room name
  );
}).toList(),

              ),
              SizedBox(height: 16),
              // Participants (emails)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Select Participant'),
                value: null, // Keep this null to avoid conflicts
                items: _allUsers.map((String email) {
                  return DropdownMenuItem<String>(
                    value: email,
                    child: Text(email),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !_selectedParticipants.contains(value)) {
                    _selectParticipantRole(value); // Show dialog to select role
                  }
                },
                hint: Text("Select participant(s)"),
              ),

              SizedBox(height: 16),

              // Display selected participants with their roles
              Wrap(
                children: _selectedParticipants.map((email) {
                  String role = _participantRoles[email] ??
                      'Attendee'; // Default to 'Attendee' if no role selected
                  return Chip(
                    label: Text('$email ($role)'),
                    onDeleted: () {
                      setState(() {
                        _selectedParticipants.remove(email);
                        _participantRoles
                            .remove(email); // Remove the role as well
                      });
                    },
                  );
                }).toList(),
              ),
              // Meeting Location (No longer a free text field, it's a room now)
              // No longer need location text input, as location is based on room.
              SizedBox(height: 16),

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

              SizedBox(height: 16),
              // Create Meeting Button
              ElevatedButton(
                onPressed: _createMeeting,
                child: Text('Create Meeting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
