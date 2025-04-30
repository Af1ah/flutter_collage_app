import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educaps/views/widgets/showtoast_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference assignmentCollection = FirebaseFirestore.instance
      .collection('assignments');

  Future<void> uploadAssignment(String question) async {
    try {
     
    } catch (e) {
      ToastWidget(message: "Error uploading assignment: $e");
    }
  }

  Future<void> deleteAssignment(String docId) async {
    try {
      await assignmentCollection.doc(docId).delete();
    } catch (e) {
      ToastWidget(message: "Error deleting assignment: $e");
    }
  }

  // Update assignment
  Future<void> updateAssignment(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      await assignmentCollection.doc(docId).update(updatedData);
    } catch (e) {
      ToastWidget(message: "Error updating assignment: $e");
    }
  }

  Future<String?> getUserRole() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          return userDoc['role']; // Return "teacher" or "student"
        }
      }
      return null; // If user not found
    } catch (e) {
      ToastWidget(message: "Error getting user role: $e");
      return null;
    }
  }

  // Get user id
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}
