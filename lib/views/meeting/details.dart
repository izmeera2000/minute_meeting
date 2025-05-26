import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    final user = await UserModel.loadFromPrefs();
    if (user == null) return;

    setState(() {
      _currentUser = user;
    });
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
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

    final isHostParticipant = meeting.participants.any(
      (p) => p.uid == _currentUser!.uid && p.role.toLowerCase() == 'host',
    );

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

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('attachments/${meeting.id}/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}');

    // 🔥 Use putFile now that we have permission
    final uploadTask = storageRef.putFile(file);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
  print('Task state: ${snapshot.state}, bytes transferred: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
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
      status: isHost(meeting) ? 'accepted' : 'pending',
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





  @override
  Widget build(BuildContext context) {
    final meetingId = widget.meeting.id;
    if (meetingId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting Details')),
        body: const Center(child: Text('Meeting ID not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Details')),
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

          final isPending = _isPending(meeting);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Date'),
                Text(DateFormat('yyyy-MM-dd').format(meeting.date)),
                const SizedBox(height: 12),
                _sectionTitle('Scheduled Start Time'),
                Text(
                    '${_formatDateTime(meeting.startTime)} - ${_formatDateTime(meeting.endTime)}'),
                const SizedBox(height: 12),
                if (meeting.startTime2 != null && meeting.endTime2 != null) ...[
                  _sectionTitle('Actual Start Time'),
                  Text(
                      '${_formatDateTime(meeting.startTime2!)} - ${_formatDateTime(meeting.endTime2!)}'),
                  const SizedBox(height: 12),
                ],
                _sectionTitle('Location'),
                Text(meeting.location),
                const SizedBox(height: 12),
                _sectionTitle('Created By'),
                ...meeting.createdBy.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: Text(c.email),
                    )),
                const SizedBox(height: 12),
                _sectionTitle('Participants'),
                ...meeting.participants.map((p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.email),
                      subtitle: Text('${p.role} • ${p.status}'),
                    )),
                const SizedBox(height: 12),
if (!isPending) ...[
  _sectionTitle('Attachments'),
  if (_currentUser != null) ...[
    const SizedBox(height: 12),
    _sectionTitle('Upload Attachment'),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _attachmentController,
            decoration: const InputDecoration(
              hintText: 'Enter attachment URL',
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: () => _pickAndUploadAttachment(meeting),
        ),
      ],
    ),
  ],
  if (meeting.attachments.isEmpty)
    const Text('No attachments')
  else
    ...meeting.attachments.map((a) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insert_drive_file),
      title: Text(
        _getFileName(a.url),
        style: const TextStyle(decoration: TextDecoration.underline, color: Colors.blue),
      ),
      subtitle: Text('Status: ${a.status}'),
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(_getFileName(a.url)),
            content: SizedBox(
              width: double.maxFinite,
              child: a.url.endsWith('.pdf') 
                ? const Text('Preview not available for PDF. Click Open to view in browser.') 
                : Image.network(a.url, errorBuilder: (_, __, ___) => const Text('Failed to load preview')),
            ),
            actions: [
              TextButton(
                child: const Text('Open'),
                onPressed: () {
                  Navigator.pop(context);
                  _launchURL(a.url);
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    )),
]

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

          if (!isPending) return const SizedBox.shrink();

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
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
String _getFileName(String url) {
  return Uri.decodeFull(url.split('/').last.split('?').first);
}

void _launchURL(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // Handle error
  }
}
