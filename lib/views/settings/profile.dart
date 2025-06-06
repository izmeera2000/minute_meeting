import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:minute_meeting/models/user.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _icController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
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

      _nameController.text = _currentUser?.name ?? ''; // Updated to set text
      _emailController.text = _currentUser?.email ?? ''; // Updated to set text
    });
  }

  Future<void> _updateProfile() async {
    // Validate the form inputs before proceeding
    if (!_formKey.currentState!.validate()) return;

    // Indicate the form is in the process of saving
    setState(() => _isSaving = true);

    try {
      final uid = _currentUser?.uid;

      // If the user is logged in, proceed with the update
      if (uid != null) {
        // Reference to the user document in Firestore
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

        // Update the basic user info (name in this case)
        await userRef.update({
          'name': _nameController.text.trim(),
        });

        // Only update password if it's provided and confirmed
        if (_passwordController.text.isNotEmpty) {
          // Check if the password and confirmation password match
          if (_passwordController.text != _confirmPasswordController.text) {
            throw FirebaseAuthException(
              code: 'password-mismatch',
              message: 'Passwords do not match',
            );
          }

          // Reauthenticate the user with the current password
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email;
          final currentPassword = _currentPasswordController.text
              .trim(); // Current password from user input

          if (email == null) {
            throw FirebaseAuthException(
              code: 'no-email',
              message: 'No email found for the user.',
            );
          }

          // Create a credential for reauthentication using email and current password
          final credential = EmailAuthProvider.credential(
            email: email,
            password: currentPassword,
          );

          // Reauthenticate the user
          await user?.reauthenticateWithCredential(credential);

          // Now update the password
          await user?.updatePassword(_passwordController.text.trim());
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Profile updated successfully!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Show error message if something goes wrong
      String errorMessage = "Error: ${e.toString()}";
      if (e is FirebaseAuthException) {
        errorMessage = e.message ?? "An unknown error occurred";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      // Reset the saving state
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
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
              BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text("Email (read only)",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Text("Name",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter full name',
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  const Text("Current Password ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter new password',
                    ),
                    validator: (value) =>
                        value != null && value.isNotEmpty && value.length < 6
                            ? 'Min 6 characters'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  const Text("New Password ",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter new password',
                    ),
                    validator: (value) =>
                        value != null && value.isNotEmpty && value.length < 6
                            ? 'Min 6 characters'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  const Text("Confirm New Password",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Confirm new password',
                    ),
                    validator: (value) =>
                        value != null && value.isNotEmpty && value.length < 6
                            ? 'Min 6 characters'
                            : null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text("Update Profile"),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
