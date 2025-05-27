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
 

class MeetingNote extends KanbanBoardGroupItem {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final String author;

  MeetingNote({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.author,
  });

  @override
  String get itemId => id;
}