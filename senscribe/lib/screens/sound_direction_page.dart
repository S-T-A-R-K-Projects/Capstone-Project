import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SoundDirectionPage extends StatelessWidget {
  const SoundDirectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sound Direction', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Text('Enable or calibrate the sound direction detection.'),
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
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start calibration (placeholder)'))),
                    child: const Text('Calibrate'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Calibration tips'),
                      content: const Text('Place the device on a flat surface and rotate slowly during calibration.'),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                    ),
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
