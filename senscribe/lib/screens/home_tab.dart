import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_page.dart';
import 'unified_home_page.dart';

/// HomeTab wraps the home page logic and shows StartPage only on first launch.
/// After the user completes the start screen, it shows UnifiedHomePage.
/// This design keeps the bottom navigation visible at all times.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  static final GlobalKey<_HomeTabState> homeTabKey = GlobalKey<_HomeTabState>();

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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

  @override
  Widget build(BuildContext context) {
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
