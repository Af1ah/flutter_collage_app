import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educaps/views/widgets/showtoast_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../widget_tree.dart';

class AuthServieses {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signin({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      ToastWidget(message: "Account created successfully");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WidgetTree()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "";
      if (e.code == "weak-password") {
        message = "The password is too weak";
      } else if (e.code == "email-already-in-use") {
        message = "An account already exists with this email";
      } else {
        message = "An error occurred: ${e.message}"; // Include error message
      }
      ToastWidget(message: message);
    } catch (e) {
      ToastWidget(
        message: "An unexpected error occurred: $e",
      ); // Handle other errors
    }
  }

  Future<void> register({
    required String name,
    required String admissionNo,
    required BuildContext context,
    required DateTime dob,
    required String email,
    required String password,
    required String cpassword,
  }) async {
    if (password != cpassword) {
      ToastWidget(message: "Passwords do not match");
      return;
    }
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      String uid =
          userCredential.user?.uid ?? "";

      if (uid.isNotEmpty) {
        // Store additional user info in Firestore
        await _firestore.collection('users').doc(uid).set({
          'name': name,
          'dob': dob,
          'userId': uid,
          'admissionNO': admissionNo,
          'email': email,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(), 
        });

        ToastWidget(message: "User registered successfully!");
      } else {
        ToastWidget(message: "Failed to get user ID.");
      }
      ToastWidget(message: "Account created successfully");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await Future.delayed(const Duration(seconds: 1));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WidgetTree()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "";
      if (e.code == "weak-password") {
        message = "The password is too weak";
      } else if (e.code == "email-already-in-use") {
        message = "An account already exists with this email";
      } else {
        message = "An error occurred: ${e.message}"; // Include error message
      }
      ToastWidget(message: message);
    } catch (e) {
      ToastWidget(
        message: "An unexpected error occurred: $e",
      ); // Handle other errors
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    String uid =
        _auth.currentUser?.uid ?? ""; // Get current user ID, handle null

    if (uid.isEmpty) return null;

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      ToastWidget(message: "Error fetching user data: $e"); // Log error
      return null;
    }
  }
}
