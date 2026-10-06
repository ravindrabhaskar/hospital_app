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

  group('B8: VitalRanges (usual adult reference ranges)', () {
    test('QA values are flagged: BP 185/115, SpO2 89, temp 39.5, pulse 120', () {
      expect(VitalRanges.flag('bp_systolic', 185), VitalFlag.high);
      expect(VitalRanges.flag('bp_diastolic', 115), VitalFlag.high);
      expect(VitalRanges.flag('spo2', 89), VitalFlag.low);
      expect(VitalRanges.flag('temperature', 39.5), VitalFlag.high);
      expect(VitalRanges.flag('pulse', 120), VitalFlag.high);
    });

    test('normal values are not flagged; boundaries are inclusive', () {
      for (final (type, value) in [
        ('bp_systolic', 120),
        ('bp_systolic', 139),
        ('bp_systolic', 90),
        ('bp_diastolic', 80),
        ('pulse', 72),
        ('spo2', 98),
        ('spo2', 95),
        ('spo2', 100),
        ('temperature', 36.8),
        ('blood_glucose', 110),
        ('respiratory_rate', 16),
        ('weight', 300),
      ]) {
        expect(VitalRanges.flag(type, value), isNull, reason: '$type $value');
      }
    });

    test('low values are flagged', () {
      expect(VitalRanges.flag('bp_systolic', 85), VitalFlag.low);
      expect(VitalRanges.flag('pulse', 40), VitalFlag.low);
      expect(VitalRanges.flag('temperature', 34.5), VitalFlag.low);
      expect(VitalRanges.flag('blood_glucose', 55), VitalFlag.low);
      expect(VitalRanges.flag('respiratory_rate', 8), VitalFlag.low);
      expect(VitalRanges.flag('unknown', 1), isNull);
    });

    test('flagRaw ignores empty and invalid input (impossible values stay validation errors)', () {
      expect(VitalRanges.flagRaw(VitalSpecs.pulse, ''), isNull);
      expect(VitalRanges.flagRaw(VitalSpecs.pulse, 'abc'), isNull);
      expect(VitalRanges.flagRaw(VitalSpecs.pulse, '400'), isNull);
      expect(VitalsValidator.validateField(VitalSpecs.pulse, '400')!.kind, VitalErrorKind.outOfRange);
      expect(VitalRanges.flagRaw(VitalSpecs.temperature, '39,5'), VitalFlag.high);
    });
  });

  group('B8: VitalsForm highlighting', () {
    testWidgets('abnormal values show High/Low with icon and range; normal values do not', (tester) async {
      Map<String, dynamic>? submitted;
      await tester.pumpWidget(testApp(VitalsForm(onSubmit: (b) async {
        submitted = b;
        return true;
      })));
      await tester.enterText(find.byKey(const Key('vital.bp_systolic')), '185');
      await tester.enterText(find.byKey(const Key('vital.bp_diastolic')), '115');
      await tester.enterText(find.byKey(const Key('vital.spo2')), '89');
      await tester.enterText(find.byKey(const Key('vital.pulse')), '72');
      await tester.pump();

      expect(find.byKey(const Key('vitalFlag.bp_systolic')), findsOneWidget);
      expect(find.byKey(const Key('vitalFlag.bp_diastolic')), findsOneWidget);
      expect(find.byKey(const Key('vitalFlag.spo2')), findsOneWidget);
      expect(find.byKey(const Key('vitalFlag.pulse')), findsNothing);
      expect(find.text('High · usual adult range 90–139 mmHg'), findsOneWidget);
      expect(find.text('Low · usual adult range ≥ 95 %'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(3));

      // Highlighting does not block saving plausible values.
      await tester.ensureVisible(find.byKey(const Key('vitalsSave')));
      await tester.tap(find.byKey(const Key('vitalsSave')));
      await tester.pump();
      expect((submitted!['measurements'] as List).length, 4);
    });

    testWidgets('fixing the value clears the highlight', (tester) async {
      await tester.pumpWidget(testApp(VitalsForm(onSubmit: (_) async => true)));
      await tester.enterText(find.byKey(const Key('vital.temperature')), '39.5');
      await tester.pump();
      expect(find.byKey(const Key('vitalFlag.temperature')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('vital.temperature')), '36.9');
      await tester.pump();
      expect(find.byKey(const Key('vitalFlag.temperature')), findsNothing);
    });

    testWidgets('badge reads High / Low in Hindi too', (tester) async {
      await tester.pumpWidget(testApp(const VitalFlagBadge(flag: VitalFlag.high), locale: const Locale('hi')));
      expect(find.text('अधिक'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });
  });
}
