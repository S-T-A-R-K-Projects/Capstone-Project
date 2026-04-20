import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation/main_navigation.dart';
import 'screens/introduction_page.dart';
import 'theme/app_theme.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const SenScribeApp());
}

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  static ThemeProvider get instance => _instance;
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    // Cycle: System -> Light -> Dark -> System
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}

class SenScribeApp extends StatefulWidget {
  const SenScribeApp({super.key});

  @override
  State<SenScribeApp> createState() => _SenScribeAppState();
}

class _SenScribeAppState extends State<SenScribeApp> {
  final ThemeProvider _themeProvider = ThemeProvider();
  // null = still loading, false = show intro, true = show home
  bool? _introCompleted;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _checkIntroCompleted();
  }

  Future<void> _checkIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('intro_completed') ?? false;
    setState(() {
      _introCompleted = completed;
    });
  }

  Future<void> _markIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_completed', true);
    setState(() {
      _introCompleted = true;
    });
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  Widget _buildHome() {
    if (_introCompleted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1724),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_introCompleted == true) {
      return const MainNavigationPage();
    }
    // Full-screen standalone intro — no bottom nav
    return IntroductionPage(onDone: _markIntroCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'SenScribe',
      materialLightTheme: AppTheme.lightTheme,
      materialDarkTheme: AppTheme.darkTheme,
      cupertinoLightTheme: AppTheme.cupertinoLightTheme,
      cupertinoDarkTheme: AppTheme.cupertinoDarkTheme,
      themeMode: _themeProvider.themeMode,
      home: _buildHome(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
      ],
    );
  }
}
