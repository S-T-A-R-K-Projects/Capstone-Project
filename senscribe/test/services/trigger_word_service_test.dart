import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/sound_location_snapshot.dart';
import 'package:senscribe/models/trigger_alert.dart';
import 'package:senscribe/services/trigger_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const feedbackChannel = MethodChannel('senscribe/alert_feedback');
  late TriggerWordService service;
  late List<MethodCall> feedbackCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = TriggerWordService();
    await service.clearAlerts();

    feedbackCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(feedbackChannel,
            (MethodCall methodCall) async {
      feedbackCalls.add(methodCall);
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(feedbackChannel, null);
    await service.clearAlerts();
  });

  test('trigger detection requests native alert feedback', () async {
    await service.playTriggerDetectedFeedback();

    expect(feedbackCalls, hasLength(1));
    expect(feedbackCalls.single.method, 'playTriggerAlertFeedback');
  });

  test('deduplicated sound alerts are only stored once', () async {
    final alert = TriggerAlert(
      triggerWord: 'doorbell',
      detectedText: 'Doorbell detected',
      source: TriggerAlert.sourceSoundRecognition,
      metadata: const <String, dynamic>{'soundEventKey': 'doorbell-1'},
    );

    final firstAdd = await service.addAlert(alert);
    final secondAdd = await service.addAlert(alert);

    expect(firstAdd, isTrue);
    expect(secondAdd, isFalse);

    final alerts = await service.loadAlerts();
    expect(alerts, hasLength(1));
    expect(alerts.single.normalizedSoundKey, 'doorbell-1');
  });

  test('sound alerts without location metadata remain backward compatible',
      () async {
    final alert = TriggerAlert(
      triggerWord: 'doorbell',
      detectedText: 'Doorbell detected',
      source: TriggerAlert.sourceSoundRecognition,
      metadata: const <String, dynamic>{'soundEventKey': 'legacy-doorbell'},
    );

    await service.addAlert(alert);

    final alerts = await service.loadAlerts();
    final location = SoundLocationSnapshot.fromMetadata(alerts.single.metadata);
    expect(location.status, SoundLocationStatus.notRecorded);
  });
}
