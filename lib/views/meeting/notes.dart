import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kanban_board/kanban_board.dart';
import 'package:minute_meeting/models/kanban_group.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/note_details.dart';

class MeetingNotesKanbanPage extends StatefulWidget {
  final String meetingId;

  const MeetingNotesKanbanPage({required this.meetingId});

  @override
  _MeetingNotesKanbanPageState createState() => _MeetingNotesKanbanPageState();
}

class _MeetingNotesKanbanPageState extends State<MeetingNotesKanbanPage> {
  final KanbanBoardController controller = KanbanBoardController();
  int _noteIdCounter = 1;
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserFromPrefs();
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
      MeetingNote updatedNote, String meetingID) async {
    try {
      // Get the reference to the Firestore collection and the specific document
      final noteRef = FirebaseFirestore.instance
          .collection('meetings') // Collection for meetings
          .doc(meetingID) // Specific meeting ID
          .collection('notes') // Collection for notes under this meeting
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

  Future<void> deleteNoteFromFirestore(String noteId, String meetingUid) async {
    try {
      // Get the reference to the Firestore document for the specific note
      final noteRef = FirebaseFirestore.instance
          .collection('meetings') // Collection for meetings
          .doc(meetingUid) // Specific meeting ID
          .collection('notes') // Collection for notes under this meeting
          .doc(noteId); // The note document ID

      // Delete the note from Firestore
      await noteRef.delete();

      print("Note deleted successfully!");
    } catch (e) {
      // Handle errors, such as if the note or meeting doesn't exist
      print("Error deleting note: $e");
    }
  }

  Future<void> getMeetingDetailsAndSaveAsNote(
      String userId, String meetingId) async {
    try {
      // Reference to the specific meeting document
      final meetingRef = FirebaseFirestore.instance
          .collection('meetings') // Collection for meetings
          .doc(meetingId); // Meeting ID

      // Get the meeting document
      final docSnapshot = await meetingRef.get();

      if (docSnapshot.exists) {
        // If the document exists, extract the data
        final meetingDetails = docSnapshot.data() as Map<String, dynamic>;

        List<Map<String, dynamic>> createdByList = [];
        if (meetingDetails.containsKey('created_by')) {
          List<dynamic> createdBy = meetingDetails['created_by'];

          // Iterate over the createdBy list and store them as a list of maps
          for (var creator in createdBy) {
            if (creator is Map<String, dynamic>) {
              createdByList.add({
                'email': creator['email'],
                'name': creator['name'],
                'uid': creator['uid'],
              });
            }
          }
        }

        // Extract individual meeting details
        String title = meetingDetails['title'];
        Timestamp date = meetingDetails['date'];
        String location = meetingDetails['location'];
        Timestamp startTime = meetingDetails['startTime'];
        Timestamp endTime = meetingDetails['endTime'];

        // Create a note based on the meeting details
        Map<String, dynamic> noteData = {
          'title': title,
          'meetingId': meetingId,
          'startTime': startTime,
          'endTime': endTime,
          'createdBy': createdByList, // Store the list of creators
          'status': meetingDetails['status'],
          'timestamp': FieldValue
              .serverTimestamp(), // Automatically set the timestamp when the note is created
        };

        // Reference to the user's favourites collection
        final notesCollection = FirebaseFirestore.instance
            .collection('users') // Collection for users
            .doc(userId) // User ID
            .collection('favourites'); // User's favourites collection

        // Check if a note with the same meetingId already exists
        final existingNotesQuery = await notesCollection
            .where('meetingId',
                isEqualTo: meetingId) // Check for duplicate meetingId
            .get();

        if (existingNotesQuery.docs.isEmpty) {
          // If no existing note found, add the new note
          await notesCollection.add(noteData);
          print("Note added successfully for meeting $meetingId");
        } else {
          print("Note for meeting $meetingId already exists.");
        }
      } else {
        print("No such meeting exists.");
      }
    } catch (e) {
      // Handle errors
      print("Error fetching meeting details or saving note: $e");
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

Future<void> exportNotesToFirestore({
  required String meetingId,
}) async {
  final notesCollection = FirebaseFirestore.instance
      .collection('meetings')
      .doc(meetingId)
      .collection('notes');

  final batch = FirebaseFirestore.instance.batch();

  try {
    final snapshot = await notesCollection.get();

    if (snapshot.docs.isEmpty) {
      print('❌ No notes found for this meeting.');
      return;
    }

    final userId = currentUser!.uid;

    // ✅ Create a new note doc under users/{uid}/notes
    final newNoteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notes')
        .doc();

    final generatedNoteId = newNoteRef.id;

    // ✅ Add metadata for the main exported note
    final noteMetaData = {
      'user_uid': userId,
      'source_meeting_id': meetingId,
      'exported_note_id': generatedNoteId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    batch.set(newNoteRef, noteMetaData);

    // ✅ Subnotes collection under this note
    final subnotesCollection = newNoteRef.collection('subnotes');

    // ✅ Loop over all meeting notes
    for (var doc in snapshot.docs) {
      final noteData = doc.data();

      // Structure of each meeting note
      final subnoteData = {
        'title': noteData['title'],
        'content': noteData['content'],
        'group': noteData['group'],
        'author': noteData['author'],
        'original_note_id': noteData['id'] ?? doc.id,
        'timestamp': noteData['timestamp'],
        'exported_at': FieldValue.serverTimestamp(),
        'user_uid': userId,
      };

      final newSubnoteRef = subnotesCollection.doc();
      batch.set(newSubnoteRef, subnoteData);
    }

    // ✅ Commit the batch
    await batch.commit();
    print(
        '✅ All meeting notes exported as subnotes to users/$userId/notes/$generatedNoteId/subnotes.');
  } catch (e) {
    print("❌ Error exporting notes: $e");
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            tooltip: 'More options',
            onSelected: (value) async {
              if (value == 'favourite') {
                // Handle Set as Favourite
                // _setAsFavourite();
                await getMeetingDetailsAndSaveAsNote(
                    currentUser!.uid, widget.meetingId);
              } else if (value == 'export') {
                // Handle Export Note
                final List<Note> notesToExport = [
                  // Populate this list with notes from the Kanban board
                  // You should gather all notes from the groups or wherever you store them
                ];

                // Call the export function
                exportNotesToFirestore(
                  meetingId: widget.meetingId,
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'favourite',
                child: Text('Favourite'),
              ),
              PopupMenuItem<String>(
                value: 'export',
                child: Text('Export Note'),
              ),
            ],
          ),
        ],
      ),
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

            // Get author data and map it to the Author object
            final authorData = data['author'] as Map<String, dynamic>;
            final author = Author.fromMap(authorData);

            final note = MeetingNote(
              id: data['id'],
              title: data['title'],
              content: data['content'],
              timestamp: (data['timestamp'] as Timestamp).toDate(),
              author: author, // Use the Author object here
              group: data['group'],
            );
            final status = data['group'];
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
                elevation:
                    6, // Slightly increased elevation for a more pronounced shadow
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      16), // More rounded corners for a softer look
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                      16), // Ensure the ripple effect is rounded
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierDismissible:
                          true, // Allow dismiss by tapping outside
                      builder: (BuildContext context) {
                        return MeetingNoteDetailsPage(
                          note: note, // Pass the note here
                          onDelete: () async {
                            // Handle delete action here
                            // For example, call a method to delete this note from your data source
                            await deleteNoteFromFirestore(
                                note.id, widget.meetingId);
                            print("Note deleted: ${note.id}");
                            Navigator.pop(
                                context); // Close the dialog after deletion
                          },
                          onEdit: (updatedNote) async {
                            // Handle the edited note here
                            // For example, update the note in your data source
                            await updateNoteInFirestore(
                                updatedNote, widget.meetingId);

                            print("Note updated: ${updatedNote.title}");
                            Navigator.pop(
                                context); // Close the dialog after saving the changes
                          },
                        );
                      },
                    );
                  },
                 
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(
                        20), // Increased padding for a more spacious feel
                    title: Text(
                      note.title,
                      style: TextStyle(
                        fontSize: 18, // Slightly larger font size for the title
                        fontWeight: FontWeight
                            .w600, // Use a semi-bold weight for better emphasis
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(
                          top: 10.0), // Spacing between title and subtitle
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'By ${note.author.name} • ${_formatTimestamp(note.timestamp)}',
                            style: TextStyle(
                              fontSize:
                                  14, // Increased font size for better readability
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(
                              height:
                                  10), // Increased height for better spacing
                          Text(
                            note.content,
                            style: TextStyle(
                              fontSize:
                                  15, // Slightly larger font size for content
                              color: Colors.black.withOpacity(
                                  0.8), // More opaque text for better visibility
                            ),
                            maxLines: 3, // Allow more lines for content
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
