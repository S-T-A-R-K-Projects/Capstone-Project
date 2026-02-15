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

import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimationController;

  // Separate monitoring states for each feature
  bool _isSoundFeedMonitoring = false;
  bool _isSpeechToTextMonitoring = false;
  bool _isTextToSpeechMonitoring = false;

  late AnimationController _soundFeedPulseController;
  late AnimationController _speechToTextPulseController;
  late AnimationController _textToSpeechPulseController;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _soundFeedPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _speechToTextPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _textToSpeechPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      // Fail-safe for older Android versions or if manage is not applicable (though manifest says manage)
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _soundFeedPulseController.dispose();
    _speechToTextPulseController.dispose();
    _textToSpeechPulseController.dispose();
    super.dispose();
  }

  void _toggleSoundFeedMonitoring() {
    setState(() {
      _isSoundFeedMonitoring = !_isSoundFeedMonitoring;
      if (_isSoundFeedMonitoring) {
        _soundFeedPulseController.repeat();
      } else {
        _soundFeedPulseController.stop();
        _soundFeedPulseController.reset();
      }
    });
  }

  void _toggleSpeechToTextMonitoring() {
    setState(() {
      _isSpeechToTextMonitoring = !_isSpeechToTextMonitoring;
      if (_isSpeechToTextMonitoring) {
        _speechToTextPulseController.repeat();
      } else {
        _speechToTextPulseController.stop();
        _speechToTextPulseController.reset();
      }
    });
  }

  void _toggleTextToSpeechMonitoring() {
    setState(() {
      _isTextToSpeechMonitoring = !_isTextToSpeechMonitoring;
      if (_isTextToSpeechMonitoring) {
        _textToSpeechPulseController.repeat();
      } else {
        _textToSpeechPulseController.stop();
        _textToSpeechPulseController.reset();
      }
    });
  }

  List<Widget> get _pages => [
    HomePage(
      isMonitoring: _isSoundFeedMonitoring,
      pulseController: _soundFeedPulseController,
      onToggleMonitoring: _toggleSoundFeedMonitoring,
    ),
    HistoryPage(),
    AlertsPage(),
    SettingsPage(),
    SpeechToTextPage(
      isMonitoring: _isSpeechToTextMonitoring,
      pulseController: _speechToTextPulseController,
      onToggleMonitoring: _toggleSpeechToTextMonitoring,
    ),
    TextToSpeechPage(
      isMonitoring: _isTextToSpeechMonitoring,
      pulseController: _textToSpeechPulseController,
      onToggleMonitoring: _toggleTextToSpeechMonitoring,
    ),
  ];

  final iconList = <IconData>[
    Icons.hearing_rounded,
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
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ),
      ),
      floatingActionButton:
          (_selectedIndex == 0 || _selectedIndex == 4 || _selectedIndex == 5)
          ? SpeedDial(
                  icon: _selectedIndex == 0
                      ? Icons.add_rounded
                      : Icons.home_rounded,
                  activeIcon: Icons.close_rounded,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  activeForegroundColor: Colors.white,
                  activeBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondary,
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
                )
                .animate()
                .scale(duration: 300.ms)
                .then()
                .shimmer(duration: 1000.ms)
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
