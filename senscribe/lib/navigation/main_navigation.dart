import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
  final List<Widget> _pages = const [
    UnifiedHomePage(),
    HistoryPage(),
    AlertsPage(),
    SettingsPage(),
  ];

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

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final useNativeBar = PlatformInfo.isIOS26OrHigher();

    return AdaptiveScaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          return true; // Stop scroll notifications from reaching AdaptiveScaffold to prevent dock scaling
        },
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        useNativeBottomBar: useNativeBar,
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          AdaptiveNavigationDestination(
            icon: useNativeBar ? 'house.fill' : Icons.home_rounded,
            label: 'Home',
          ),
          AdaptiveNavigationDestination(
            icon:
                useNativeBar ? 'clock.arrow.circlepath' : Icons.history_rounded,
            label: 'History',
          ),
          AdaptiveNavigationDestination(
            icon: useNativeBar ? 'bell.fill' : Icons.notifications_rounded,
            label: 'Alerts',
          ),
          AdaptiveNavigationDestination(
            icon: useNativeBar ? 'gear' : Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
