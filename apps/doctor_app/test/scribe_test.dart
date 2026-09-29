import 'package:care_companion_doctor/core/providers.dart';
import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/data/clinician_repository.dart';
import 'package:care_companion_doctor/features/common/audio_recorder.dart';
import 'package:care_companion_doctor/features/consultation/scribe_controller.dart';
import 'package:care_companion_doctor/features/consultation/scribe_screen.dart';
import 'package:care_companion_doctor/models/care.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class FakeRecorder implements ScribeRecorder {
  bool permission = true;
  int starts = 0;
  int cancels = 0;

  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<void> start() async => starts++;
  @override
  Future<RecordedAudio?> stop() async =>
      const RecordedAudio(bytes: [1, 2, 3, 4], filename: 'consultation.m4a', contentType: 'audio/mp4');
  @override
  Future<void> cancel() async => cancels++;
  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> _draft() => {
  'id': 'scr-1',
  'appointmentId': 'appt-1',
  'transcript': 'Doctor: How are you? Patient: headache for two days.',
  'draft': {
    'subjective': 'Headache x2 days',
    'objective': 'BP 150/95',
    'assessment': 'Review BP',
    'plan': 'Recheck in 1 week',
  },
  'model': 'test',
  'advisory': true,
  'generatedAt': '2026-09-29T05:00:00.000Z',
  'audioRetained': false,
};

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<(ScribeController, FakeRecorder, List)> make() async {
    final b = mockBackend((req, path) => path.endsWith('/scribe') ? _draft() : null);
    final api = await apiWith(b.client);
    final rec = FakeRecorder();
    final c = ScribeController(
      appointmentId: 'appt-1',
      repository: ClinicianRepository(api),
      recorderFactory: () => rec,
    );
    return (c, rec, b.requests);
  }

  test('without consent nothing is recorded or sent', () async {
    final (c, rec, requests) = await make();
    expect(c.canRecord, isFalse);
    await c.startRecording();
    expect(rec.starts, 0);
    expect(c.error, ScribeError.consentMissing);
    await c.generateFromTranscript('Doctor: hello there. Patient: I have a headache since yesterday.');
    expect(requests, isEmpty);
    expect(c.canGenerate('x' * 50), isFalse);
  });

  test('with consent: record -> stop uploads multipart audio with consentConfirmed=true', () async {
    final (c, rec, requests) = await make();
    await c.setConsent(true);
    await c.startRecording();
    expect(rec.starts, 1);
    expect(c.recording, isTrue);
    await c.stopAndTranscribe();
    expect(c.draft!.subjective, 'Headache x2 days');
    final req = requests.single;
    expect(req.url.path, endsWith('/clinician/appointments/appt-1/scribe'));
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    expect(req.body, contains('name="consentConfirmed"'));
    expect(req.body, contains('true'));
    expect(req.body, contains('name="audio"; filename="consultation.m4a"'));
  });

  test('typed transcript sends JSON with consentConfirmed', () async {
    final (c, _, requests) = await make();
    await c.setConsent(true);
    await c.generateFromTranscript('short');
    expect(c.error, ScribeError.emptyTranscript);
    await c.generateFromTranscript('Doctor: How are you? Patient: headache for two days.');
    expect(requests.single.body, contains('"consentConfirmed":true'));
    expect(c.draft, isNotNull);
  });

  test('withdrawing consent while recording discards the recording', () async {
    final (c, rec, requests) = await make();
    await c.setConsent(true);
    await c.startRecording();
    await c.setConsent(false);
    expect(rec.cancels, 1);
    expect(c.recording, isFalse);
    expect(requests, isEmpty);
  });

  test('denied microphone permission is reported', () async {
    final (c, rec, _) = await make();
    rec.permission = false;
    await c.setConsent(true);
    await c.startRecording();
    expect(c.error, ScribeError.micDenied);
    expect(rec.starts, 0);
  });

  test('SOAP formatting for "Insert into notes"', () {
    final d = ScribeDraft.fromJson({
      'id': 'x',
      'transcript': 't',
      'draft': {'subjective': 'sub', 'objective': ' ', 'assessment': 'ass', 'plan': ''},
    });
    final text = ScribeController.formatSoap(d, s: 'S', o: 'O', a: 'A', p: 'P');
    expect(text, 'S: sub\nA: ass');
  });

  testWidgets('screen: Record is disabled until consent is ticked; draft is AI-labelled', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final b = mockBackend((req, path) => path.endsWith('/scribe') ? _draft() : null);
    final rec = FakeRecorder();
    await tester.pumpWidget(
      testApp(
        const ScribeScreen(appointmentId: 'appt-1'),
        overrides: [...commonOverrides(b.client), audioRecorderProvider.overrideWithValue(() => rec)],
        scaffold: false,
      ),
    );
    await tester.pumpAndSettle();
    FilledButton record() => tester.widget<FilledButton>(find.byKey(const Key('scribeRecord')));
    expect(record().onPressed, isNull);
    await tester.tap(find.byKey(const Key('scribeConsent')));
    await tester.pump();
    expect(record().onPressed, isNotNull);
    await tester.enterText(
      find.byKey(const Key('scribeTranscript')),
      'Doctor: How are you? Patient: headache for two days.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('scribeGenerate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aiAdvisoryLabel')), findsOneWidget);
    expect(find.text('Headache x2 days'), findsOneWidget);
    expect(find.byKey(const Key('scribeInsert')), findsOneWidget);
  });
}
