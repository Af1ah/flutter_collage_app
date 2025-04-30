import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'package:educaps/views/pages/login/welcome_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../services/theme_provider_class.dart'; // Theme provider class

class ProfileDetails extends StatefulWidget {
  const ProfileDetails({super.key});

  @override
  State<ProfileDetails> createState() => _ProfileDetailsState();
}

class _ProfileDetailsState extends State<ProfileDetails> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? userData; // Cached user data
  bool isLoading = true;
  bool _isImageUploading = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      auth.User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        } else {
          // Handle case where document doesn't exist
          _showErrorSnackBar('User profile not found');
        }
      } else {
        // Handle case where user is not logged in
        _navigateToLogin();
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePage()),
    );
  }

  Future<void> uploadProfileImage() async {
    try {
      setState(() {
        _isImageUploading = true;
      });

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _isImageUploading = false;
        });
        return;
      }

      final File imageFile = File(pickedFile.path);
      final String userId = _auth.currentUser!.uid;
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      final String filePath = 'users/$userId/profile/$fileName';

      // Upload to Supabase - using try/catch for error handling
      try {
        // Modern Supabase SDK usage
        await Supabase.instance.client.storage
            .from('profiles')
            .upload(filePath, imageFile);

        // Get public URL
        final imageUrl = Supabase.instance.client.storage
            .from('profiles')
            .getPublicUrl(filePath);

        // Update Firestore with new image URL
        await _firestore.collection('users').doc(userId).update({
          'photoURL': imageUrl,
        });

        setState(() {
          userData!['photoURL'] = imageUrl;
          _isImageUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        _showErrorSnackBar('Upload error: $e');
        setState(() {
          _isImageUploading = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading image: $e');
      setState(() {
        _isImageUploading = false;
      });
    }
  }

  void _resetPassword() async {
    try {
      final emailController = TextEditingController(
        text: userData?['email'] ?? '',
      );

      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'We will send a password reset link to your email:',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _auth.sendPasswordResetEmail(
                        email: emailController.text.trim(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent'),
                        ),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      _showErrorSnackBar('Error: $e');
                    }
                  },
                  child: const Text('SEND RESET LINK'),
                ),
              ],
            ),
      );
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Profile Image with Upload Functionality
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          userData!['photoURL'] != null
                              ? NetworkImage(userData!['photoURL'])
                                  as ImageProvider
                              : const AssetImage(
                                "assets/images/default_user.jpg",
                              ),
                    ),
                  ),
                  if (_isImageUploading) const CircularProgressIndicator(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _isImageUploading ? null : uploadProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // User Name
              Text(
                userData!['name'] ?? "Full Name Not Set",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                userData!['email'] ?? "",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),

              const SizedBox(height: 32),

              // User Details Card
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                        child: Text(
                          "Account Details",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _buildDetailRow(
                        Icons.badge,
                        "Admission No",
                        userData!['admissionNO'] ?? "Not Set",
                      ),
                      _buildDetailRow(
                        Icons.calendar_today,
                        "Date of Birth",
                        _formatDate(userData!['dob']),
                      ),
                      _buildDetailRow(
                        Icons.date_range,
                        "Joined On",
                        _formatDate(userData!['createdAt']),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _resetPassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text("Reset Password"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setBool('isLoggedIn', false);
                        await _auth.signOut();
                        _navigateToLogin();
                      } catch (e) {
                        _showErrorSnackBar('Error signing out: $e');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Logout"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "Not Available";
    try {
      return DateFormat(
        'MMMM d, yyyy',
      ).format((timestamp as Timestamp).toDate());
    } catch (e) {
      return "Invalid Date";
    }
  }

  void _editProfile(BuildContext context) {
    final nameController = TextEditingController(text: userData!['name']);
    final emailController = TextEditingController(text: userData!['email']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit Profile",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCEL"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          () => _updateUserProfile(
                            nameController.text.trim(),
                            emailController.text.trim(),
                            context,
                          ),
                      child: const Text("SAVE"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  Future<void> _updateUserProfile(
    String name,
    String email,
    BuildContext context,
  ) async {
    try {
      if (name.isEmpty || email.isEmpty) {
        _showErrorSnackBar('Name and email cannot be empty');
        return;
      }

      final String userId = _auth.currentUser!.uid;

      // Show loading indicator
      setState(() {
        isLoading = true;
      });

      // Update authentication email if it changed
      if (email != userData!['email']) {
        await _auth.currentUser!.updateEmail(email);
      }

      // Update Firestore data
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'email': email,
        'updatedAt': Timestamp.now(),
      });

      // Update local state
      setState(() {
        userData!['name'] = name;
        userData!['email'] = email;
        isLoading = false;
      });

      // Close the bottom sheet
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error updating profile: $e');
    }
  }
}
