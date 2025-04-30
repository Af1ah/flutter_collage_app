import 'package:educaps/views/pages/dashboard_page.dart';
import 'package:educaps/views/pages/profile_page.dart';
import 'package:educaps/views/values/notifiers.dart';
import 'package:educaps/views/widgets/navebar_widget.dart';
import 'package:flutter/material.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  List<Widget> pages = [DashboardPage(), ProfileDetails()];
  List<String> appBartitles = ["Collage Dashboard", "profile page"];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedIndex,
      builder: (BuildContext context, int selectedPage, Widget? child) {
        return Scaffold(
          body: pages[selectedPage],
          bottomNavigationBar: NavebarWidget(),
        );
      },
    );
  }
}
