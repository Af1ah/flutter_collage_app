import 'package:educaps/views/pages/assignment/show_assignment.dart';
import 'package:firebase_cloud_firestore/firebase_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class AssignmentSubmitviewPage extends StatefulWidget {
  final String assignmentId;
  const AssignmentSubmitviewPage({super.key, required this.assignmentId});

  @override
  State<AssignmentSubmitviewPage> createState() =>
      _AssignmentSubmitviewPageState();
}

class _AssignmentSubmitviewPageState extends State<AssignmentSubmitviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Assignment')),
      body: buildSubmissionList(
        widget.assignmentId,
      ), // Removed Center and direct Column.
    );
  }
}

FutureBuilder<QuerySnapshot> buildSubmissionList(String assignmentId) {
  return FutureBuilder<QuerySnapshot>(
    future:
        FirebaseFirestore.instance
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .get(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator();
      }

      if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return const Text('No submissions yet.');
      }

      final submissions = snapshot.data!.docs;

      return ListView.builder(
        itemCount: submissions.length,
        itemBuilder: (context, index) {
          final submission = submissions[index].data() as Map<String, dynamic>;
          final studentName = submission['studentName'] as String? ?? 'Unknown';
          final admissionNo = submission['admissionNO'] as String? ?? 'Unknown';
          final fileName = submission['fileName'] as String? ?? 'No File Name';
          final filePath = submission['filePath'] as String? ?? 'no path found';

          return Card(
            child: ListTile(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PDFView(filePath: filePath),
                    ),
                  ),
              title: Text(studentName),
              subtitle: Text('Admission No: $admissionNo, File: $fileName'),
              // Add other relevant data or actions here
            ),
          );
        },
      );
    },
  );
}
