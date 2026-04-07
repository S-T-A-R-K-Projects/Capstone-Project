import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:senscribe/models/custom_sound_profile.dart';
import 'package:senscribe/screens/custom_sound_enrollment_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
      'custom sound enrollment page shows back button and disables training until 10/3 is met',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomSoundEnrollmentPage(
          initialProfile: _profile(
            name: 'Doorbell',
            targetCount: 10,
            backgroundCount: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Samples 10/10'), findsOneWidget);
    expect(find.text('Background 2/3'), findsOneWidget);

    final trainButton = tester.widget<AdaptiveButton>(
      find.widgetWithText(AdaptiveButton, 'Train Custom Model'),
    );
    expect(trainButton.enabled, isFalse);
  });

  testWidgets(
      'custom sound enrollment page enables training when 10 target and 3 background samples exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomSoundEnrollmentPage(
          initialProfile: _profile(
            name: 'Kettle',
            targetCount: 10,
            backgroundCount: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Samples 10/10'), findsOneWidget);
    expect(find.text('Background 3/3'), findsOneWidget);

    final trainButton = tester.widget<AdaptiveButton>(
      find.widgetWithText(AdaptiveButton, 'Train Custom Model'),
    );
    expect(trainButton.enabled, isTrue);
  });
}

CustomSoundProfile _profile({
  required String name,
  required int targetCount,
  required int backgroundCount,
}) {
  return CustomSoundProfile(
    id: name.toLowerCase(),
    name: name,
    status: CustomSoundProfileStatus.draft,
    createdAt: DateTime(2026, 4, 1),
    updatedAt: DateTime(2026, 4, 1),
    targetSamplePaths: List<String>.generate(
      targetCount,
      (index) => 'target_${index + 1}.wav',
    ),
    backgroundSamplePaths: List<String>.generate(
      backgroundCount,
      (index) => 'background_${index + 1}.wav',
    ),
  );
}
