import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educaps/views/pages/assignment/upload_assignment_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'assignment_submitview_page.dart';

class Assignment {
  final String id; // Firestore document ID
  final String title;
  final String question;
  final DateTime dueDate;
  final String subject;

  Assignment({
    required this.id,
    required this.title,
    required this.question,
    required this.dueDate,
    required this.subject,
  });

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    dynamic dueDateData = data['dueDate'];

    // Handle the dueDate field based on its type
    DateTime dueDate;
    if (dueDateData is Timestamp) {
      dueDate = dueDateData.toDate();
    } else if (dueDateData is String) {
      try {
        // Parse the string to DateTime if it's in a valid format
        dueDate = DateTime.parse(dueDateData);
      } catch (e) {
        // If parsing fails, use a fallback (e.g., current date) or throw an error
        dueDate = DateTime.now();
        debugPrint(
          'Error parsing dueDate string: $e. Using current date as fallback.',
        );
      }
    } else {
      // If dueDate is null or an unsupported type, use a fallback
      dueDate = DateTime.now();
      debugPrint(
        'dueDate is null or unsupported type. Using current date as fallback.',
      );
    }

    return Assignment(
      id: doc.id,
      title: data['title'] ?? '',
      question: data['question'] ?? '',
      dueDate: dueDate,
      subject: data['subject'] ?? '',
    );
  }
}

class AssignmentPage extends StatefulWidget {
  const AssignmentPage({super.key});

  @override
  State<AssignmentPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<AssignmentPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('assignments').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching assignments'));
          }

          final assignments =
              snapshot.data?.docs
                  .map((doc) => Assignment.fromFirestore(doc))
                  .toList() ??
              [];

          if (assignments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No assignments available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              var assignment = assignments[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    assignment.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Subject: ${assignment.subject}"),
                      Text(
                        "Due: ${DateFormat('dd/MM/yyyy HH:mm').format(assignment.dueDate)}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.assignment),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignmentSubmitviewPage(
                          assignmentId: assignment.id,
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _showEditDeleteDialog(context, assignment),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UploadAssignmentPage(),
            ),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDeleteDialog(BuildContext context, Assignment assignment) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(assignment.title),
            content: const Text('Choose an action:'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editAssignment(context, assignment);
                },
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAssignment(context, assignment);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _editAssignment(BuildContext context, Assignment assignment) {
    // Navigate to the upload page with pre-filled data for editing
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UploadAssignmentPage()),
    );
  }

  void _deleteAssignment(BuildContext context, Assignment assignment) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Assignment'),
            content: const Text(
              'Are you sure you want to delete this assignment?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('assignments')
                        .doc(assignment.id)
                        .delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assignment deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete assignment: $e'),
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
