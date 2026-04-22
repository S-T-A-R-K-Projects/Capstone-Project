import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation/main_navigation.dart';
import 'screens/introduction_page.dart';
import 'services/app_settings_service.dart';
import 'services/audio_classification_service.dart';
import 'services/live_update_service.dart';
import 'services/sound_filter_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await ThemeProvider.instance.load();
  await SoundFilterService().initialize();
  await LiveUpdateService().initialize(
    audioService: AudioClassificationService(),
  );
  runApp(SenScribeApp(key: SenScribeApp._appKey));
}

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  static ThemeProvider get instance => _instance;
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  final AppSettingsService _settingsService = AppSettingsService();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    _themeMode = await _settingsService.loadThemeMode();
  }

  void toggleTheme() {
    // Cycle: System -> Light -> Dark -> System
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    unawaited(_settingsService.saveThemeMode(_themeMode));
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      unawaited(_settingsService.saveThemeMode(_themeMode));
      notifyListeners();
    }
  }
}

class SenScribeApp extends StatefulWidget {
  const SenScribeApp({super.key});

  static final GlobalKey<_SenScribeAppState> _appKey =
      GlobalKey<_SenScribeAppState>();

  static void restartIntro() {
    _appKey.currentState?._showIntro();
  }

  @override
  State<SenScribeApp> createState() => _SenScribeAppState();
}

class _SenScribeAppState extends State<SenScribeApp> {
  final ThemeProvider _themeProvider = ThemeProvider();
  bool? _introCompleted;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _checkIntroCompleted();
  }

  void _showIntro() {
    setState(() {
      _introCompleted = false;
    });
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
      return MainNavigationPage(key: MainNavigationPage.navigationKey);
    }
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
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        if (!PlatformInfo.isAndroid) {
          return child;
        }

        return SafeArea(
          top: false,
          child: child,
        );
      },
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
