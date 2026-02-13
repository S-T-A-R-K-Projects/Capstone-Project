import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class NameRecognitionPage extends StatelessWidget {
  const NameRecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Name Recognition',
      ),
      body: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding for iOS 26 translucent app bar
              if (Platform.isIOS)
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
              const SizedBox(height: 12),
              Text(
                'Name recognition',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                          'Configure name recognition behavior and haptic feedback.'),
                      SizedBox(height: 8),
                      Text('- Enable/disable recognition'),
                      Text('- Enter name to prioritize'),
                      Text('- Choose haptic pattern'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: () => AdaptiveSnackBar.show(context,
                          message: 'Open name recognition editor (placeholder)',
                          type: AdaptiveSnackBarType.info),
                      label: 'Edit name recognition',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: AdaptiveButton(
                      onPressed: () => AdaptiveAlertDialog.show(
                        context: context,
                        title: 'Haptic patterns',
                        message:
                            'Select the haptic pattern used when a recognized name appears.',
                        actions: [
                          AlertAction(
                            title: 'Close',
                            style: AlertActionStyle.cancel,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      label: 'View',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
