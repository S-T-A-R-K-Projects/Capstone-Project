import 'package:flutter/material.dart';

import '../services/app_logger.dart';
import 'unified_home_page.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  static final GlobalKey<_HomeTabState> _homeTabKey =
      GlobalKey<_HomeTabState>();
  static _HomeTabState? _currentState;

  static Key get navigationKey => _homeTabKey;

  static String get currentVisiblePageName =>
      (_homeTabKey.currentState ?? _currentState)?.currentPageName ??
      'Unified Home';

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _lastLoggedPageName;

  String get currentPageName => 'Unified Home';

  @override
  void initState() {
    super.initState();
    HomeTab._currentState = this;
  }

  @override
  void dispose() {
    if (HomeTab._currentState == this) {
      HomeTab._currentState = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageName = currentPageName;
    if (_lastLoggedPageName != pageName) {
      _lastLoggedPageName = pageName;
      AppLogger.logPageVisit(pageName);
    }

    return const UnifiedHomePage();
  }
}
