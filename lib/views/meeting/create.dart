import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For file picker (e.g., images)
import 'package:minute_meeting/config/notification.dart';
import 'package:minute_meeting/config/style.dart';
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
    late DateTime _selectedDate;

  final _titleController = TextEditingController();
  final _participantsController = TextEditingController();
  final _locationController = TextEditingController(); // For location input
  final _attachmentUrls = <Attachment>[]; // List of attachments
  List<String> _allUsers = [];
  List<Seed> _seeds = []; // This should be a list of Seed objects
  List<Room> _rooms = []; // To store rooms under the selected seed
  String? selectedSeed;
  String? _selectedRoom;
  Map<String, dynamic>? selectedUser;
  String? selectedUserUid; // store uid only

  UserModel? currentUser;
  List<Map<String, dynamic>> _selectedParticipants = [];
  Map<String, String> _participantRoles = {}; // Maps emails to their roles

   TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0); // Default start time
  TimeOfDay _endTime = TimeOfDay(hour: 10, minute: 0); // Default end time

  // Convert TimeOfDay to DateTime
  DateTime _timeToDateTime(TimeOfDay time) {
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
        time.hour, time.minute);
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Retrieve the selected date passed from the previous screen
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments != null && arguments is DateTime) {
      _selectedDate = arguments;
    } else {
      _selectedDate = DateTime.now(); // Default to current date if no date is passed
    }
  }


  Future<void> _fetchUsersAndSeeds() async {
    try {
      UserModel? currentUser = await UserModel.loadFromPrefs();

      if (currentUser != null) {
        // Fetch the user's document from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final seedsFromDoc =
            List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);

        // Create a list of Seed objects by filtering based on user role
        List<Seed> filteredSeeds = [];

        for (var seed in seedsFromDoc) {
          final seedId = seed['seed']?.toString() ?? '';
          final seedName = seed['name']?.toString() ?? '';

          // Fetch the seed document from Firestore
          final seedDoc = await FirebaseFirestore.instance
              .collection('seeds')
              .doc(seedId)
              .get();

          if (seedDoc.exists) {
            final seedData = seedDoc.data();
            final users = (seedData?['users'] as List<dynamic>)
                .map((userMap) =>
                    SeedUser.fromMap(userMap as Map<String, dynamic>))
                .toList(); // Convert to List<SeedUser>

            // Find the user's entry in the users list and check the role
            final userEntry = users.firstWhere(
              (user) => user.uid == currentUser.uid,
              orElse: () => SeedUser(uid: '', role: '', status: '', email: ''),
            );

            if (userEntry.uid.isNotEmpty) {
              final userRole = userEntry.role;
              final userStatus = userEntry.status;

              // Only add the seed if the user has a certain role, e.g., 'admin' or 'member'
              // You can adjust this based on your requirement
              if (userRole == 'admin' && userStatus == 'accepted') {
                filteredSeeds.add(
                  Seed(
                    seedId: seedId,
                    name: seedName,
                    users: users, // Now users is a List<SeedUser>
                  ),
                );
              }
            }
          }
        }

        // Update the state with the filtered seeds list
        setState(() {
          _seeds = filteredSeeds;
        });
      }
    } catch (e) {
      print("Error fetching users and seeds: $e");
    }
  }

  Future<void> _fetchRoomsForSeed(String seedId) async {
    try {
      final roomsSnapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .where('seed', isEqualTo: seedId)
          .get();

      setState(() {
        _rooms = roomsSnapshot.docs
            .map((doc) =>
                Room.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      });

      // Print the rooms map to the console
      print("Rooms fetched successfully: $_rooms");
    } catch (e) {
      print("Error fetching rooms for seed: $e");
    }
  }

  // Create a meeting and store it in Firestore
  void _createMeeting() async {
    if (_titleController.text.isEmpty ||
        _selectedParticipants.isEmpty ||
        selectedSeed == null ||
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
    for (var participant in _selectedParticipants) {
      final email = participant['email'];
      final uid = participant['uid'];
      final name = participant['name'];
      final role = participant['role'];

      if (email != null && uid != null) {
        participants.add(
          Participant(
            uid: uid,
            email: email,
            name: name ?? '',
            role: role ?? '',
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
      seed: selectedSeed!, // Save the selected seed as part of the meeting
    );

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('meetings')
          .add(meeting.toMap());

      // Save Firestore doc ID inside the document itself
      await docRef.update({'id': docRef.id});

      for (Participant participant in participants) {
        // Skip sending notification to the host
        // if (participant.uid == currentUser.uid) continue;

        // Fetch user's FCM token from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(participant.uid)
            .get();

        final fcmToken = userDoc.data()?['fcmToken'];
        print(fcmToken);

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await sendNotificationToFCM(
            fcmToken,
            "You've been invited!",
            'New meeting: ${meeting.title}',
            'site11',
          );
          
                    String botToken =
                  '7833413502:AAFDP4OLzJIZuJU_Rm2a5ueaNtTSXHsf-I0'; // Replace with your Bot Token
              String groupChatId = '-4798645160'; // Replace with your Chat ID
              String message = "${participant.email} been invited to new meeting: ${meeting.title}" ;
              await sendTelegramGroupMessage(botToken, groupChatId, message);
        } else {
          print("No FCM token for ${participant.name}");
        }
      }

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

      Navigator.pushReplacement(
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

  void _showAddParticipantDialog() async {
    String? selectedEmail;
    String selectedRole = 'attendee'; // Default role
    List<String> roles = ['attendee', 'executive', 'host']; // Adjust if needed

    final seedDoc = await FirebaseFirestore.instance
        .collection('seeds')
        .doc(selectedSeed)
        .get();

    if (!seedDoc.exists) {
      print("Seed with ID $selectedSeed does not exist.");
      return; // Exit early to avoid accessing non-existent data
    }

    UserModel? currentUser = await UserModel.loadFromPrefs();
    print("Current user UID: ${currentUser?.uid}");

// Debug: print the entire seedDoc
    print('seedDoc: $seedDoc');

// Debug: print current user UID
    print('Current User UID: ${currentUser?.uid}');

// Extract the users list
    final List<dynamic>? rawUsers = seedDoc['users'];
    print('Raw users list: $rawUsers');

// Safely convert to List<Map<String, dynamic>> and filter
    final List<Map<String, dynamic>>? availableUsers = rawUsers
        ?.where((u) {
          final uid = u['uid'];
          final status = u['status']?.toString().toLowerCase();

          // Debug: Print each user’s info
          print('Checking user: uid=$uid, status=$status');

          return uid != currentUser?.uid && status == 'accepted';
        })
        .map<Map<String, dynamic>>((u) => Map<String, dynamic>.from(u))
        .toList();

// Final debug print
    print('Filtered availableUsers: $availableUsers');

    showDialog(
      context: context,
      builder: (context) {
        String manualEmail = '';

        return AlertDialog(
          title: Text("Add Participant"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedUserUid != null &&
                            availableUsers!
                                .any((u) => u['uid'] == selectedUserUid)
                        ? selectedUserUid
                        : null,
                    decoration: const InputDecoration(labelText: 'Select User'),
                    items: availableUsers?.map((user) {
                      return DropdownMenuItem<String>(
                        value: user['uid'],
                        child: Text(user['email'] ?? 'No Email'),
                      );
                    }).toList(),
                    onChanged: (uid) {
                      setState(() {
                        selectedUserUid = uid;
                        manualEmail = '';
                      });
                    },
                    hint: const Text('Please select a user'),
                    validator: (value) =>
                        value == null ? 'Please select a user' : null,
                  ),
                  SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(labelText: 'Select Role'),
                    items: roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text("Add"),
              onPressed: () {
                final user = availableUsers?.firstWhere(
                  (u) => u['uid'] == selectedUserUid,
                  orElse: () => {}, // empty map fallback to prevent crash
                );


                final alreadyAdded = _selectedParticipants
                    .any((p) => p['uid'] == selectedUserUid);

                if (!alreadyAdded) {
                  setState(() {
                    _selectedParticipants.add({
                      'uid': user?['uid'],
                      'name': user?['name'],
                      'email': user?['email'],
                      'role': selectedRole!, // chosen role
                    });
                  });
                } else {
                  print("alr");
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUsersAndSeeds(); // Load users and seeds when the page is initialized
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Create Meeting'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DropdownField(
                value: selectedSeed,
                label: 'Select Group',
                hintText: 'Select Group',
                items: _seeds.map((seed) {
                  return DropdownMenuItem<String>(
                    value: seed.seedId,
                    child: Text(seed.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSeed = value;
                    _rooms.clear(); // Clear previous room selections
                  });
                  if (value != null) {
                    _fetchRoomsForSeed(
                        value); // Fetch rooms when a seed is selected
                    print(value);
                  }
                },
              ),

              InputField(controller: _titleController, text: 'Meeting Title'),

              // Seed Dropdown

              // Meeting Location (No longer a free text field, it's a room now)
              // No longer need location text input, as location is based on room.
              SizedBox(height: 16),

              DatePickerRow(
                selectedDate: _selectedDate,
                onDateChanged: (newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),

              // Start Time
              TimePickerRow(
                label: 'Start Time',
                time: _startTime,
                onTimeChanged: (picked) {
                  setState(() {
                    _startTime = picked;
                  });
                },
              ),

              TimePickerRow(
                label: 'End Time',
                time: _endTime,
                onTimeChanged: (picked) {
                  setState(() {
                    _endTime = picked;
                  });
                },
              ),

              SizedBox(height: 16),
              // Room Dropdown (for selected seed)
              // Room Dropdown
              DropdownField(
                value: _selectedRoom,
                label: 'Select Room',
                hintText: 'Select Room',
                items: _rooms.map((room) {
                  return DropdownMenuItem<String>(
                    value: room.name, // Use unique ID
                    child: Text(room.name), // Display room name
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRoom = value; // Update selected room
                  });
                },
              ),

              SizedBox(height: 16),

              SizedBox(height: 16),
              // Participants (emails)
              ButtonCustom(
                onPressed: _showAddParticipantDialog,
                label: "Add Participant",
                icon: Icons.person_add,
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),

              SizedBox(height: 16),

              ParticipantChips(
                participants: _selectedParticipants,
                onRemove: (user) {
                  setState(() {
                    _selectedParticipants.remove(user);
                  });
                },
              ),
              // Create Meeting Button
              SizedBox(height: 16),

              ButtonCustom(
                onPressed: _createMeeting,
                label: "Create Meeting",
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
