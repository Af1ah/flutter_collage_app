import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.title});
  final String title;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _attendanceMap = {};
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _subjects = [];
  String _selectedSubject = '';
  bool _isLoading = false;
  List<int> _pendingUpdates = [];
  int _currentStudentIndex = -1;
  bool _batchProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _loadAttendanceDates();
  }

  Future<void> _loadSubjects() async {
    try {
      final response = await supabase
          .from('subjects')
          .select('subject_id, subject_name')
          .order('subject_name');

      setState(() {
        _subjects = List<Map<String, dynamic>>.from(response);
        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects[0]['subject_name'];
        }
      });
    } catch (e) {
      _showErrorMessage('Failed to load subjects: $e');
    }
  }

  Future<void> _loadAttendanceDates() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('attendance')
          .select('date, status, student_id')
          .order('date');

      Map<DateTime, List<String>> attendanceMap = {};
      for (var record in response) {
        final date = DateTime.parse(record['date']);
        final dateWithoutTime = DateTime(date.year, date.month, date.day);
        if (!attendanceMap.containsKey(dateWithoutTime)) {
          attendanceMap[dateWithoutTime] = [];
        }
        attendanceMap[dateWithoutTime]!.add(record['student_id'].toString());
      }

      setState(() {
        _attendanceMap = attendanceMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Failed to load attendance data: $e');
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedDay == null) return;

    setState(() => _isLoading = true);
    try {
      // Get all students
      final studentsResponse = await supabase
          .from('students')
          .select('student_id, name, roll_number, department, batch_year')
          .order('roll_number');

      List<Map<String, dynamic>> students = List<Map<String, dynamic>>.from(
        studentsResponse,
      );

      // Get attendance for the selected day and subject
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
      final attendanceResponse = await supabase
          .from('attendance')
          .select('student_id, status')
          .eq('date', dateStr)
          .eq('subject', _selectedSubject);

      Map<int, String> attendanceMap = {};
      for (var record in attendanceResponse) {
        attendanceMap[record['student_id']] = record['status'];
      }

      // Merge attendance data with student data
      for (var student in students) {
        student['attendance_status'] =
            attendanceMap[student['student_id']] ?? 'Absent';
      }

      setState(() {
        _students = students;
        _isLoading = false;
        _pendingUpdates.clear();
        // Initialize pendingUpdates with all student IDs that don't have attendance marked
        for (int i = 0; i < _students.length; i++) {
          if (_students[i]['attendance_status'] == 'Absent') {
            _pendingUpdates.add(i);
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Failed to load student data: $e');
    }
  }

  Future<void> _updateAttendance(
    int studentId,
    String status, {
    bool showNextStudent = false,
  }) async {
    if (_selectedDay == null) return;

    // Only show loading indicator if we're not processing a batch
    if (!_batchProcessing) {
      setState(() => _isLoading = true);
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);

      // Check if attendance record exists
      final existingRecord =
          await supabase
              .from('attendance')
              .select()
              .eq('student_id', studentId)
              .eq('date', dateStr)
              .eq('subject', _selectedSubject)
              .maybeSingle();

      if (existingRecord != null) {
        // Update existing record
        await supabase
            .from('attendance')
            .update({'status': status})
            .eq('student_id', studentId)
            .eq('date', dateStr)
            .eq('subject', _selectedSubject);
      } else {
        // Insert new record
        await supabase.from('attendance').insert({
          'student_id': studentId,
          'date': dateStr,
          'status': status,
          'subject': _selectedSubject,
        });
      }

      // Update local state
      final updatedStudents =
          _students.map((student) {
            if (student['student_id'] == studentId) {
              return {...student, 'attendance_status': status};
            }
            return student;
          }).toList();

      setState(() {
        _students = updatedStudents;

        // Update the attendance map for the calendar
        final dateWithoutTime = DateTime(
          _selectedDay!.year,
          _selectedDay!.month,
          _selectedDay!.day,
        );
        if (!_attendanceMap.containsKey(dateWithoutTime)) {
          _attendanceMap[dateWithoutTime] = [];
        }
        if (!_attendanceMap[dateWithoutTime]!.contains(studentId.toString())) {
          _attendanceMap[dateWithoutTime]!.add(studentId.toString());
        }

        if (!_batchProcessing) {
          _isLoading = false;
        }
      });

      // If we're showing the next student in batch processing mode
      if (showNextStudent) {
        _processNextStudent();
      }
    } catch (e) {
      if (!_batchProcessing) {
        setState(() => _isLoading = false);
      }
      _showErrorMessage('Failed to update attendance: $e');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _startBatchProcessing() {
    if (_pendingUpdates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No students need attendance updates')),
      );
      return;
    }

    setState(() {
      _batchProcessing = true;
      _currentStudentIndex = 0;
    });

    _showStudentAttendanceDialog(_pendingUpdates[0]);
  }

  void _processNextStudent() {
    // Remove the student we just processed
    if (_currentStudentIndex >= 0 &&
        _currentStudentIndex < _pendingUpdates.length) {
      _pendingUpdates.removeAt(0);
    }

    // If there are more students to process
    if (_pendingUpdates.isNotEmpty) {
      _showStudentAttendanceDialog(_pendingUpdates[0]);
    } else {
      // We're done with batch processing
      setState(() {
        _batchProcessing = false;
        _currentStudentIndex = -1;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All attendance updates completed and saved!')),
      );
    }
  }

  void _showStudentAttendanceDialog(int studentIndex) {
    if (studentIndex < 0 || studentIndex >= _students.length) return;

    final student = _students[studentIndex];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Mark Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${student['name']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Roll: ${student['roll_number']}'),
              Text('Department: ${student['department']}'),
              Text('Batch: ${student['batch_year']}'),
              SizedBox(height: 20),
              Text('Current status: ${student['attendance_status']}'),
            ],
          ),
          actions: [
            // Present button
            ElevatedButton.icon(
              icon: Icon(Icons.check, color: Colors.white),
              label: Text('Present'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.of(context).pop();
                _updateAttendance(
                  student['student_id'],
                  'Present',
                  showNextStudent: true,
                );
              },
            ),
            // Late button
            ElevatedButton.icon(
              icon: Icon(Icons.schedule, color: Colors.white),
              label: Text('Late'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.of(context).pop();
                _updateAttendance(
                  student['student_id'],
                  'Late',
                  showNextStudent: true,
                );
              },
            ),
            // Absent button
            ElevatedButton.icon(
              icon: Icon(Icons.close, color: Colors.white),
              label: Text('Absent'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _updateAttendance(
                  student['student_id'],
                  'Absent',
                  showNextStudent: true,
                );
              },
            ),
            // Leave button
            ElevatedButton.icon(
              icon: Icon(Icons.holiday_village, color: Colors.white),
              label: Text('Leave'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                Navigator.of(context).pop();
                _updateAttendance(
                  student['student_id'],
                  'Leave',
                  showNextStudent: true,
                );
              },
            ),
            // Skip button (for batch processing)
            if (_batchProcessing)
              TextButton(
                child: Text('Skip'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _processNextStudent();
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Quick mark all button
          IconButton(
            icon: Icon(Icons.playlist_add_check),
            tooltip: 'Batch Mark Attendance',
            onPressed:
                (_selectedDay != null && !_isLoading)
                    ? _startBatchProcessing
                    : null,
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadAttendanceDates();
              if (_selectedDay != null) {
                _loadStudents();
              }
            },
          ),
        ],
      ),
      body:
          _isLoading && !_batchProcessing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildCalendar(),
                  if (_subjects.isNotEmpty) _buildSubjectDropdown(),
                  if (_selectedDay != null)
                    Expanded(child: _buildStudentList()),
                ],
              ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) {
        return isSameDay(_selectedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _loadStudents();
      },
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final dateWithoutTime = DateTime(date.year, date.month, date.day);
          if (_attendanceMap.containsKey(dateWithoutTime) &&
              _attendanceMap[dateWithoutTime]!.isNotEmpty) {
            return Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                width: 8,
                height: 8,
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<String>(
        value: _selectedSubject,
        hint: Text('Select Subject'),
        isExpanded: true,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedSubject = newValue;
            });
            _loadStudents();
          }
        },
        items:
            _subjects.map<DropdownMenuItem<String>>((subject) {
              return DropdownMenuItem<String>(
                value: subject['subject_name'],
                child: Text(subject['subject_name']),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildStudentList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Attendance for ${DateFormat('yyyy-MM-dd').format(_selectedDay!)} - $_selectedSubject',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (_batchProcessing)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Processing: ${_pendingUpdates.length} remaining',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _students.length,
            itemBuilder: (context, index) {
              final student = _students[index];
              final statusColor = _getStatusColor(student['attendance_status']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Text(
                      student['name'][0],
                      style: TextStyle(color: statusColor),
                    ),
                  ),
                  title: Text(student['name']),
                  subtitle: Text(
                    'Roll: ${student['roll_number']} | ${student['department']} | ${student['batch_year']}',
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      student['attendance_status'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Show individual student attendance dialog
                    _showStudentAttendanceDialog(index);
                  },
                ),
              );
            },
          ),
        ),
        // Quick action buttons at the bottom
        if (_students.isNotEmpty && !_batchProcessing)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Mark All Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () => _confirmBulkUpdate('Present'),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.highlight_off),
                  label: Text('Mark All Absent'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _confirmBulkUpdate('Absent'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _confirmBulkUpdate(String status) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Bulk Update'),
          content: Text(
            'Are you sure you want to mark all students as $status?',
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop();
                _bulkUpdateAttendance(status);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _bulkUpdateAttendance(String status) async {
    if (_selectedDay == null || _students.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
      final batch = [];

      // Prepare batch operations
      for (var student in _students) {
        batch.add({
          'student_id': student['student_id'],
          'date': dateStr,
          'status': status,
          'subject': _selectedSubject,
        });
      }

      try {
        await supabase
            .from('attendance')
            .delete()
            .eq('date', dateStr)
            .eq('subject', _selectedSubject)
            .inFilter(
              'student_id',
              _students.map((s) => s['student_id']).toList(),
            );
        print('Delete operation successful');
      } catch (e) {
        print('Error during delete operation: $e');
      }
      // Insert all new records
      await supabase.from('attendance').insert(batch);

      // Update local state
      final updatedStudents =
          _students.map((student) {
            return {...student, 'attendance_status': status};
          }).toList();

      setState(() {
        _students = updatedStudents;

        // Update the attendance map for the calendar
        final dateWithoutTime = DateTime(
          _selectedDay!.year,
          _selectedDay!.month,
          _selectedDay!.day,
        );
        if (!_attendanceMap.containsKey(dateWithoutTime)) {
          _attendanceMap[dateWithoutTime] = [];
        }

        for (var student in _students) {
          final studentId = student['student_id'].toString();
          if (!_attendanceMap[dateWithoutTime]!.contains(studentId)) {
            _attendanceMap[dateWithoutTime]!.add(studentId);
          }
        }

        _isLoading = false;
        _pendingUpdates.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All students marked as $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Failed to update attendance: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'Absent':
        return Colors.red;
      case 'Late':
        return Colors.orange;
      case 'Leave':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
