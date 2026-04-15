import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_logger.dart';
import 'start_page.dart';
import 'unified_home_page.dart';

/// HomeTab wraps the home page logic and shows StartPage only on first launch.
/// After the user completes the start screen, it shows UnifiedHomePage.
/// This design keeps the bottom navigation visible at all times.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  static final GlobalKey<_HomeTabState> _homeTabKey =
      GlobalKey<_HomeTabState>();

  static Key get navigationKey => _homeTabKey;

  static String get currentVisiblePageName =>
      _homeTabKey.currentState?.currentPageName ?? 'Home';

  static Future<void> restartOnboarding() async =>
      _homeTabKey.currentState?.showOnboarding();

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _lastLoggedPageName;

  Future<void> showOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunched', false);

    if (mounted) {
      setState(() {
        _isFirstLaunch = true;
      });
    }
  }

  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunched = prefs.getBool('hasLaunched') ?? false;

    if (mounted) {
      setState(() {
        _isFirstLaunch = !hasLaunched;
        _isLoading = false;
      });
    }
  }

  Future<void> _markFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunched', true);

    if (mounted) {
      setState(() {
        _isFirstLaunch = false;
      });
    }
  }

  String get currentPageName {
    if (_isLoading) return 'Home Loading';
    if (_isFirstLaunch) return 'Welcome to SenScribe';
    return 'Unified Home';
  }

  @override
  Widget build(BuildContext context) {
    final pageName = currentPageName;
    if (_lastLoggedPageName != pageName) {
      _lastLoggedPageName = pageName;
      AppLogger.logPageVisit(pageName);
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isFirstLaunch) {
      return StartPage(onGetStarted: _markFirstLaunchComplete);
    }

    return const UnifiedHomePage();
  }
}
