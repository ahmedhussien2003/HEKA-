import 'package:flutter/material.dart';
import 'widgets/navbar_widget.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/history_page.dart';
import 'pages/saved_page.dart';
import '../data/notifiers.dart';

// ======================
// Pages
// ======================

final List<Widget> pages = [
  const HomePage(),
  const HistoryPage(),
  const Center(
    child: Text(
      "AR Scan Page",
      style: TextStyle(color: Colors.white, fontSize: 24),
    ),
  ),
  const SavedPage(),
  const ProfilePage(),
];

// Headers are now managed internally by each page.

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDarkMode, _) {
        final backgroundColor = isDarkMode
            ? const Color(0xFF0D0C09)
            : const Color(0xFFF7F0E8);
        return ValueListenableBuilder<int>(
          valueListenable: selectedPageNotifier,
          builder: (context, index, _) {
            return Scaffold(
              backgroundColor: backgroundColor,
              extendBody: true, // Seamless floating navbar
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(index),
                  child: pages[index],
                ),
              ),
              bottomNavigationBar: const NavbarWidget(),
            );
          },
        );
      },
    );
  }
}
