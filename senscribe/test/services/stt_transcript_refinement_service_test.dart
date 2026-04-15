import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/trigger_word.dart';
import 'package:senscribe/services/stt_transcript_refinement_service.dart';
import 'package:senscribe/services/trigger_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TriggerWordService triggerWordService;
  late SttTranscriptRefinementService refinementService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    triggerWordService = TriggerWordService();
    refinementService = SttTranscriptRefinementService(
      triggerWordService: triggerWordService,
    );
    await triggerWordService.saveTriggerWords(const []);
  });

  String refine(
    String text, {
    required bool isFinal,
    required SttBackend backend,
    List<String> alternates = const [],
    List<String> recognizedPhrases = const [],
  }) {
    return refinementService.refine(
      SttRefinementRequest(
        text: text,
        isFinal: isFinal,
        backend: backend,
        alternates: alternates,
        recognizedPhrases: recognizedPhrases,
      ),
    );
  }

  test('final standalone subscribe becomes SenScribe', () {
    expect(
      refine(
        'subscribe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('partial standalone subscribe stays unchanged on Android', () {
    expect(
      refine(
        'subscribe',
        isFinal: false,
        backend: SttBackend.androidOfflineVosk,
      ),
      'subscribe',
    );
  });

  test('partial standalone subscribe becomes SenScribe on iOS', () {
    expect(
      refine(
        'subscribe',
        isFinal: false,
        backend: SttBackend.iosSpeechToText,
      ),
      'SenScribe',
    );
  });

  test('open subscribe becomes open SenScribe', () {
    expect(
      refine(
        'open subscribe',
        isFinal: false,
        backend: SttBackend.androidOfflineVosk,
      ),
      'open SenScribe',
    );
  });

  test('launch send a scribe app becomes launch SenScribe app', () {
    expect(
      refine(
        'launch send a scribe app',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'launch SenScribe app',
    );
  });

  test('use sense scribe becomes use SenScribe', () {
    expect(
      refine(
        'use sense scribe',
        isFinal: false,
        backend: SttBackend.androidOfflineVosk,
      ),
      'use SenScribe',
    );
  });

  test('partial standalone send scribe becomes SenScribe', () {
    expect(
      refine(
        'send scribe',
        isFinal: false,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('sen describe becomes SenScribe', () {
    expect(
      refine(
        'sen describe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('sense gripe becomes SenScribe', () {
    expect(
      refine(
        'sense gripe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('descends gripe becomes SenScribe', () {
    expect(
      refine(
        'descends gripe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('sens great becomes SenScribe', () {
    expect(
      refine(
        'sens great',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe',
    );
  });

  test('subscribe settings becomes SenScribe settings', () {
    expect(
      refine(
        'subscribe settings',
        isFinal: true,
        backend: SttBackend.iosSpeechToText,
      ),
      'SenScribe settings',
    );
  });

  test('welcome to subscribe becomes welcome to SenScribe', () {
    expect(
      refine(
        'welcome to subscribe',
        isFinal: true,
        backend: SttBackend.iosSpeechToText,
      ),
      'welcome to SenScribe',
    );
  });

  test('this is subscribe becomes this is SenScribe', () {
    expect(
      refine(
        'this is subscribe',
        isFinal: true,
        backend: SttBackend.iosSpeechToText,
      ),
      'this is SenScribe',
    );
  });

  test('subscribe is an app becomes SenScribe is an app', () {
    expect(
      refine(
        'subscribe is an app',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'SenScribe is an app',
    );
  });

  test('please subscribe to the channel stays unchanged', () {
    expect(
      refine(
        'please subscribe to the channel',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'please subscribe to the channel',
    );
  });

  test('like and subscribe stays unchanged', () {
    expect(
      refine(
        'like and subscribe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'like and subscribe',
    );
  });

  test('please subscribe stays unchanged', () {
    expect(
      refine(
        'please subscribe',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'please subscribe',
    );
  });

  test('subscription settings stays unchanged', () {
    expect(
      refine(
        'subscription settings',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'subscription settings',
    );
  });

  test('iOS alternates can upgrade subscribe into SenScribe', () {
    expect(
      refine(
        'subscribe',
        isFinal: false,
        backend: SttBackend.iosSpeechToText,
        alternates: const ['subscribe', 'sense scribe'],
      ),
      'SenScribe',
    );
  });

  test('user trigger word refinement still runs after brand correction',
      () async {
    await triggerWordService.saveTriggerWords(
      const [
        TriggerWord(word: 'Start Page'),
      ],
    );

    expect(
      refine(
        'open sense scribe start page',
        isFinal: true,
        backend: SttBackend.androidOfflineVosk,
      ),
      'open SenScribe Start Page',
    );
  });
}
