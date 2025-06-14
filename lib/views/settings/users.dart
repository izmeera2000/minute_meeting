import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:minute_meeting/config/notification.dart';
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
  String? seedName;
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

      seedName = doc['name'] ??
          'Unknown Seed'; // Default to 'Unknown Seed' if not found

      // Filter out the current user from the users list
      final filteredUsers = users.where((user) {
        if (user['uid'] == _currentUser?.uid) {
          setState(() {
            currentUserRole = user['role'] ??
                ''; // Default to an empty string if role is not found
          });
          return false; // Skip the current user
        }
        return true; // Keep all other users
      }).toList();

      // Update state without the current user
      setState(() {
        seedUsers =
            filteredUsers; // Save the filtered seed users for UI display
      });
    } catch (e) {
      print("Error fetching users from seed: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _inviteUserByEmail(String email, String role) async {
    if (widget.seedId == null || email.isEmpty) return;

    try {
      final seedRef = _firestore.collection('seeds').doc(widget.seedId);
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

      // Fetch the user's FCM token
      final userDoc = await _firestore.collection('users').doc(uidToAdd).get();
      final fcmToken = userDoc.data()?['fcmToken'];

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Send the push notification if the token exists
        await sendNotificationToFCM(
          fcmToken,
          "You've been invited",
          '${seedName}', // Replace this with the actual group name or dynamic data
          'site11', // Site name or dynamic info, replace as needed
          route: '/managegroup',
        );

        String botToken =
            '7833413502:AAFDP4OLzJIZuJU_Rm2a5ueaNtTSXHsf-I0'; // Replace with your Bot Token
        String groupChatId = '-4798645160'; // Replace with your Chat ID
        String message = "You've been invited to ${seedName} ";
        await sendTelegramGroupMessage(botToken, groupChatId, message);
      } else {
        print("No FCM token for user with email $email");
      }

      await _fetchSeedUsers(widget.seedId!);

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

// Function to kick the user (remove from seed)
  void _kickUser(Map<String, dynamic> user) async {
    try {
      // Get the seed document first
      final seedDoc = await FirebaseFirestore.instance
          .collection('seeds')
          .doc(widget.seedId)
          .get();

      if (seedDoc.exists) {
        final seedData = seedDoc.data();
        final users = List<Map<String, dynamic>>.from(seedData?['users'] ?? []);

        // Check if the user exists in the users array
        bool userFound = false;
        for (var seedUser in users) {
          if (seedUser['uid'] == user['uid']) {
            userFound = true;
            break;
          }
        }

        if (userFound) {
          // If the user is found, proceed to remove them
          await FirebaseFirestore.instance
              .collection('seeds')
              .doc(widget.seedId)
              .update({
            'users': FieldValue.arrayRemove([user]), // Remove the exact user
          });

          // Also update the user's seed array in the users collection
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user['uid'])
              .update({
            'seeds': FieldValue.arrayRemove([
              {
                'seed': widget.seedId, // remove this seed from user's seeds
              }
            ]),
          });

          print('User kicked');
          _fetchSeedUsers(widget.seedId);
        } else {
          print("User not found in this seed.");
        }
      } else {
        print("Seed document does not exist.");
      }
    } catch (error) {
      print("Error kicking user: $error");
    }
  }

// Function to change the user's role (in seed and users collection)
  void _changeUserRole(Map<String, dynamic> user) async {
    String newRole = user['role'] == 'admin' ? 'user' : 'admin'; // Toggle role

    try {
      // First, remove the user from the seed's users array
      await FirebaseFirestore.instance
          .collection('seeds')
          .doc(widget.seedId)
          .update({
        'users': FieldValue.arrayRemove([user]), // Remove the old user
      });

      // Then, add the user back with the new role in the seed document
      await FirebaseFirestore.instance
          .collection('seeds')
          .doc(widget.seedId)
          .update({
        'users': FieldValue.arrayUnion([
          {
            ...user,
            'role': newRole, // Update the role to newRole
          }
        ]),
      });

      // Also update the user's seed array in the users collection (with updated role)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .update({
        'seeds': FieldValue.arrayRemove([
          {
            'seed': widget.seedId,
          }
        ]), // Remove the old seed entry from the user
      });

      // Re-add the updated seed information for the user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .update({
        'seeds': FieldValue.arrayUnion([
          {
            'seed': widget.seedId,
            'role': newRole, // Updated role in user document
            'status': user['status'], // Assuming status stays the same
          }
        ]),
      });

      _fetchSeedUsers(widget.seedId);

      print('User role changed to $newRole');
    } catch (error) {
      print("Error changing user role: $error");
    }
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
          labelText: 'Select Group',
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
