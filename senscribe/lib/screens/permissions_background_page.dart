import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PermissionsBackgroundPage extends StatelessWidget {
  const PermissionsBackgroundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Permissions & Background', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Permissions & background',
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
                    Text('Manage required permissions for the app to function.'),
                    SizedBox(height: 8),
                    Text('- Microphone (record audio)'),
                    Text('- Notifications (send alerts)'),
                    Text('- Haptics (vibration)'),
                    Text('- Background processing (run tasks in background)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requesting permissions (placeholder)'))),
                    child: const Text('Request permissions'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Permissions help'),
                      content: const Text('Open system settings to grant permissions if necessary.'),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                    ),
                  ),
                  child: const Text('Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
