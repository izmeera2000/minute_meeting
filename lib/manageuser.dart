import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class UserManagementPage extends StatefulWidget {
  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _dbRef = FirebaseDatabase.instance.ref().child('users');
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final loaded = data.entries
          .map((entry) => {
        'key': entry.key,
        'email': entry.value['email'] ?? '',
        'ic': entry.value['ic'] ?? '',
        'name': entry.value['name'] ?? '',
      })
          .toList();
      setState(() {
        _users = loaded;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _deleteUser(String key) async {
    try {
      final snapshot = await _dbRef.child(key).get();
      final email = snapshot.child('email').value?.toString();
      final ic = snapshot.child('ic').value?.toString();
      if (email != null && ic != null) {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          final user = (await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: ic,
          ))
              .user;
          await user?.delete();
        }
      }
    } catch (e) {
      print('Auth deletion skipped or failed: $e');
    }

    await _dbRef.child(key).remove();
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("User Management"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(child: Text("No users added yet."))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (_, index) {
          final user = _users[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text(user['email'], style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Name: ${user['name']}", style: TextStyle(color: Colors.black87)),
                  Text("IC: ${user['ic']}", style: TextStyle(color: Colors.black87)),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteUser(user['key']),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddUserPage(onUserAdded: _fetchUsers)),
        ),
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddUserPage extends StatefulWidget {
  final VoidCallback onUserAdded;
  const AddUserPage({super.key, required this.onUserAdded});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _emailController = TextEditingController();
  final _icController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authResult = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _icController.text.trim(),
      );

      final uid = authResult.user?.uid;
      if (uid != null) {
        // 🔥 Get FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print("📦 User FCM Token: $fcmToken");

        await FirebaseDatabase.instance.ref('users/$uid').set({
          'email': _emailController.text.trim(),
          'ic': _icController.text.trim(),
          'name': _nameController.text.trim(),
          'fcmToken': fcmToken, // ✅ Save token to database
        });
      }

      widget.onUserAdded();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add User"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter full name',
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter email',
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Email is required' : null,
                ),
                const SizedBox(height: 20),
                const Text("IC Number (used as password)", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _icController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter IC number',
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'IC is required' : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _addUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Save User"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
