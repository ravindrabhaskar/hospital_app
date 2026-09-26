import 'package:care_companion_provider/features/visits/domain/vitals_validation.dart';
import 'package:care_companion_provider/features/visits/ui/vitals_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('VitalsValidator.validateField', () {
    test('empty is allowed (all vitals optional)', () {
      expect(VitalsValidator.validateField(VitalSpecs.pulse, ''), isNull);
      expect(VitalsValidator.validateField(VitalSpecs.pulse, '   '), isNull);
    });

    test('non-numeric input is rejected', () {
      expect(VitalsValidator.validateField(VitalSpecs.pulse, 'abc')!.kind, VitalErrorKind.notANumber);
      expect(VitalsValidator.validateField(VitalSpecs.pulse, '7.2.1')!.kind, VitalErrorKind.notANumber);
      expect(VitalsValidator.validateField(VitalSpecs.pulse, '-5')!.kind, VitalErrorKind.notANumber);
    });

    test('integer vitals reject decimals; decimal vitals allow one place', () {
      expect(VitalsValidator.validateField(VitalSpecs.spo2, '97.5')!.kind, VitalErrorKind.notANumber);
      expect(VitalsValidator.validateField(VitalSpecs.temperature, '37.2'), isNull);
      expect(VitalsValidator.validateField(VitalSpecs.temperature, '37,2'), isNull, reason: 'comma decimal');
      expect(VitalsValidator.validateField(VitalSpecs.temperature, '37.25')!.kind, VitalErrorKind.notANumber);
      expect(VitalsValidator.validateField(VitalSpecs.weight, '62.4'), isNull);
    });

    test('values outside plausible physical ranges are rejected', () {
      expect(VitalsValidator.validateField(VitalSpecs.spo2, '101')!.kind, VitalErrorKind.outOfRange);
      expect(VitalsValidator.validateField(VitalSpecs.spo2, '100'), isNull);
      expect(VitalsValidator.validateField(VitalSpecs.pulse, '400')!.kind, VitalErrorKind.outOfRange);
      expect(VitalsValidator.validateField(VitalSpecs.temperature, '98.6')!.kind, VitalErrorKind.outOfRange,
          reason: 'Fahrenheit typed into a Celsius field');
      expect(VitalsValidator.validateField(VitalSpecs.bpSystolic, '1200')!.kind, VitalErrorKind.outOfRange);
      expect(VitalsValidator.validateField(VitalSpecs.respiratoryRate, '2')!.kind, VitalErrorKind.outOfRange);
      expect(VitalsValidator.validateField(VitalSpecs.bloodGlucose, '140'), isNull);
    });
  });

  group('VitalsValidator.validate (form)', () {
    test('nothing entered -> form error', () {
      final r = VitalsValidator.validate({});
      expect(r.isValid, isFalse);
      expect(r.formError!.kind, VitalErrorKind.empty);
    });

    test('blood pressure must be entered as a pair', () {
      final r = VitalsValidator.validate({'bp_systolic': '130'});
      expect(r.fieldErrors['bp_diastolic']!.kind, VitalErrorKind.bpPairRequired);
    });

    test('diastolic must be lower than systolic', () {
      final r = VitalsValidator.validate({'bp_systolic': '80', 'bp_diastolic': '90'});
      expect(r.fieldErrors['bp_diastolic']!.kind, VitalErrorKind.bpOrder);
    });

    test('valid input builds the contract request body with units and measuredAt', () {
      final r = VitalsValidator.validate({
        'bp_systolic': '132',
        'bp_diastolic': '84',
        'pulse': '76',
        'spo2': '97',
        'temperature': '37.1',
        'blood_glucose': '',
      });
      expect(r.isValid, isTrue);
      final body = VitalsValidator.toRequestBody(r.values, DateTime.utc(2026, 9, 26, 10));
      final m = body['measurements'] as List;
      expect(m, hasLength(5));
      expect(m.first, {'type': 'bp_systolic', 'value': 132, 'unit': 'mmHg', 'measuredAt': '2026-09-26T10:00:00.000Z'});
      expect(m.firstWhere((e) => e['type'] == 'temperature')['value'], 37.1);
      expect(m.map((e) => e['type']), isNot(contains('blood_glucose')));
    });
  });

  group('VitalsForm widget', () {
    testWidgets('shows range error and does not submit invalid values', (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(testApp(VitalsForm(onSubmit: (b) async {
        submitted = b;
        return true;
      })));

      await tester.enterText(find.byKey(const Key('vital.spo2')), '120');
      await tester.ensureVisible(find.byKey(const Key('vitalsSave')));
      await tester.tap(find.byKey(const Key('vitalsSave')));
      await tester.pump();

      expect(find.text('Must be between 50 and 100'), findsOneWidget);
      expect(submitted, isNull);
    });

    testWidgets('empty form shows a form-level error', (tester) async {
      await tester.pumpWidget(testApp(VitalsForm(onSubmit: (_) async => true)));
      await tester.ensureVisible(find.byKey(const Key('vitalsSave')));
      await tester.tap(find.byKey(const Key('vitalsSave')));
      await tester.pump();
      expect(find.byKey(const Key('vitalsFormError')), findsOneWidget);
    });

    testWidgets('valid values are submitted and the form clears', (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(testApp(VitalsForm(
        clock: () => DateTime.utc(2026, 9, 26, 10),
        onSubmit: (b) async {
          submitted = b;
          return true;
        },
      )));
      await tester.enterText(find.byKey(const Key('vital.pulse')), '72');
      await tester.enterText(find.byKey(const Key('vital.temperature')), '36.8');
      await tester.ensureVisible(find.byKey(const Key('vitalsSave')));
      await tester.tap(find.byKey(const Key('vitalsSave')));
      await tester.pump();

      expect((submitted!['measurements'] as List).map((m) => m['type']), ['pulse', 'temperature']);
      expect(find.text('72'), findsNothing);
    });
  });
}
