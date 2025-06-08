import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kanban_board/kanban_board.dart';
import 'package:minute_meeting/models/kanban_group.dart';
import 'package:minute_meeting/models/meetings.dart';
import 'package:minute_meeting/models/user.dart';



class MeetingNoteDetailsPage extends StatelessWidget {
  final MeetingNote note;
  final VoidCallback onDelete; // Callback for deleting the note
  final Function(MeetingNote) onEdit; // Callback for editing the note

  const MeetingNoteDetailsPage({
    required this.note,
    required this.onDelete, // Pass the delete callback
    required this.onEdit, // Pass the edit callback
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Author: ${note.author.name}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Time: ${note.timestamp}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              Text(
                note.content,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit Button
                  TextButton(
                    onPressed: () {
                      // Navigate to the edit page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeetingNoteEditPage(
                            note: note,
                            onSave: (updatedNote) {
                              // Handle the updated note, probably save it to your database
                              onEdit(updatedNote);
                            },
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Delete Button
                  TextButton(
                    onPressed: onDelete,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MeetingNoteEditPage extends StatefulWidget {
  final MeetingNote note;
  final Function(MeetingNote) onSave; // Callback to save the edited note

  const MeetingNoteEditPage({
    required this.note,
    required this.onSave,
  });

  @override
  _MeetingNoteEditPageState createState() => _MeetingNoteEditPageState();
}

class _MeetingNoteEditPageState extends State<MeetingNoteEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Meeting Note'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () {
              final updatedNote = MeetingNote(
                id: widget.note.id,
                title: _titleController.text,
                content: _contentController.text,
                timestamp:
                    widget.note.timestamp, // You can update timestamp if needed
                author: widget.note.author, // Assume the author does not change
                group: widget.note.group,
              );
              widget.onSave(updatedNote);
              Navigator.pop(context); // Close the edit page after saving
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Title'),
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(labelText: 'Content'),
                maxLines: 6,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
