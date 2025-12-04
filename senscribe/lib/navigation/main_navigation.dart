import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../screens/home_page.dart';
import '../screens/history_page.dart';
import '../screens/alerts_page.dart';
import '../screens/settings_page.dart';
import '../screens/speech_to_text_page.dart';
import '../screens/text_to_speech_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimationController;
  bool _isMonitoring = false;
  late AnimationController _monitoringPulseController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _monitoringPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _monitoringPulseController.dispose();
    super.dispose();
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        _monitoringPulseController.repeat();
      } else {
        _monitoringPulseController.stop();
        _monitoringPulseController.reset();
      }
    });
  }

  List<Widget> get _pages => [
    HomePage(
      isMonitoring: _isMonitoring,
      pulseController: _monitoringPulseController,
      onToggleMonitoring: _toggleMonitoring,
    ),
    HistoryPage(),
    AlertsPage(),
    SettingsPage(),
    SpeechToTextPage(
      isMonitoring: _isMonitoring,
      pulseController: _monitoringPulseController,
      onToggleMonitoring: _toggleMonitoring,
    ),
    TextToSpeechPage(
      isMonitoring: _isMonitoring,
      pulseController: _monitoringPulseController,
      onToggleMonitoring: _toggleMonitoring,
    ),
  ];

  final iconList = <IconData>[
    Icons.home_rounded,
    Icons.history_rounded,
    Icons.notifications_rounded,
    Icons.settings_rounded,
  ];

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
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 4 || _selectedIndex == 5) ? 
        SpeedDial(
          icon: _selectedIndex == 0 ? Icons.add_rounded : Icons.home_rounded,
          activeIcon: Icons.close_rounded,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
          activeForegroundColor: Colors.white,
          activeBackgroundColor: Theme.of(context).colorScheme.secondary,
          buttonSize: const Size(56.0, 56.0),
          visible: true,
          closeManually: false,
          curve: Curves.bounceIn,
          overlayColor: Colors.black,
          overlayOpacity: 0.5,
          elevation: 8.0,
          shape: const CircleBorder(),
          children: [
            if (_selectedIndex == 4 || _selectedIndex == 5)
              SpeedDialChild(
                child: const Icon(Icons.hearing_rounded),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                label: 'R-T Sound Feed',
                labelStyle: const TextStyle(fontSize: 16.0),
                onTap: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
            SpeedDialChild(
              child: const Icon(Icons.mic_rounded),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              label: 'Speech to Text',
              labelStyle: const TextStyle(fontSize: 16.0),
              onTap: () {
                setState(() {
                  _selectedIndex = 4;
                });
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.volume_up_rounded),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              label: 'Text to Speech',
              labelStyle: const TextStyle(fontSize: 16.0),
              onTap: () {
                setState(() {
                  _selectedIndex = 5;
                });
              },
            ),
          ],
        ).animate()
          .scale(duration: 300.ms)
          .then()
          .shimmer(duration: 1000.ms) : null,
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