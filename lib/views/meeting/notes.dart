import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kanban_board/kanban_board.dart';
import 'package:minute_meeting/models/kanban_group.dart';

class MeetingNotesKanbanPage extends StatefulWidget {
  final String meetingId;

  const MeetingNotesKanbanPage({required this.meetingId});

  @override
  _MeetingNotesKanbanPageState createState() => _MeetingNotesKanbanPageState();
}

class _MeetingNotesKanbanPageState extends State<MeetingNotesKanbanPage> {
  final KanbanBoardController controller = KanbanBoardController();
  int _noteIdCounter = 1;
  @override
  void initState() {
    super.initState();
  }

  List<KanbanBoardGroup<String, MeetingNote>> groups = [
    KanbanBoardGroup<String, MeetingNote>(
      id: 'ideas',
      name: 'Ideas',
      items: [],
    ),
    KanbanBoardGroup<String, MeetingNote>(
      id: 'discussed',
      name: 'Discussed',
      items: [],
    ),
    KanbanBoardGroup<String, MeetingNote>(
      id: 'action_items',
      name: 'Action Items',
      items: [],
    ),
  ];
  void _addNoteToGroup(String groupId, String title, String content) async {
    final docRef = FirebaseFirestore.instance
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('notes')
        .doc(); // <-- Firestore generates a unique ID

    final newNote = MeetingNote(
      id: docRef.id,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      author: 'User',
    );

    await docRef.set({
      'id': newNote.id,
      'title': newNote.title,
      'content': newNote.content,
      'timestamp': Timestamp.fromDate(newNote.timestamp),
      'author': newNote.author,
      'status': groupId,
    });
  }

  String _formatTimestamp(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _showAddNoteDialog(String groupId) async {
    String title = '';
    String content = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('Add Note to ${groupId.replaceAll("_", " ").toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Title'),
              onChanged: (value) => title = value,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Content'),
              maxLines: 3,
              onChanged: (value) => content = value,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (title.trim().isNotEmpty && content.trim().isNotEmpty) {
                _addNoteToGroup(groupId, title.trim(), content.trim());
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meeting Notes Kanban')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meetings')
            .doc(widget.meetingId)
            .collection('notes')
            .orderBy('timestamp')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final ideas = <MeetingNote>[];
          final discussed = <MeetingNote>[];
          final actionItems = <MeetingNote>[];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final note = MeetingNote(
              id: data['id'],
              title: data['title'],
              content: data['content'],
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              author: data['author'],
            );
            final status = data['status'];
            if (status == 'ideas') {
              ideas.add(note);
            } else if (status == 'discussed') {
              discussed.add(note);
            } else if (status == 'action_items') {
              actionItems.add(note);
            }
          }

          final groups = [
            KanbanBoardGroup(id: 'ideas', name: 'Ideas', items: ideas),
            KanbanBoardGroup(
                id: 'discussed', name: 'Discussed', items: discussed),
            KanbanBoardGroup(
                id: 'action_items', name: 'Action Items', items: actionItems),
          ];

          return KanbanBoard(
            controller: controller,
            groups: groups,
            onGroupItemMove:
                (oldCardIndex, newCardIndex, oldListIndex, newListIndex) async {
              final movedNote = groups[oldListIndex!].items[oldCardIndex!];

              // Firestore update
              await FirebaseFirestore.instance
                  .collection('meetings')
                  .doc(widget.meetingId)
                  .collection('notes')
                  .doc(movedNote.id)
                  .update({'status': groups[newListIndex!].id});
            },
            groupConstraints: BoxConstraints(maxWidth: 250),
            groupHeaderBuilder: (context, groupId) {
              final group = groups.firstWhere((g) => g.id == groupId);
              return Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(group.name,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.add, size: 20),
                      tooltip: 'Add Note',
                      onPressed: () => _showAddNoteDialog(group.id),
                    ),
                  ],
                ),
              );
            },
            groupItemBuilder: (context, groupId, itemIndex) {
              final note =
                  groups.firstWhere((g) => g.id == groupId).items[itemIndex];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(note.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By ${note.author} • ${_formatTimestamp(note.timestamp)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 4),
                      Text(note.content,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MeetingNoteDetailsPage(note: note),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MeetingNoteDetailsPage extends StatelessWidget {
  final MeetingNote note;
  const MeetingNoteDetailsPage({required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(note.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Author: ${note.author}', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Time: ${note.timestamp}', style: TextStyle(fontSize: 14)),
            SizedBox(height: 16),
            Text(note.content, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
