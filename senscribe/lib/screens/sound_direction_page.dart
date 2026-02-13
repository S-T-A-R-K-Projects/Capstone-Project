import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class SoundDirectionPage extends StatelessWidget {
  const SoundDirectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Sound Direction'),
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
                'Sound direction',
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
                          'Enable or calibrate the sound direction detection.'),
                      SizedBox(height: 8),
                      Text('- Enable/disable detection'),
                      Text('- Run calibration routine'),
                      Text('- View calibration tips'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: () => AdaptiveSnackBar.show(
                        context,
                        message: 'Start calibration (placeholder)',
                        type: AdaptiveSnackBarType.info,
                      ),
                      label: 'Calibrate',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: AdaptiveButton(
                      onPressed: () => AdaptiveAlertDialog.show(
                        context: context,
                        title: 'Calibration tips',
                        message:
                            'Place the device on a flat surface and rotate slowly during calibration.',
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
