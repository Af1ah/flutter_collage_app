
import 'package:educaps/views/values/notifiers.dart';
import 'package:flutter/material.dart';

class NavebarWidget extends StatefulWidget {
  const NavebarWidget({super.key});

  @override
  State<NavebarWidget> createState() => _NavebarWidgetState();
}

class _NavebarWidgetState extends State<NavebarWidget> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedIndex,
      builder: (BuildContext context, int selected, Widget? child) {
        return NavigationBar(
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.dashboard),
              label: "Dashboard",
            ),
            NavigationDestination(icon: Icon(Icons.person), label: "profile"),
          ],
          onDestinationSelected: (value) {
            selectedIndex.value = value;
          },
          selectedIndex: selected,
        );
      },
    );
  }
}
