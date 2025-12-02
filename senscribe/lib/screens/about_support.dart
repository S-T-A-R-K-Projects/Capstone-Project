import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutSupportPage extends StatelessWidget {
	const AboutSupportPage({super.key});

	static const _supportEmail = 'support@senscribe.example';

	void _copyEmail(BuildContext context) async {
		final scaffoldMessenger = ScaffoldMessenger.of(context);
		await Clipboard.setData(const ClipboardData(text: _supportEmail));
		scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Support email copied to clipboard')));
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('About & Support'),
				backgroundColor: Theme.of(context).colorScheme.primary,
			),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const SizedBox(height: 12),
						const Text('Acknowledgements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
						const SizedBox(height: 8),
						Expanded(
							child: SingleChildScrollView(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: const [
										Text('SenScribe was built by Team STARK.'),
										SizedBox(height: 8),
										Text('Contributors:'),
										Text('- Kaushik Naik'),
										Text('- Tamerlan Khalilbayov'),
										Text('- Spencer Russel'),
										Text('- Reewaz Rijal'),
										SizedBox(height: 8),
										Text('Third-party packages used in the app (selected):'),
										Text('- flutter_animate'),
										Text('- google_fonts'),
										Text('- animated_bottom_navigation_bar'),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Row(
							children: [
								Expanded(
									child: ElevatedButton(
										onPressed: () => _copyEmail(context),
										child: const Text('Copy support email'),
									),
								),
								const SizedBox(width: 12),
								TextButton(
									onPressed: () => showDialog<void>(
										context: context,
										builder: (context) => AlertDialog(
											title: const Text('Contact Support'),
											content: const Text('You can reach support at support@senscribe.example'),
											actions: [
												TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
											],
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