import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kanban_board/kanban_board.dart';

class KanbanItem extends KanbanBoardGroupItem {
  final String id;
  final String title;
  final DateTime timestamp;
  final String createdBy;

  KanbanItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.createdBy,
  });
  @override
  String get itemId => id;
}
 

class Author {
  final String name;
  final String uid;

  Author({required this.name, required this.uid});

  // Convert the Author object to a Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uid': uid,
    };
  }

  // Convert from Map to Author object
  factory Author.fromMap(Map<String, dynamic> map) {
    return Author(
      name: map['name'] ?? '',  // Ensure it handles missing values
      uid: map['uid'] ?? '',    // Ensure it handles missing values
    );
  }
}


class MeetingNote extends KanbanBoardGroupItem {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final Author author;  // Changed from List<Author> to Author
  final String group;   // Added field for group

  MeetingNote({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.author,  // Accepts a single Author object
    required this.group,   // Accepts a group as a String
  });

  @override
  String get itemId => id;

  // Convert MeetingNote to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'author': author.toMap(),  // Convert Author to a map
      'group': group,  // Convert group to a map or value
    };
  }

  // Create MeetingNote from Firestore data
  factory MeetingNote.fromMap(Map<String, dynamic> map) {
    final authorMap = map['author'];  // Get the author map from Firestore
    final author = Author.fromMap(authorMap);  // Convert the map to an Author object

    return MeetingNote(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      author: author,  // Pass the Author object
      group: map['group'],  // Retrieve the group field from Firestore map
    );
  }
}
