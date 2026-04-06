import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF2563EB); // Royal Blue
  static const Color _lightSecondary = Color(0xFF4F46E5); // Indigo
  static const Color _lightSurface = Color(0xFFF9FAFB); // Very Light Gray
  static const Color _lightSurfaceContainer = Color(0xFFFFFFFF); // White
  static const Color _lightOnSurface = Color(0xFF111827); // Very Dark Gray

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFF3B82F6); // Vibrant Blue
  static const Color _darkSecondary = Color(0xFF8B5CF6); // Vibrant Violet
  static const Color _darkSurface = Color(0xFF0A0E17); // Deep Midnight Blue
  static const Color _darkSurfaceContainer = Color(0xFF151D2C); // Slightly Lighter Midnight
  static const Color _darkOnSurface = Color(0xFFF3F4F6); // Off White

  static ColorScheme get _lightColorScheme {
    return ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _lightPrimary,
      onPrimary: Colors.white,
      secondary: _lightSecondary,
      onSecondary: Colors.white,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      surfaceContainerHighest: _lightSurfaceContainer,
      outline: const Color(0xFFD1D5DB),
      error: const Color(0xFFDC2626),
      onError: Colors.white,
    );
  }

  static ColorScheme get _darkColorScheme {
    return ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _darkPrimary,
      onPrimary: Colors.white,
      secondary: _darkSecondary,
      onSecondary: Colors.white,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerHighest: _darkSurfaceContainer,
      outline: const Color(0xFF374151),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
    );
  }

  static TextTheme _buildTextTheme(
      TextTheme baseTextTheme, ColorScheme scheme) {
    // Body font: Inter
    final base = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    // Headings: Inter
    return base.copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.inter( // Keep title medium as Inter for better list readabilty
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withValues(alpha: 0.9),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final textTheme = _buildTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark(useMaterial3: true).textTheme
          : ThemeData.light(useMaterial3: true).textTheme,
      colorScheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      iconTheme:
          IconThemeData(color: colorScheme.onSurface.withValues(alpha: 0.9)),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.35),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurface.withValues(alpha: 0.85),
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(88, 52),
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.5),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 52),
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 52),
          foregroundColor: colorScheme.primary,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65), // Translucent card base
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)), // Thin glass border
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.65),
        ),
        labelStyle: textTheme.bodyMedium,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary.withValues(alpha: 0.2),
        disabledColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        deleteIconColor: colorScheme.onSurface.withValues(alpha: 0.75),
        labelStyle: textTheme.bodyMedium ?? const TextStyle(),
        secondaryLabelStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary) ??
                const TextStyle(),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor:
            WidgetStatePropertyAll(colorScheme.outline.withValues(alpha: 0.4)),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurface.withValues(alpha: 0.75);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.35);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimary;
            }
            return colorScheme.onSurface;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.surfaceContainerHighest;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        actionTextColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  static ThemeData get lightTheme {
    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: _lightColorScheme,
    );
  }

  static ThemeData get darkTheme {
    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: _darkColorScheme,
    );
  }

  static CupertinoThemeData get cupertinoLightTheme {
    return CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: _lightColorScheme.primary,
      scaffoldBackgroundColor: _lightColorScheme.surface,
      barBackgroundColor: _lightColorScheme.surface,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.inter(color: _lightColorScheme.onSurface),
      ),
    );
  }

  static CupertinoThemeData get cupertinoDarkTheme {
    return CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: _darkColorScheme.primary,
      scaffoldBackgroundColor: _darkColorScheme.surface,
      barBackgroundColor: _darkColorScheme.surface,
      textTheme: CupertinoTextThemeData(
        textStyle: GoogleFonts.inter(color: _darkColorScheme.onSurface),
      ),
    );
  }
}
