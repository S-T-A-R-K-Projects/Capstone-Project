import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/sound_caption.dart';
import 'package:senscribe/models/sound_filter.dart';
import 'package:senscribe/screens/home_page.dart';
import 'package:senscribe/services/audio_classification_service.dart';
import 'package:senscribe/services/sound_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final audioService = AudioClassificationService();
  final filterService = SoundFilterService();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    audioService.debugReplaceHistory(<SoundCaption>[
      SoundCaption(
        sound: 'Speech',
        timestamp: DateTime(2026, 4, 12, 10),
        isCritical: false,
        confidence: 0.91,
      ),
      SoundCaption(
        sound: 'Dog',
        timestamp: DateTime(2026, 4, 12, 10, 0, 5),
        isCritical: false,
        confidence: 0.88,
      ),
    ]);
  });

  tearDown(() async {
    await filterService.debugReset(
        selectedFilters: SoundFilterId.defaultSelection);
    audioService.debugReplaceHistory(const <SoundCaption>[]);
  });

  testWidgets('home page filters the feed and supports multi-select chips', (
    tester,
  ) async {
    final pulseController = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(pulseController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          isMonitoring: false,
          pulseController: pulseController,
          onToggleMonitoring: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speech'), findsOneWidget);
    expect(find.text('Dog'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Animals'));
    await tester.pumpAndSettle();

    expect(find.text('Speech'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'People & Speech'));
    await tester.pumpAndSettle();

    expect(find.text('Speech'), findsNothing);
    expect(find.text('Dog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Animals'));
    await tester.pumpAndSettle();

    expect(
        find.text('Please select a filter to show the sounds'), findsOneWidget);
    expect(find.text('Dog'), findsNothing);
    expect(find.text('No filters selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();

    expect(find.text('Speech'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Animals'));
    await tester.pumpAndSettle();

    expect(find.text('Speech'), findsOneWidget);
    expect(find.text('Dog'), findsNothing);
  });
}
