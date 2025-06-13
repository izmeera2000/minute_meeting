import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kanban_board/kanban_board.dart';

class Creator {
  final String uid;
  final String name;
  final String email;

  Creator({
    required this.uid,
    required this.name,
    required this.email,
  });

  factory Creator.fromMap(Map<String, dynamic> map) {
    return Creator(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
    };
  }
}

class Note extends KanbanBoardGroupItem {
  final String id;
  final String content;
  String status; // 'todo', 'in-progress', 'done'

  Note({
    required this.id,
    required this.content,
    required this.status,
  });

  @override
  String get itemId => id;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'status': status,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      status: map['status'],
    );
  }
}

class Participant {
  String uid;
  String email;
  String role;
  String status;
  String name;

  Participant({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.status = "pending",
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid, // Include uid here
      'email': email,
      'name': name, // Include name here
      'role': role,
      'status': status,
    };
  }

  factory Participant.fromMap(String uid, Map<String, dynamic> map) {
    return Participant(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      name: map['name'] ?? '',
      status: map['status'] ?? "pending",
    );
  }
}

class Attachment {
  String url;
  String status;
  String uploadedBy;
  String filename; // New field

  Attachment({
    required this.url,
    required this.uploadedBy,
    required this.filename,
    this.status = "pending",
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'status': status,
      'uploadedBy': uploadedBy,
      'filename': filename,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      url: map['url'],
      status: map['status'] ?? "pending",
      uploadedBy: map['uploadedBy'] ?? "Unknown",
      filename: map['filename'] ??
          Uri.decodeFull(
              map['url']?.split('/').last?.split('?').first ?? 'unknown_file'),
    );
  }
}

class Meeting {
  final String? id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? startTime2;
  final DateTime? endTime2;
  final List<Creator> createdBy;
  final DateTime date;
  List<Note>? notes;
  final List<Participant> participants;
  final List<Attachment> attachments;
  final String location;
  final String seed; // Added seed field
  String? userStatus; // Current user's status for this meeting
  String? status; // Added status field for the meeting

  Meeting({
    this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.startTime2,
    this.endTime2,
    required this.createdBy,
    required this.date,
    required this.participants,
    required this.attachments,
    required this.location,
    required this.seed, // Accept seed in the constructor
    this.notes, // optional
    this.userStatus,
    this.status, // Include status in the constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'startTime2': startTime2 != null ? Timestamp.fromDate(startTime2!) : null,
      'endTime2': endTime2 != null ? Timestamp.fromDate(endTime2!) : null,
      'date': Timestamp.fromDate(date),
      'created_by': createdBy.map((c) => c.toMap()).toList(),
      if (notes != null) 'notes': notes!.map((n) => n.toMap()).toList(),
      'participants': participants.map((p) => p.toMap()).toList(),
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'location': location,
      'seed': seed, // Include seed in the map
      if (status != null) 'status': status, // Add status to the map
    };
  }

  factory Meeting.fromMap(Map<String, dynamic> map) {
    // Safely parse participants
    final participantsList = (map['participants'] is List)
        ? (map['participants'] as List<dynamic>).map((e) {
            final participantMap = e as Map<String, dynamic>;
            final uid = participantMap['uid'] as String? ?? '';
            return Participant.fromMap(uid, participantMap);
          }).toList()
        : <Participant>[]; // fallback to empty list if malformed

    final attachmentsList = (map['attachments'] is List)
        ? (map['attachments'] as List<dynamic>)
            .map((e) => Attachment.fromMap(e as Map<String, dynamic>))
            .toList()
        : <Attachment>[];

    final creatorList = (map['created_by'] is List)
        ? (map['created_by'] as List<dynamic>)
            .map((e) => Creator.fromMap(e as Map<String, dynamic>))
            .toList()
        : <Creator>[];

    final notesList = (map['notes'] is List)
        ? (map['notes'] as List<dynamic>)
            .map((noteMap) => Note.fromMap(noteMap))
            .toList()
        : null;

    return Meeting(
      id: map['id'] as String?,
      title: map['title'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      startTime2: map['startTime2'] != null
          ? (map['startTime2'] as Timestamp).toDate()
          : null,
      endTime2: map['endTime2'] != null
          ? (map['endTime2'] as Timestamp).toDate()
          : null,
      notes: notesList,
      date: (map['date'] as Timestamp).toDate(),
      createdBy: creatorList,
      participants: participantsList,
      attachments: attachmentsList,
      location: map['location'] ?? '',
      seed: map['seed'] ?? '', // Retrieve seed from the map
      status: map['status'], // Retrieve status from the map (nullable)
    );
  }
}
