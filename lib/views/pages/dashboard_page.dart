
import 'package:educaps/views/pages/assignment/assignment_page.dart';
import 'package:educaps/views/pages/assignment/firebase_service.dart';
import 'package:educaps/views/pages/attendence/attendance_screen.dart';
import 'package:educaps/views/widgets/dasgboard_icons.dart';
import 'package:flutter/material.dart';

import 'assignment/assignmentview_page.dart';
import 'notification_screen.dart';

final FirebaseService _firebaseService = FirebaseService();
String? userRole; // Store user role

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  // Fetch user role
  void _loadUserRole() async {
    String? role = await _firebaseService.getUserRole();
    setState(() {
      userRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Dashboard"),
          actions: [
            IconButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              NotificationScreen(title: "notifications"),
                    ),
                  ),
              icon: Icon(Icons.notification_add),
            ),
          ],
        ),
        body: Column(
          children: [
            Row(
              children: [
                RoundedIconButtonWithLabel(
                  icon: Icons.assignment_add,
                  label: "Assignment",
                  page:
                      userRole != "teacher"
                          ? const AssignmentListPage()
                          : const AssignmentPage(),
                ),
                RoundedIconButtonWithLabel(
                  icon: Icons.today,
                  label: "Attendence",
                  page: AttendanceScreen(title: "Attendence"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
