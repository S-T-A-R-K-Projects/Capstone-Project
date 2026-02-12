import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../screens/unified_home_page.dart';
import '../screens/history_page.dart';
import '../screens/alerts_page.dart';
import '../screens/settings_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  List<Widget> get _pages => const [
        UnifiedHomePage(),
        HistoryPage(),
        AlertsPage(),
        SettingsPage(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          return true; // Stop scroll notifications from reaching AdaptiveScaffold to prevent dock scaling
        },
        child: AnimationConfiguration.staggeredList(
          position: _selectedIndex,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            horizontalOffset: 50.0,
            child: FadeInAnimation(
              child: IndexedStack(index: _selectedIndex, children: _pages),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: true, // Glass effect for iOS 26+
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          AdaptiveNavigationDestination(
            icon: Platform.isIOS ? 'house.fill' : Icons.home_rounded,
            label: 'Home',
          ),
          AdaptiveNavigationDestination(
            icon: Platform.isIOS ? 'clock.fill' : Icons.history_rounded,
            label: 'History',
          ),
          AdaptiveNavigationDestination(
            icon: Platform.isIOS ? 'bell.fill' : Icons.notifications_rounded,
            label: 'Alerts',
          ),
          AdaptiveNavigationDestination(
            icon: Platform.isIOS ? 'gear' : Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
