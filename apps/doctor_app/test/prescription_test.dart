import 'dart:convert';

import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/consultation/prescription_writer.dart';
import 'package:care_companion_doctor/models/clinical.dart';
import 'package:care_companion_doctor/models/prescription.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

const _item = RxItem(
  drugName: 'Amoxicillin',
  strength: '500mg',
  dose: '1',
  frequency: '1-0-1',
  durationDays: 5,
  times: ['08:00', '20:00'],
);
const _major = RxWarning(severity: 'major', type: 'allergy', drugs: ['Amoxicillin'], message: 'Penicillin allergy');
const _moderate = RxWarning(severity: 'moderate', type: 'interaction', drugs: ['A', 'B'], message: 'Monitor');

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('RxGate', () {
    test('no warnings: valid items can be sent', () {
      const g = RxGate(items: [_item], warnings: []);
      expect(g.canSubmit, isTrue);
      expect(g.overrideFields, isEmpty);
    });

    test('moderate warnings do not block', () {
      expect(const RxGate(items: [_item], warnings: [_moderate]).canSubmit, isTrue);
    });

    test('major warning blocks until acknowledged AND a reason is given', () {
      expect(const RxGate(items: [_item], warnings: [_major]).canSubmit, isFalse);
      expect(const RxGate(items: [_item], warnings: [_major], acknowledged: true).canSubmit, isFalse);
      expect(const RxGate(items: [_item], warnings: [_major], overrideReason: 'benefit outweighs').canSubmit, isFalse);
      expect(
        const RxGate(items: [_item], warnings: [_major], acknowledged: true, overrideReason: 'ok').canSubmit,
        isFalse,
        reason: 'reason too short',
      );
      const g = RxGate(
        items: [_item],
        warnings: [_major],
        acknowledged: true,
        overrideReason: 'Desensitised, supervised',
      );
      expect(g.canSubmit, isTrue);
      expect(g.overrideFields, {'acknowledgedWarnings': true, 'overrideReason': 'Desensitised, supervised'});
    });

    test('empty, invalid or still-checking prescriptions cannot be sent', () {
      expect(const RxGate(items: [], warnings: []).canSubmit, isFalse);
      const bad = RxItem(drugName: 'X', dose: '1', frequency: 'OD', durationDays: 0);
      expect(const RxGate(items: [bad], warnings: []).canSubmit, isFalse);
      const badTime = RxItem(drugName: 'X', dose: '1', frequency: 'OD', durationDays: 3, times: ['8am']);
      expect(badTime.isValid, isFalse);
      expect(const RxGate(items: [_item], warnings: [], checking: true).canSubmit, isFalse);
    });

    test('check result sorts warnings by severity', () {
      final r = RxCheckResult.fromJson({
        'warnings': [
          {'severity': 'info', 'type': 'dose_form', 'drugs': [], 'message': 'i'},
          {'severity': 'major', 'type': 'interaction', 'drugs': [], 'message': 'm'},
          {'severity': 'moderate', 'type': 'interaction', 'drugs': [], 'message': 'o'},
        ],
        'knowledgePack': {'version': 'interactions-fixture-0.1', 'status': 'fixture_unapproved'},
      });
      expect(r.warnings.map((w) => w.severity), ['major', 'moderate', 'info']);
      expect(r.packVersion, 'interactions-fixture-0.1');
    });
  });

  testWidgets('writer: live check shows a major badge and gates sending until ack + reason', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final b = mockBackend((req, path) {
      if (path == '/clinician/prescriptions/check') {
        return {
          'warnings': [
            {
              'severity': 'major',
              'type': 'allergy',
              'drugs': ['Amoxicillin'],
              'message': 'Patient is allergic to penicillin',
              'source': 'class map',
            },
          ],
          'knowledgePack': {'version': 'interactions-fixture-0.1', 'status': 'fixture_unapproved'},
        };
      }
      return null;
    });
    final appt = Appointment.fromJson(queueItem(status: 'in_progress'));
    await tester.pumpWidget(
      testApp(PrescriptionWriter(appointment: appt), overrides: commonOverrides(b.client), scaffold: false),
    );
    await tester.pumpAndSettle();

    FilledButton submit() => tester.widget<FilledButton>(find.byKey(const Key('rxSubmit')));
    expect(submit().onPressed, isNull, reason: 'no items yet');

    await tester.tap(find.byKey(const Key('rxAddItem')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rxDrug')), 'Amoxicillin');
    await tester.enterText(find.byKey(const Key('rxStrength')), '500mg');
    await tester.enterText(find.byKey(const Key('rxFrequency')), '1-0-1');
    await tester.enterText(find.byKey(const Key('rxTimes')), '08:00, 20:00');
    await tester.tap(find.byKey(const Key('rxItemSave')));
    await tester.pumpAndSettle();
    // Debounced live check.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final check = b.requests.firstWhere((r) => r.url.path.endsWith('/prescriptions/check'));
    final body = jsonDecode(check.body) as Map;
    expect(body['patientId'], 'pat-1');
    expect((body['items'] as List).single, {'drugName': 'Amoxicillin', 'strength': '500mg'});

    expect(find.byKey(const Key('rxWarning.major')), findsOneWidget);
    expect(find.text('Major'), findsOneWidget);
    expect(find.byKey(const Key('rxOverride')), findsOneWidget);
    expect(submit().onPressed, isNull, reason: 'major warning not acknowledged');

    await tester.tap(find.byKey(const Key('rxAck')));
    await tester.pump();
    expect(submit().onPressed, isNull, reason: 'reason still missing');
    await tester.enterText(find.byKey(const Key('rxReason')), 'Tolerated previously under supervision');
    await tester.pump();
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('warnings panel: severities are labelled with text, not colour alone', (tester) async {
    await tester.pumpWidget(
      testApp(
        const SingleChildScrollView(
          child: RxWarningsPanel(warnings: [_major, _moderate], checking: false, hasItems: true),
        ),
      ),
    );
    expect(find.text('Major'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('Allergy'), findsOneWidget);
    expect(find.text('Interaction'), findsOneWidget);
  });
}
