import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../screens/home_page.dart';
import '../screens/history_page.dart';
import '../screens/alerts_page.dart';
import '../screens/settings_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimationController;
  // current UI mode for HomePage: 'speech' or 'text'
  String _mode = 'speech';
  List<Widget> get _pages => [
        HomePage(mode: _mode),
        HistoryPage(),
        AlertsPage(),
        SettingsPage(),
      ];

  final iconList = <IconData>[
    Icons.home_rounded,
    Icons.history_rounded,
    Icons.notifications_rounded,
    Icons.settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimationConfiguration.staggeredList(
        position: _selectedIndex,
        duration: const Duration(milliseconds: 375),
        child: SlideAnimation(
          horizontalOffset: 50.0,
          child: FadeInAnimation(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                  // Show a true semicircular overlay anchored above the nav bar.
                  OverlayEntry? entry;
                  entry = OverlayEntry(builder: (context) {
                    // Overlay constants
                    const double width = 320;
                    const double height = 160;
                    const double btnSize = 68;
                    final double centerX = width / 2;
                    final double centerY = height; // center at bottom of the box
                    final double radius = 120;

                    // angles for two options along the semicircle (left to right)
                    final leftAngle = 160.0 * (math.pi / 180.0);
                    final rightAngle = 20.0 * (math.pi / 180.0);

                    final leftX = centerX + radius * math.cos(leftAngle);
                    final leftY = centerY - radius * math.sin(leftAngle);
                    final rightX = centerX + radius * math.cos(rightAngle);
                    final rightY = centerY - radius * math.sin(rightAngle);

                    return Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          entry?.remove();
                        },
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 64.0),
                                child: SizedBox(
                                  width: width,
                                  height: height,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // semicircle background
                                      CustomPaint(
                                        size: const Size(width, height),
                                        painter: _SemiCirclePainter(
                                          color: Theme.of(context).colorScheme.surface,
                                        ),
                                      ),
                                      // Left option (Speech to Text) - placed on arc
                                      Positioned(
                                        left: leftX - (btnSize / 2),
                                        top: leftY - (btnSize / 2),
                                        child: Column(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _mode = 'speech';
                                                });
                                                entry?.remove();
                                              },
                                              child: Container(
                                                width: btnSize,
                                                height: btnSize,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.hearing_rounded, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                'Speech to Text',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Right option (Text to Speech)
                                      Positioned(
                                        left: rightX - (btnSize / 2),
                                        top: rightY - (btnSize / 2),
                                        child: Column(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _mode = 'text';
                                                });
                                                entry?.remove();
                                              },
                                              child: Container(
                                                width: btnSize,
                                                height: btnSize,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
                                                  ],
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.record_voice_over, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                'Text to Speech',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                  Overlay.of(context).insert(entry);

                _fabAnimationController.forward().then((_) {
                  _fabAnimationController.reverse();
                });
              },
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ).animate().scale(duration: 300.ms).then().shimmer(duration: 1000.ms)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar(
        icons: iconList,
        activeIndex: _selectedIndex,
        onTap: _onItemTapped,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 32,
        rightCornerRadius: 32,
        activeColor: Theme.of(context).colorScheme.primary,
        inactiveColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        iconSize: 24,
      ),
    );
  }

}

class _SemiCirclePainter extends CustomPainter {
  final Color color;
  _SemiCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height), radius: size.width / 2);
    // draw the top semicircle (arc from 180deg to 0deg)
    canvas.drawArc(rect, math.pi, -math.pi, false, paint);
  // optional: leave as flat colored semicircle; shadow handled by container
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}