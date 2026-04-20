import 'package:flutter/material.dart';

import 'unified_home_page.dart';

/// HomeTab is the Home tab inside MainNavigation.
/// Always shows UnifiedHomePage — onboarding is handled at the app level.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  static final GlobalKey<State> homeTabKey = GlobalKey<State>();

  @override
  Widget build(BuildContext context) {
    return const UnifiedHomePage();
  }
}
