import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educaps/views/pages/assignment/assignmentview_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Assignment Detail Page
class AssignmentDetailPage extends StatefulWidget {
  final AssignmentModel assignment;

  const AssignmentDetailPage({Key? key, required this.assignment})
    : super(key: key);

  @override
  State<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends State<AssignmentDetailPage> {
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkSubmissionStatus();
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user ID
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Fetch user data
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _checkSubmissionStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('assignments') // Parent collection
              .doc(widget.assignment.id) // Assignment document ID
              .collection('submissions') // Sub-collection
              .where('userId', isEqualTo: uid) // Filter by user ID
              .get();

      setState(() {
        _hasSubmitted = snapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking submission status: $e');
    }
  }

  Future<void> _uploadSubmission() async {
    if (_userData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User data not available')));
      return;
    }
    String status = "Pending";

    setState(() {
      _isSubmitting = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final fileName = result.files.single.name;
        final File fileToUpload = File(path);
        final String assignmentId = widget.assignment.id;
        final String uid = FirebaseAuth.instance.currentUser!.uid;

        String fileType = _getFileType(fileName);

        // Show upload progress
        final uploadTask = Supabase.instance.client.storage
            .from('assignments')
            .upload('$assignmentId/$uid/$fileName', fileToUpload);

        await uploadTask;

        // Get the file URL
        final String fileUrl = Supabase.instance.client.storage
            .from('assignments')
            .getPublicUrl('$assignmentId/$uid/$fileName');

        final submissionData = {
          'assignmentId': assignmentId,
          'userId': uid,
          'studentName': _userData!['name'] ?? 'Unknown',
          'admissionNO': _userData!['admissionNO'] ?? 'Unknown',
          'filePath': fileUrl,
          'fileName': fileName,
          'fileType': fileType,
          'fileSize': fileToUpload.lengthSync(),
          'submittedAt': Timestamp.now(),
          'status': status,
        };

        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(assignmentId)
            .collection('submissions')
            .doc(uid)
            .set(submissionData);

        setState(() {
          _hasSubmitted = true;
        });

        _showSubmissionSuccess(fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _getFileType(String fileName) {
    final String fileExtension = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      return 'image';
    } else if (fileExtension == 'pdf') {
      return 'pdf';
    } else if (['doc', 'docx'].contains(fileExtension)) {
      return 'document';
    } else {
      return 'other';
    }
  }

  void _showSubmissionSuccess(String fileName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Submission Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                Text('File: $fileName'),
                const SizedBox(height: 8),
                Text('Admission No: ${_userData?['admissionNO'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text(
                  'Time: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
                ),
                Text('status: Pending'),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize a QuillController if questionDelta exists
    quill.QuillController? quillController;
    if (widget.assignment.questionDelta != null) {
      try {
        final document = quill.Document.fromJson(
          widget.assignment.questionDelta!,
        );
        quillController = quill.QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // Fallback to plain text if delta cannot be parsed
        print('Error parsing delta: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.assignment.title), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment metadata card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.subject, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          widget.assignment.subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Due: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.assignment.dueDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Due Time: ${DateFormat('h:mm a').format(widget.assignment.dueDate)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Assignment question section
            const Text(
              'Assignment Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    quillController != null
                        ? quill.QuillEditor.basic(controller: quillController)
                        : Text(widget.assignment.question),
              ),
            ),

            const SizedBox(height: 24),

            // Submission section

            // Replace the submission section in your build method with this
            // Submission section
            if (!_hasSubmitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon:
                      _isSubmitting
                          ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                          : const Icon(Icons.upload_file),
                  label: Text(
                    _isSubmitting ? 'Uploading...' : 'Submit Assignment',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _uploadSubmission,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assignment Submitted',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted by: ${_userData?['name'] ?? "Unknown"}',
                            style: TextStyle(color: Colors.green[800]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
