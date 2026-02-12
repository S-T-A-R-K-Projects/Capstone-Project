import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'navigation/main_navigation.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const SenScribeApp());
}

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
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
    _themeMode = mode;
    notifyListeners();
  }
}

class SenScribeApp extends StatefulWidget {
  const SenScribeApp({super.key});

  @override
  State<SenScribeApp> createState() => _SenScribeAppState();
}

class _SenScribeAppState extends State<SenScribeApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveApp(
      title: 'SenScribe',
      materialLightTheme: AppTheme.lightTheme,
      materialDarkTheme: AppTheme.darkTheme,
      cupertinoLightTheme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF1565C0),
      ),
      cupertinoDarkTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF42A5F5),
      ),
      themeMode: _themeProvider.themeMode,
      home: const MainNavigationPage(),
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
