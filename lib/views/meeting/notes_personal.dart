import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kanban_board/kanban_board.dart';
import 'package:minute_meeting/models/kanban_group.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/note_details.dart';

class MeetingNotesKanbanPage2 extends StatefulWidget {
  final String noteID;

  const MeetingNotesKanbanPage2({Key? key, required this.noteID})
      : super(key: key);

  @override
  _MeetingNotesKanbanPage2State createState() =>
      _MeetingNotesKanbanPage2State();
}

class _MeetingNotesKanbanPage2State extends State<MeetingNotesKanbanPage2> {
  final KanbanBoardController controller = KanbanBoardController();
  int _noteIdCounter = 1;
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserFromPrefs();
    print(widget.noteID);
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
        .collection('users')
        .doc(currentUser?.uid)
        .collection('notes')
        .doc(widget.noteID) // <-- Firestore generates a unique ID
        .collection('subnotes')
        .doc(); // <-- Firestore generates a unique ID

    final author = Author(name: currentUser!.name, uid: currentUser!.uid);

    final newNote = MeetingNote(
      id: docRef.id,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      author: author, // Pass a list of authors
      group: groupId,
    );

    await docRef.set(newNote.toMap());
  }

  Future<void> updateNoteInFirestore(
      MeetingNote updatedNote, String noteID) async {
    try {
      // Get the reference to the Firestore collection and the specific document
      final noteRef = FirebaseFirestore.instance
          .collection('users') // Collection for meetings
          .doc(currentUser!.uid) // Specific meeting ID
          .collection('notes') // Collection for notes under this meeting
          .doc(noteID) // The note document ID
          .collection('subnotes') // Collection for notes under this meeting
          .doc(updatedNote.id); // The note document ID
      // Update the note data in Firestore
      await noteRef.update({
        'title': updatedNote.title,
        'content': updatedNote.content,
        'group': updatedNote.group,
        'timestamp': Timestamp.fromDate(
            updatedNote.timestamp), // Ensure to convert DateTime to Timestamp
      });

      // Optionally, show a success message to the user
      print("Note updated successfully!");
    } catch (e) {
      // Handle any errors
      print("Error updating note: $e");
    }
  }

  Future<void> deleteNoteFromFirestore(String noteId) async {
    try {
      // Get the reference to the Firestore document for the specific note
      final noteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('notes')
          .doc(widget.noteID) // <-- Firestore generates a unique ID
          .collection('subnotes')
          .doc(noteId); // <-- Firestore generates a unique ID

      // Delete the note from Firestore
      await noteRef.delete();

      print("Note deleted successfully!");
    } catch (e) {
      // Handle errors, such as if the note or meeting doesn't exist
      print("Error deleting note: $e");
    }
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

  Future<void> _loadUserFromPrefs() async {
    final user = await UserModel.loadFromPrefs();
    if (user == null) return;

    setState(() {
      currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = currentUser?.uid;

    if (userId == null) {
      return Center(child: Text('User not logged in'));
    }

    final subnotesCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc(widget.noteID)
        .collection('subnotes');

    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: subnotesCollection
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No notes found.'));
          }

          // Parse documents into MeetingNote objects
          final allSubnotes = snapshot.data!.docs.map((doc) {
            final data = doc.data()! as Map<String, dynamic>;

            final authorData = data['author'] as Map<String, dynamic>? ?? {};
            final author = Author.fromMap(authorData);

            return MeetingNote(
              id: doc.id,
              title: data['title'] ?? '',
              content: data['content'] ?? '',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              author: author,
              group: data['group'] ?? 'ideas',
            );
          }).toList();

          // Group subnotes by group
          final ideas =
              allSubnotes.where((note) => note.group == 'ideas').toList();
          final discussed =
              allSubnotes.where((note) => note.group == 'discussed').toList();
          final actionItems = allSubnotes
              .where((note) => note.group == 'action_items')
              .toList();

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

              // Update the group field in Firestore for the moved note
              await subnotesCollection.doc(movedNote.id).update({
                'group': groups[newListIndex!].id,
              });
            },
            groupConstraints: BoxConstraints(maxWidth: 250),
            groupHeaderBuilder: (context, groupId) {
              final group = groups.firstWhere((g) => g.id == groupId);
              return Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: 20),
                      color: Colors.white,
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => MeetingNoteDetailsPage(
                        note: note,
                        onDelete: () async {
                          // Delete the subnote document
                          await deleteNoteFromFirestore(note.id);
                          Navigator.pop(context);
                        },
                        onEdit: (updatedNote) async {
                          // Update the subnote document fields

                          await updateNoteInFirestore(
                              updatedNote, widget.noteID);

                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    title: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'By ${note.author.name} • ${_formatTimestamp(note.timestamp)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            note.content,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black.withOpacity(0.8),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
