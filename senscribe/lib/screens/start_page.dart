import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'unified_home_page.dart';

/// A simple landing screen that welcomes the user and provides a single
/// button to access the main home page with all the app's features.
///
/// The visual style mirrors the rest of the app by using [AdaptiveScaffold],
/// [AdaptiveAppBar] and the standard theme colours for buttons.
class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  void _openHomePage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (c) => const UnifiedHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Welcome'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (topInset > 0) SizedBox(height: topInset),
              // replicate header from unified home to keep branding
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/real_logo.png',
                        height: 32,
                        width: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "SenScribe",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome to SenScribe',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your assistant for text-to-speech, speech-to-text, and sound recognition.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    AdaptiveButton(
                      onPressed: () => _openHomePage(context),
                      label: 'Get Started',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
