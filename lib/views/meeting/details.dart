import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minute_meeting/config/notification.dart';
import 'package:minute_meeting/helper/downloadpdf.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:minute_meeting/views/meeting/components/create_cmp.dart';
 import 'package:minute_meeting/views/meeting/notes.dart';
import 'package:minute_meeting/views/meeting/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingDetailsScreen extends StatefulWidget {
  final Meeting meeting;

  const MeetingDetailsScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends State<MeetingDetailsScreen> {
  UserModel? _currentUser;
  final TextEditingController _attachmentController = TextEditingController();
  late String selectedSeed;
  bool isHostc = false;
  @override
  void initState() {
    super.initState();
    _loadUserFromPrefs();
    selectedSeed = widget.meeting.seed;
  }

  bool isUserStatusAccepted(Meeting meeting, String currentUserUid) {
    // Find the participant in the meeting who matches the current user UID
    final participant = meeting.participants.firstWhere(
      (p) => p.uid == currentUserUid,
      // Return null if no match is found
    );

    // Check if the participant is found and their status is 'accepted'
    if (participant != null && participant.status == 'accepted') {
      subscribeToTopic('meeting-${widget.meeting.id}');

      return true;
    }

    return false; // Return false if the user is not found or not accepted
  }

  Future<void> _loadUserFromPrefs() async {
    final user = await UserModel.loadFromPrefs();
    if (user == null) return;

    setState(() {
      _currentUser = user;
    });

    (isUserStatusAccepted(widget.meeting, _currentUser!.uid));
  }

  bool _isPending(Meeting meeting) {
    if (_currentUser == null) return false;

    final matchingParticipant = meeting.participants.firstWhere(
      (p) => p.email == _currentUser!.email,
      orElse: () =>
          Participant(email: '', role: '', status: '', uid: '', name: ''),
    );

    return matchingParticipant.status == 'pending';
  }

  bool isHost(Meeting meeting) {
    if (_currentUser == null) return false;

    final isCreator = meeting.createdBy.any(
      (creator) => creator.uid == _currentUser!.uid,
    );

    final isHostParticipant = meeting.participants.any((p) {
      final participantUid = p.uid ?? '';
      final role = (p.role ?? '').toString().toLowerCase();

      print('Checking participant: uid=$participantUid, role=$role');

      return participantUid == _currentUser!.uid &&
          (role == 'host' || role == 'executive');
    });

    return isCreator || isHostParticipant;
  }

  Future<void> _acceptInvitation(Meeting meeting) async {
    if (_currentUser == null || meeting.id == null) {
      return;
    }

    try {
      final docId = meeting.id!;

      final updatedParticipantsList = meeting.participants.map((p) {
        if (p.email == _currentUser!.email) {
          return Participant(
            uid: p.uid,
            email: p.email,
            role: p.role,
            name: p.name,
            status: 'accepted',
          ).toMap();
        }
        return p.toMap();
      }).toList();

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(docId)
          .update({'participants': updatedParticipantsList});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted.')),
        );
      }
    } catch (e) {
      print('Error accepting invitation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept invitation: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadAttachment(Meeting meeting) async {
    if (_currentUser == null) return;

    try {
      // 1. Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'jpg', 'png'],
        allowMultiple: false,
      );

      if (result == null) return;

      final pickedFile = result.files.single;
      print("Picked: ${pickedFile.name}");
      print("File path: ${pickedFile.path}");

      if (pickedFile.path == null) {
        throw Exception('Picked file path is null.');
      }

      final file = File(pickedFile.path!);

      final storageRef = FirebaseStorage.instance.ref().child(
          'attachments/${meeting.id}/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}');

      // 🔥 Use putFile now that we have permission
      final uploadTask = storageRef.putFile(file);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Task state: ${snapshot.state}, bytes transferred: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      }, onError: (e) {
        print('Upload error during snapshot: $e');
      });
      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      print("Uploaded file URL: $downloadUrl");

      final newAttachment = Attachment(
        url: downloadUrl,
        uploadedBy: _currentUser!.email,
        filename: Uri.decodeFull(downloadUrl.split('/').last.split('?').first),
        status: isHost(meeting) ? 'approved' : 'pending',
      );

      final docId = meeting.id!;
      final updatedAttachments = [...meeting.attachments, newAttachment]
          .map((a) => a.toMap())
          .toList();

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(docId)
          .update({'attachments': updatedAttachments});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attachment uploaded: ${newAttachment.status}'),
          ),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleMeetingStatus(String newStatus) async {
    try {
      final meetingRef = FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meeting.id);
      // Assuming you have the seed or topic name to notify

      if (newStatus == 'started') {
        await meetingRef.update({
          'status': newStatus,
          'startTime2': Timestamp.now().toDate(),
        });

        String topic =
            'meeting-${widget.meeting.id}'; // Or you can set a custom topic like 'meeting_${meeting.id}'
        String title = 'Meeting Started';
        String body = 'The meeting  has started.';
        String sitename = 'site11'; // Replace with actual site name

        // Send the notification
        await sendNotificationTopic(topic, title, body, sitename);
      } else {
        await meetingRef.update({
          'status': newStatus,
          'endTime2': Timestamp.now().toDate(),
        });

        String topic =
            'meeting-${widget.meeting.id}'; // Or you can set a custom topic like 'meeting_${meeting.id}'
        String title = 'Meeting Started';
        String body = 'The meeting  has started.';
        String sitename = 'site11'; // Replace with actual site name

        // Send the notification
        await sendNotificationTopic(topic, title, body, sitename);
      }
    } catch (e) {
      print("Error updating meeting status: $e");
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

// Now it's safe to access fields
    final users = List<Map<String, dynamic>>.from(seedDoc['users'] ?? [])
        .where((u) =>
            u['uid'] != currentUser?.uid &&
            u['status']?.toString().toLowerCase() ==
                'accepted') // Only accepted users
        .toList();

    final List<String> availableEmails =
        users.map((u) => u['email'].toString()).toList();

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
                  // Dropdown to pick existing user
                  DropdownButtonFormField<String>(
                    value: selectedEmail,
                    decoration: InputDecoration(labelText: 'Select Email'),
                    items: availableEmails.map((email) {
                      return DropdownMenuItem(
                        value: email,
                        child: Text(email),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedEmail = value;
                        manualEmail =
                            ''; // Clear manual email when selecting from dropdown
                      });
                    },
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
              onPressed: () async {
                final emailToAdd = selectedEmail ?? manualEmail;

                if (emailToAdd.isNotEmpty &&
                    !widget.meeting.participants
                        .any((p) => p.email == emailToAdd)) {
                  try {
                    // 🔍 Optionally get additional info for the participant (name, uid)
                    final userQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .where('email', isEqualTo: emailToAdd)
                        .limit(1)
                        .get();

                    final userData = userQuery.docs.isNotEmpty
                        ? userQuery.docs.first.data()
                        : null;
                    final uid = userQuery.docs.first.id;
                    final name = userData?['name'] ?? 'Unknown';

                    final newParticipant = Participant(
                      uid: uid,
                      email: emailToAdd,
                      name: name,
                      role: selectedRole,
                      status: 'accepted',
                    );

                    // ✅ Update Firestore
                    await FirebaseFirestore.instance
                        .collection('meetings')
                        .doc(widget.meeting.id)
                        .update({
                      'participants':
                          FieldValue.arrayUnion([newParticipant.toMap()])
                    });

                    // ✅ Update local UI (if needed, pass a callback or setState)
                    setState(() {
                      widget.meeting.participants.add(newParticipant);
                    });

                    print('Participant added successfully.');
                  } catch (e) {
                    print('Error adding participant: $e');
                  }

                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<Attachment> _filteredAttachments(Meeting meeting) {
    isHostc =
        meeting.createdBy.any((creator) => creator.uid == _currentUser?.uid);
    print(meeting.createdBy);
    print('Meeting createdBy uids: ${meeting.createdBy.map((c) => c.uid)}');
    print('Current user uid: ${_currentUser?.uid}');
    for (final a in meeting.attachments) {
      print('Attachment: ${a.filename}, status: ${a.status}');
    }

    if (isHostc) {
      return meeting.attachments;
    } else {
      return meeting.attachments.where((a) => a.status == 'approved').toList();
    }
  }

  Future<void> _approveAttachment(
      Meeting meeting, Attachment attachment) async {
    if (meeting.id == null) return;

    try {
      final docId = meeting.id!;
      final updatedAttachments = meeting.attachments.map((a) {
        if (a.url == attachment.url) {
          return Attachment(
            url: a.url,
            uploadedBy: a.uploadedBy,
            filename: a.filename,
            status: 'accepted', // approve here
          ).toMap();
        }
        return a.toMap();
      }).toList();

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(docId)
          .update({'attachments': updatedAttachments});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment approved')),
        );
      }
    } catch (e) {
      print('Error approving attachment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve attachment: $e')),
        );
      }
    }
  }

  Future<void> _rejectAttachment(Meeting meeting, Attachment attachment) async {
    if (meeting.id == null) return;

    try {
      // 1. Delete file from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(attachment.url);
      await ref.delete();

      // 2. Remove attachment from list in Firestore
      final docId = meeting.id!;
      final updatedAttachments = meeting.attachments
          .where((a) => a.url != attachment.url) // remove rejected file
          .map((a) => a.toMap())
          .toList();

      await FirebaseFirestore.instance
          .collection('meetings')
          .doc(docId)
          .update({'attachments': updatedAttachments});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment rejected and deleted')),
        );
      }
    } catch (e) {
      print('Error rejecting attachment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject attachment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingId = widget.meeting.id;
    if (meetingId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meeting Details'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Meeting ID not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Details'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: 'View Notes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MeetingNotesKanbanPage(meetingId: meetingId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meetings')
            .doc(meetingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Meeting not found'));
          }

          final meetingData = snapshot.data!.data()! as Map<String, dynamic>;
          final meeting = Meeting.fromMap(meetingData);
          print("sadasdsa  ${isHost(meeting)}");

          final isPending = _isPending(meeting);
          final filteredAttachments = _filteredAttachments(meeting);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle('Date'),
                DateSectionCard(date: meeting.date),

                const SizedBox(height: 12),

                // Scheduled Start Time Section
                sectionTitle('Scheduled Time'),
                TimeRangeCard(
                  start: meeting.startTime,
                  end: meeting.endTime,
                ),

                const SizedBox(height: 12),

                // Actual Start Time Section (Optional)
                if (meeting.startTime2 != null && meeting.endTime2 != null) ...[
                  sectionTitle('Actual Time'),
                  TimeRangeCard(
                    start: meeting.startTime2!,
                    end: meeting.endTime2!,
                  ),
                  const SizedBox(height: 12),
                ],

                // Location Section
                sectionTitle('Location'),
                LocationCard(location: meeting.location),

                const SizedBox(height: 12),

                // Created By Section
                sectionTitle('Created By'),
                ...meeting.createdBy
                    .map((c) => CreatorCard(creator: c))
                    .toList(),

                const SizedBox(height: 12),

                if (!isPending) ...[
                  if (_currentUser != null) ...[
                    const SizedBox(height: 12),
                    sectionTitle(
                      'Attachments',
                      buttonText: 'Add',
                      onButtonPressed: () {
                        _pickAndUploadAttachment(meeting);
                      },
                    ),
                  ],
                  if (filteredAttachments.isEmpty)
                    const Text('No attachments')
                  else
                    ...filteredAttachments.map((a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file),
                          title: Text(
                            getFileName(a.url),
                            style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.blue),
                          ),
                          subtitle: Text('Status: ${a.status}'),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(getFileName(a.url)),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: a.url.toLowerCase().endsWith('.pdf')
                                      ? const Text(
                                          'Preview not available for PDF. Click Open to view in browser.',
                                        )
                                      : Image.network(
                                          a.url,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Text(
                                                  'Failed to load image preview'),
                                        ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('Open'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      launchURL(context, a.url);
                                    },
                                  ),
                                  if (isHost(meeting) &&
                                      a.status != 'approved') ...[
                                    TextButton(
                                      child: const Text('Approve'),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _approveAttachment(meeting, a);
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Reject'),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _rejectAttachment(meeting, a);
                                      },
                                    ),
                                  ],
                                  TextButton(
                                    child: const Text('Close'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            );
                          },
                        )),
                ],
                const SizedBox(height: 12),

                // Participants Section
                sectionTitle('Participants'),
                ...meeting.participants.map((p) => Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        title: Text(p.email,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p.role} • ${p.status}',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    )),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meetings')
            .doc(meetingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }
          final meetingData = snapshot.data!.data()! as Map<String, dynamic>;
          final meeting = Meeting.fromMap(meetingData);

          final isPending = _isPending(meeting);

          if (isPending) {
            return FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text("Accept Invite"),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Accept Invitation"),
                    content: const Text(
                        "Do you want to accept this meeting invitation?"),
                    actions: [
                      TextButton(
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      ElevatedButton(
                        child: const Text("Accept"),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _acceptInvitation(meeting);
                  setState(() {});
                }
              },
            );
          }

          // Show "Start" or "Stop" button for the host
          // Show "Start" or "Stop" button for the host
if (isHostc) {
  // Get today's date for comparison
  final today = DateTime.now();
  final meetingDate = widget.meeting.date;
  
  // Only show FloatingActionButton if the meeting is today and the status is not 'ended'
  if (meetingDate.year == today.year &&
      meetingDate.month == today.month &&
      meetingDate.day == today.day &&
      meeting.status != 'ended') {
    
    return FloatingActionButton.extended(
      icon: Icon(
        meeting.status == null || meeting.status == 'not_started'
            ? Icons.play_arrow // Show play button if not started
            : Icons.stop, // Show stop button if started
      ),
      label: Text(
        meeting.status == null || meeting.status == 'not_started'
            ? "Start Meeting"
            : "End Meeting", // Change label depending on status
      ),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(meeting.status == null || meeting.status == 'not_started'
                ? "Start the meeting"
                : "End the meeting"),
            content: Text(meeting.status == null || meeting.status == 'not_started'
                ? "Do you want to start the meeting?"
                : "Do you want to end the meeting?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                child: Text(
                  meeting.status == null || meeting.status == 'not_started'
                      ? "Start"
                      : "End",
                ),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // If the meeting is not started, set it to 'started'
          if (meeting.status == null || meeting.status == 'not_started') {
            // Change the meeting status to 'started'
            await _toggleMeetingStatus('started');
          } else {
            // End the meeting if it's started
            await _toggleMeetingStatus('ended');
          }

          setState(() {}); // Refresh the UI after the action
        }
      },
    );
  }
  
  // If the meeting status is 'ended', or the meeting isn't today, no FloatingActionButton
  return SizedBox.shrink(); // Empty widget, no button
}


          // If the user is not the host and the status is not pending, don't show anything
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
