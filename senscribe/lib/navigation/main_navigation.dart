import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../screens/home_tab.dart';
import '../screens/history_page.dart';
import '../screens/alerts_page.dart';
import '../screens/settings_page.dart';
import '../services/app_permission_service.dart';

class MainNavigationPage extends StatefulWidget {
  static final GlobalKey<_MainNavigationPageState> _navigationKey =
      GlobalKey<_MainNavigationPageState>();

  const MainNavigationPage({super.key});

  static Key get navigationKey => _navigationKey;

  static void showAlertsTab({int selectedTabIndex = 0}) {
    _navigationKey.currentState?._showAlertsTab(
      selectedTabIndex: selectedTabIndex,
    );
  }

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  final AppPermissionService _permissionService = AppPermissionService();
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    HomeTab(key: HomeTab.navigationKey),
    const HistoryPage(),
    AlertsPage(key: AlertsPage.navigationKey),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _permissionService.requestInitialPermissionsIfNeeded();
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showAlertsTab({int selectedTabIndex = 0}) {
    if (mounted && _selectedIndex != 2) {
      setState(() {
        _selectedIndex = 2;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedTabIndex == 1) {
        AlertsPage.showTriggerWords();
      } else {
        AlertsPage.showRecentAlerts();
      }
    });
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
            icon: useNativeBar ? 'doc.text.fill' : Icons.description_rounded,
            label: 'Texts',
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
