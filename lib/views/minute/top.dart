import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/meeting/notes.dart';

class TwoTabsPage extends StatelessWidget {
  const TwoTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // number of tabs
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          title: const Text('My Minute Meetings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.favorite ,color: Colors.white,)),
              Tab(icon: Icon(Icons.list ,color: Colors.white,),  ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FavoriteNotesTab(),
            Center(child: Text('Content for Tab 2')),
          ],
        ),
      ),
    );
  }
}

class FavoriteNotesTab extends StatefulWidget {
  const FavoriteNotesTab();

  @override
  State<FavoriteNotesTab> createState() => _FavoriteNotesTabState();
}

class _FavoriteNotesTabState extends State<FavoriteNotesTab> {
  UserModel? currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserFromPrefs();
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid) // Replace with your actual user ID
          .collection('notes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No favorite notes available.'));
        }

        final notes = snapshot.data!.docs;

        return ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final title = note['title'];
            final meetingId = note['meetingId'];
            final createdBy =
                note['createdBy'][0]; // This should be a Map<String, dynamic>
            final name = createdBy[
                'name']; // Access the 'name' key from the created_by map

            final timestamp = (note['timestamp'] as Timestamp).toDate();

            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4.0,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MeetingNotesKanbanPage(
                        meetingId:
                            meetingId, // Pass the meetingId to the next page
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Created By : ${name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Saved on: ${timestamp.toLocal()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
