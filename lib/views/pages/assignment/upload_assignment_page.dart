import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Define the Assignment class (ensure this matches your AssignmentPage)
class Assignment {
  final String id;
  final String title;
  final String question;
  final DateTime dueDate;
  final String subject;
  final dynamic questionDelta; // Store the Delta JSON

  Assignment({
    required this.id,
    required this.title,
    required this.question,
    required this.dueDate,
    required this.subject,
    required this.questionDelta,
  });

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      title: data['title'] ?? '',
      question: data['question'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      subject: data['subject'] ?? '',
      questionDelta: data['questionDelta'] ?? [],
    );
  }
}

class UploadAssignmentPage extends StatefulWidget {
  final Assignment? assignment;
  const UploadAssignmentPage({super.key, this.assignment});

  @override
  State<UploadAssignmentPage> createState() => _UploadAssignmentPageState();
}

class _UploadAssignmentPageState extends State<UploadAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final QuillController _quillController = QuillController.basic();
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      _titleController.text = widget.assignment!.title;
      _subjectController.text = widget.assignment!.subject;
      _dueDate = widget.assignment!.dueDate;
      try {
        // Ensure questionDelta is valid and load it into the QuillController
        if (widget.assignment!.questionDelta != null &&
            widget.assignment!.questionDelta is List) {
          _quillController.document = Document.fromJson(
            widget.assignment!.questionDelta,
          );
        }
      } catch (e) {
        // If there's an error loading the Delta, initialize with plain text
        _quillController.document =
            Document()..insert(0, widget.assignment!.question);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assignment content: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String get _formattedDate {
    if (_dueDate == null) {
      return 'Select Due Date & Time';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!);
  }

  void _clearForm() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Form?'),
            content: const Text('Are you sure you want to clear the form?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _titleController.clear();
                  _subjectController.clear();
                  _quillController.clear();
                  setState(() {
                    _dueDate = null;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  Future<void> _uploadAssignment() async {
    if (!_formKey.currentState!.validate() || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a due date.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'title': _titleController.text,
        'subject': _subjectController.text,
        'dueDate': Timestamp.fromDate(_dueDate!),
        'question': _quillController.document.toPlainText(),
        'questionDelta': _quillController.document.toDelta().toJson(),
        'createdAt': Timestamp.now(),
      };

      if (widget.assignment != null) {
        // Update existing assignment
        await FirebaseFirestore.instance
            .collection('assignments')
            .doc(widget.assignment!.id)
            .update(data);
      } else {
        // Add new assignment
        await FirebaseFirestore.instance.collection('assignments').add(data);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment saved successfully!')),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save assignment: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignment != null ? 'Edit Assignment' : 'Upload Assignment',
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Stack(
        children: [
          _buildForm(context),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _uploadAssignment,
        label: const Text('Upload'),
        icon: const Icon(Icons.cloud_upload),
        backgroundColor:
            _isLoading ? Colors.grey : Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildTextField(
              controller: _titleController,
              label: 'Title',
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? 'Please enter a title'
                          : null,
            ),
            const SizedBox(height: 16),
            _buildDatePicker(context),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _subjectController,
              label: 'Subject',
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? 'Please enter a subject'
                          : null,
            ),
            const SizedBox(height: 20),
            _buildQuillToolbar(),
            const SizedBox(height: 10),
            _buildQuillEditor(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
       
      ),
      validator: validator,
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () => _selectDateTime(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Due Date & Time',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(_formattedDate),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildQuillToolbar() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: QuillSimpleToolbar(controller: _quillController),
      ),
    );
  }

  Widget _buildQuillEditor() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: QuillEditor(
          controller: _quillController,
          scrollController: ScrollController(),
          focusNode: FocusNode(),
          config: const QuillEditorConfig(
            placeholder: 'Enter your assignment question here...',
            padding: EdgeInsets.all(8.0),
          ),
        ),
      ),
    );
  }
}
