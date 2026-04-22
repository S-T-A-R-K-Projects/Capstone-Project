import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_logger.dart';
import 'start_page.dart';
import 'unified_home_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  static final GlobalKey<_HomeTabState> _homeTabKey =
      GlobalKey<_HomeTabState>();
  static _HomeTabState? _currentState;

  static Key get navigationKey => _homeTabKey;

  static String get currentVisiblePageName =>
      (_homeTabKey.currentState ?? _currentState)?.currentPageName ?? 'Home';

  static Future<void> restartOnboarding() async =>
      (_homeTabKey.currentState ?? _currentState)?.showOnboarding();

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _lastLoggedPageName;

  @override
  void initState() {
    super.initState();
    HomeTab._currentState = this;
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    if (HomeTab._currentState == this) {
      HomeTab._currentState = null;
    }
    super.dispose();
  }

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
