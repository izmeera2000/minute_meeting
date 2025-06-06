import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minute_meeting/models/seed.dart';
import 'package:minute_meeting/models/user.dart';
import 'package:minute_meeting/views/settings/seedmanagepage.dart';
import 'package:uuid/uuid.dart';

class ManageSeed extends StatefulWidget {
  @override
  _ManageSeedState createState() => _ManageSeedState();
}

class _ManageSeedState extends State<ManageSeed> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Seed> _seeds = []; // Use Seed model here
  bool _isLoading = true;
  UserModel? _currentUser;

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
    _fetchSeeds();
  }

  void _fetchSeeds() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore.collection('seeds').get();

      final matchedSeeds = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final users = List<Map<String, dynamic>>.from(data['users'] ?? []);

            final userEntry = users.firstWhere(
              (user) {
                final uid = user['uid']?.toString();
                final email = user['email']?.toString()?.toLowerCase();
                return uid == _currentUser!.uid ||
                    email == _currentUser!.email?.toLowerCase();
              },
              orElse: () => {},
            );

            if (userEntry.isEmpty) return null;

            final status = userEntry['status']?.toString() ?? 'accepted';
            final role = userEntry['role']?.toString() ?? 'member';

            // ✅ Debug print
            print("Seed: ${data['name']}, Role: $role, Status: $status");

            // ✅ If needed, you can extend the Seed model to hold `currentUserRole`
            final seed = Seed.fromMap(doc.id, data, status: status);

            return seed;
          })
          .whereType<Seed>()
          .toList();
 
      setState(() {
        _seeds = matchedSeeds;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching seeds: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

 
  String _generateSeed() => Uuid().v4();

  void _addOrUpdateSeed({String? existingSeedId}) async {
    String? seedName;

    if (existingSeedId != null) {
      final seedDoc =
          await _firestore.collection('seeds').doc(existingSeedId).get();
      if (seedDoc.exists) {
        seedName = seedDoc['name'] ?? '';
      }
    }

    final TextEditingController _controller =
        TextEditingController(text: seedName ?? '');
    Timestamp now = Timestamp.now();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existingSeedId == null ? 'Add New Seed' : 'Update Seed'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: "Seed Title"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = _controller.text.trim();
              if (title.isEmpty) return;

              try {
                if (existingSeedId == null) {
                  final newSeedId = _generateSeed();
                  DateTime createdAt = DateTime.now();
                  // Create seed doc with admin user
                  await _firestore.collection('seeds').doc(newSeedId).set({
                    'name': title,
                    'created_at': createdAt,
                    'users': [
                      {
                        'uid': _currentUser!.uid,
                        'role': 'admin',
                        'status': 'accepted',
                        'email': _currentUser!.email,
                        'updated_at': now,
                      }
                    ],
                  });

// Add seed to user's seeds array
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({
                    'seeds': FieldValue.arrayUnion([
                      {
                        'seed': newSeedId,
                        'name': title,
                        'role': 'admin',
                        'status': 'accepted'
                      }
                    ]),
                  });

                  setState(() {
                    _seeds.add(Seed(
                      seedId: newSeedId,
                      name: title,
                      role: 'admin', // Include the role
                      users: [],
                      createdAt: createdAt,
                    ));
                  });
                } else {
                  // Update existing seed's name
                  await _firestore
                      .collection('seeds')
                      .doc(existingSeedId)
                      .update({'name': title});

                  setState(() {
                    final index =
                        _seeds.indexWhere((s) => s.seedId == existingSeedId);
                    if (index != -1)
                      _seeds[index] = Seed(
                          seedId: existingSeedId,
                          name: title,
                          users: _seeds[index].users);
                  });
                }

                Navigator.pop(dialogContext);
              } catch (e) {
                print("Error saving seed: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Failed to save seed'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteSeed(String seedId) async {
    if (_currentUser?.uid == null) return;

    try {
      final doc = await _firestore.collection('seeds').doc(seedId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final users = List<Map<String, dynamic>>.from(data['users'] ?? []);

      // Find current user in seed users
      final currentUserEntry = users.firstWhere(
        (u) => u['uid'] == _currentUser!.uid,
        orElse: () => {},
      );

      if (currentUserEntry.isEmpty) return;

      final role = currentUserEntry['role'];
      final isAdmin = role == 'admin';
      final isLastUser = users.length <= 1;

      if (isLastUser) {
        // ✅ Delete the seed document

        if (!isAdmin) {
          await _firestore.collection('seeds').doc(seedId).delete();
        }
        // ✅ Remove from all user profiles
        final userSnapshots = await _firestore.collection('users').get();
        print('Fetched ${userSnapshots.docs.length} user documents.');

        for (var userDoc in userSnapshots.docs) {
          print('Processing user: ${userDoc.id}');

          // Get the current list of seeds from the document
          var userSeeds = userDoc['seeds'];
          print('Current seeds in user document: $userSeeds');

          // Find the seed object to remove
          var seedToRemove = userSeeds.firstWhere(
            (seed) => seed['seed'] == seedId,
            orElse: () => null, // Return null if not found
          );

          if (seedToRemove != null) {
            print('Found seed to remove: $seedToRemove');

            // Remove the seed object by matching it fully
            await _firestore.collection('users').doc(userDoc.id).update({
              'seeds': FieldValue.arrayRemove([seedToRemove]),
            });

            print('Removed seed from user: ${userDoc.id}');
          } else {
            print('No seed with ID $seedId found in user ${userDoc.id}');
          }
        }
      } else {
        // ✅ Remove this user from users array in the seed
        // Step 1: Remove from the users' "seeds" field
        try {
          // Step 1: Fetch the current 'users' array
          DocumentSnapshot seedDoc =
              await _firestore.collection('seeds').doc(seedId).get();

          if (seedDoc.exists) {
            var users = List<Map<String, dynamic>>.from(seedDoc['users'] ?? []);

            // Step 2: Filter out the user by UID
            users.removeWhere((user) => user['uid'] == _currentUser!.uid);

            // Step 3: Update the 'users' array without the removed user
            await _firestore
                .collection('seeds')
                .doc(seedId)
                .update({'users': users});

            print(
                'Seed $seedId successfully updated in seeds collection (removed user).');
          } else {
            print('Seed document not found');
          }
        } catch (e) {
          print('Error updating seed $seedId in seeds collection: $e');
        }
// Step 2: Fetch the user's document
        final userDoc =
            await _firestore.collection('users').doc(_currentUser!.uid).get();

// Debugging: Print the current seeds array from Firestore
        print(
            'Current seeds for user ${_currentUser!.uid}: ${userDoc['seeds']}');

// Step 3: Safely convert the seeds field to a List of Maps
        final seedEntries =
            List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);
        print('Seed entries converted to List<Map>: $seedEntries');

// Step 4: Filter the seeds to exclude the one with the specified seedId
        final updatedSeeds =
            seedEntries.where((entry) => entry['seed'] != seedId).toList();
        print('Updated seeds after removal: $updatedSeeds');

// Step 5: Update the user's document with the new seeds list
        try {
          await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .update({'seeds': updatedSeeds});

          print(
              'User ${_currentUser!.uid} updated successfully with new seeds list.');
        } catch (e) {
          print('Error updating user\'s seeds: $e');
        }

// Step 6: Remove the seed from the 'seeds' collection
        try {
          await _firestore.collection('seeds').doc(seedId).update({
            'users': FieldValue.arrayRemove([
              {'uid': _currentUser!.uid}
            ])
          });

          print(
              'Seed $seedId successfully updated in seeds collection (removed user).');
        } catch (e) {
          print('Error updating seed $seedId in seeds collection: $e');
        }
      }

      // ✅ Update local state
      setState(() {
        _seeds.removeWhere((s) => s.seedId == seedId);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Seed deleted or left successfully."),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Error deleting seed: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete seed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _acceptSeedInvitation(Seed seed) async {
    try {
      final seedRef = _firestore.collection('seeds').doc(seed.seedId);
      final userRef = _firestore.collection('users').doc(_currentUser!.uid);

      // Update status to 'accepted' in the seed's users array
      final seedDoc = await seedRef.get();
      List<Map<String, dynamic>> users =
          List<Map<String, dynamic>>.from(seedDoc['users'] ?? []);

      for (var user in users) {
        if (user['uid'] == _currentUser!.uid ||
            user['email'] == _currentUser!.email?.toLowerCase()) {
          user['status'] = 'accepted';
        }
      }

      await seedRef.update({'users': users});

      // Add this seed to the user's seeds array
      await userRef.update({
        'seeds': FieldValue.arrayUnion([
          {
            'seed': seed.seedId,
            'name': seed.name,
            'role': 'member',
            'status': 'accepted',
          }
        ])
      });

      // Refresh
      _fetchSeeds();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("You have joined '${seed.name}'"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      print("Error accepting seed invitation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to accept invitation."),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Groups"),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _seeds.isEmpty
              ? Center(child: Text("No groups available."))
              : ListView.builder(
                  itemCount: _seeds.length,
                  itemBuilder: (_, index) {
    final seed = _seeds.reversed.toList()[index];  // Reverse the list before accessing the item
                    print(seed);
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: seed.status == 'pending' ? Colors.grey[100] : null,
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text('Name: ${seed.name}')),
                            if (seed.status == 'pending')
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pending',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text('Seed: ${seed.seedId}'),
                        trailing: seed.status == 'pending'
                            ? null // no buttons for pending seeds
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (seed.getRoleForUser(_currentUser!.uid) ==
                                      'admin')
                                    IconButton(
                                      icon:
                                          Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _addOrUpdateSeed(
                                        existingSeedId: seed.seedId,
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteSeed(seed.seedId),
                                  ),
                                ],
                              ),
                        onTap: () {
                          if (seed.status == 'pending') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Seed Invitation'),
                                content: Text(
                                    'Do you want to accept the invitation to join "${seed.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context), // Decline
                                    child: Text('Decline'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // Close dialog
                                      await _acceptSeedInvitation(seed);
                                    },
                                    child: Text('Accept'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TopNavigationPage(seedId:seed.seedId)),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => _addOrUpdateSeed(),
        child: Icon(Icons.add),
      ),
    );
  }
}
