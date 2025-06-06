import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minute_meeting/models/seed.dart';
import 'package:minute_meeting/models/user.dart';

class ManageUsers extends StatefulWidget {
  final String seedId;

  ManageUsers({required this.seedId});

  @override
  _ManageUsersState createState() => _ManageUsersState();
}

class _ManageUsersState extends State<ManageUsers> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;

  List<Seed> userSeeds = [];
  String? selectedSeedId;
  List<Map<String, dynamic>> seedUsers = [];
  bool _isLoading = true;
  String? currentUserRole;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndSeeds();
  }

  Future<void> _loadUserAndSeeds() async {
    final user = await UserModel.loadFromPrefs();
    if (user == null) return;

    setState(() {
      _currentUser = user;
    });

    // try {
    //   final userDoc = await _firestore.collection('users').doc(user.uid).get();
    //   final seedsFromDoc =
    //       List<Map<String, dynamic>>.from(userDoc['seeds'] ?? []);

    //   final seeds = seedsFromDoc.map((seed) {
    //     return Seed(
    //       seedId: seed['seed'] ?? seed['seedId'],
    //       name: seed['name'] ?? '',
    //       users: [],
    //     );
    //   }).toList();

    //   setState(() {
    //     userSeeds = seeds;
    //     selectedSeedId = seeds.isNotEmpty ? seeds[0].seedId : null;
    //   });

    //   if (selectedSeedId != null) {
    await _fetchSeedUsers(widget.seedId);
    //   }
    // } catch (e) {
    //   print("Error loading seeds: $e");
    // } finally {
    //   setState(() {
    //     _isLoading = false;
    //   });
    // }
  }

  Future<void> _fetchSeedUsers(String seedId) async {
    setState(() {
      seedUsers = [];
      _isLoading = true;
    });

    try {
      // Fetch the seed document from Firestore
      final doc = await _firestore.collection('seeds').doc(seedId).get();
      final users = List<Map<String, dynamic>>.from(doc['users'] ?? []);

      // Check if the current user is in the 'users' array and their role
      bool isCurrentUserInSeed = false;
 
      for (var user in users) {
        if (user['uid'] == _currentUser?.uid) {
          setState(() {
            isCurrentUserInSeed = true;
            currentUserRole = user['role'] ??
                ''; // Default to an empty string if role is not found
          });

          break; // No need to continue once we find the current user
        }
      }

      // Optionally, you can store the role and user info in the state to use it later
      setState(() {
        seedUsers = users; // Save the seed users for UI display
      });

      // Debugging: Print if the user was found and their role
      // if (isCurrentUserInSeed) {
       // } else {
      //   print('Current user is NOT part of this seed');
      // }

      // If needed, you can perform further logic based on the role
      if (isCurrentUserInSeed && currentUserRole == 'admin') {
        // Example: Do something special if the user is an admin
        print('Current user is an admin in this seed.');
      }
    } catch (e) {
      print("Error fetching users from seed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteUserByEmail(String email, String role) async {
    if (selectedSeedId == null || email.isEmpty) return;

    try {
      final seedRef = _firestore.collection('seeds').doc(selectedSeedId);
      final doc = await seedRef.get();
      List<Map<String, dynamic>> users =
          List<Map<String, dynamic>>.from(doc['users'] ?? []);

      final alreadyInvited =
          users.any((u) => u['email'] == email.toLowerCase());
      if (alreadyInvited) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("User already invited."),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No user found"),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      String uidToAdd = query.docs.first.id;
      Timestamp now = Timestamp.now();

      users.add({
        'uid': uidToAdd,
        'email': email.toLowerCase(),
        'role': role,
        'status': 'pending',
        'invited_at': now,
        'updated_at': now,
      });

      await seedRef.update({'users': users});

      await _fetchSeedUsers(selectedSeedId!);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Invitation sent to $email"),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      print("Error inviting user: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to invite user."),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _showInviteUserDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'member';
    final List<String> roles = ['member', 'admin'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invite User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
                items: roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final email = emailController.text.trim();
                Navigator.of(context).pop();
                _inviteUserByEmail(email, selectedRole);
              },
              child: Text('Invite'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserList() {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (seedUsers.isEmpty) return Center(child: Text("No users in this seed."));

    return ListView.builder(
      itemCount: seedUsers.length,
      itemBuilder: (_, index) {
        final user = seedUsers[index];

        return Card(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            title: Text(
              user['email'],
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Role: ${user['role']} | Status: ${user['status']}",
              style: TextStyle(color: Colors.grey[700]),
            ),
            onTap: () {
              // Check if the current user is an admin
              if (currentUserRole == 'admin') {
                _showUserOptionsDialog(user);
              }
            },
          ),
        );
      },
    );
  }

// Function to kick the user (remove from the seed)
  void _kickUser(Map<String, dynamic> user) {
    // Remove the user from the seed's list of users
    FirebaseFirestore.instance.collection('seeds').doc(selectedSeedId).update({
      'users': FieldValue.arrayRemove([user]),
    }).then((_) {
      print('User kicked');
    }).catchError((error) {
      print("Error kicking user: $error");
    });
  }

// Function to change the user's role
  void _changeUserRole(Map<String, dynamic> user) {
    String newRole = user['role'] == 'admin'
        ? 'user'
        : 'admin'; // Toggle role between admin and user

    // Update role in Firestore (assuming you have a collection 'seeds' and 'users' in it)
    FirebaseFirestore.instance.collection('seeds').doc(selectedSeedId).update({
      'users': FieldValue.arrayRemove([user]),
    }).then((_) {
      FirebaseFirestore.instance
          .collection('seeds')
          .doc(selectedSeedId)
          .update({
        'users': FieldValue.arrayUnion([
          {
            ...user,
            'role': newRole, // Update role
          }
        ]),
      });
    });

    print('Role changed to $newRole');
  }

// Method to show the dialog for user actions (kick, change role)
  void _showUserOptionsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("User Options"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Option to change the role
              ListTile(
                leading: Icon(Icons.group),
                title: Text("Change Role"),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _changeUserRole(user); // Call function to change role
                },
              ),
              // Option to kick the user
              ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text("Kick User"),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _kickUser(user); // Call function to kick user
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInviteForm() {
    // Assuming you have a variable 'isAdmin' that indicates whether the user is an admin.
 

    if (currentUserRole == 'admin') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                _showInviteUserDialog();
              },
              child: Text("Invite"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox
          .shrink(); // Return an empty widget if the user is not an admin
    }
  }

  Widget _buildSeedDropdown() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Select Seed',
          border: OutlineInputBorder(),
        ),
        value: selectedSeedId,
        onChanged: (val) {
          if (val != null) {
            setState(() {
              selectedSeedId = val;
            });
            _fetchSeedUsers(val);
          }
        },
        items: userSeeds.map((seed) {
          return DropdownMenuItem<String>(
            value: seed.seedId,
            child: Text(seed.name),
          );
        }).toList(),
        isExpanded: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // _buildSeedDropdown(),
          _buildInviteForm(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }
}
