import 'package:care_companion_doctor/core/api/api_exception.dart';
import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/features/auth/login_screen.dart';
import 'package:care_companion_doctor/features/patients/patient_detail_screen.dart';
import 'package:care_companion_doctor/features/patients/snapshot_view.dart';
import 'package:care_companion_doctor/l10n/gen/app_localizations.dart';
import 'package:care_companion_doctor/models/clinical.dart';
import 'package:care_companion_doctor/ui/l10n_helpers.dart';
import 'package:care_companion_doctor/ui/vital_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

ApiException _err(int status, String code, [String message = 'err', Map<String, dynamic> details = const {}]) =>
    ApiException(statusCode: status, code: code, message: message, details: details);

Vital _vital(String type, num value, String unit, {String id = 'v'}) => Vital.fromJson({
  'id': '$id-$type',
  'type': type,
  'value': value,
  'unit': unit,
  'measuredAt': '2026-10-05T08:00:00.000Z',
});

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('OTP error mapping (B6)', () {
    test('wrong OTP is "Incorrect code" with attempts left, not "session expired"', () {
      final e = _err(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 4});
      expect(otpErrorMessage(l, e), 'Incorrect code. 4 attempts left.');
      expect(otpErrorMessage(l, _err(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 1})),
          'Incorrect code. 1 attempt left.');
      expect(otpErrorMessage(l, _err(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 0})),
          l.otpNoAttemptsLeft);
      expect(otpErrorMessage(l, _err(401, 'UNAUTHENTICATED', 'Incorrect OTP')), l.otpIncorrect);
      expect(otpErrorMessage(l, e), isNot(l.errorSessionExpired));
    });

    test('expired / locked codes and other errors', () {
      expect(otpErrorMessage(l, _err(401, 'UNAUTHENTICATED', 'OTP expired or not requested')), l.otpExpired);
      expect(otpErrorMessage(l, _err(429, 'RATE_LIMITED')), l.otpTooManyAttempts);
      expect(otpErrorMessage(l, const ApiException.network()), l.errorNetwork);
    });

    test('authenticated calls still say "session expired" on 401', () {
      expect(errorMessage(l, _err(401, 'UNAUTHENTICATED')), l.errorSessionExpired);
    });

    testWidgets('login screen shows the incorrect-code message after a wrong OTP', (tester) async {
      final b = mockBackend((req, path) {
        if (path == '/auth/otp/request') return {'requestId': 'r1', 'expiresAt': '2026-10-06T10:00:00.000Z'};
        if (path == '/auth/otp/verify') {
          return errorResponse(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 4});
        }
        if (path == '/config/public') return {};
        return null;
      });
      await tester.pumpWidget(testApp(const LoginScreen(), overrides: commonOverrides(b.client), scaffold: false));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('phoneField')), '9800000101');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('otpField')), '111111');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect code. 4 attempts left.'), findsOneWidget);
      expect(find.text(l.errorSessionExpired), findsNothing);
    });
  });

  group('vital flags (B8)', () {
    test('QA readings are flagged', () {
      expect(vitalFlag('bp_systolic', 185, unit: 'mmHg'), VitalFlag.high);
      expect(vitalFlag('bp_diastolic', 115, unit: 'mmHg'), VitalFlag.high);
      expect(vitalFlag('spo2', 89, unit: '%'), VitalFlag.low);
      expect(vitalFlag('temperature', 39.5, unit: '°C'), VitalFlag.high);
      expect(vitalFlag('pulse', 120, unit: 'bpm'), VitalFlag.high);
    });

    test('normal readings and types without a range are not flagged', () {
      expect(vitalFlag('bp_systolic', 120, unit: 'mmHg'), isNull);
      expect(vitalFlag('bp_diastolic', 80, unit: 'mmHg'), isNull);
      expect(vitalFlag('spo2', 98, unit: '%'), isNull);
      expect(vitalFlag('temperature', 36.8, unit: '°C'), isNull);
      expect(vitalFlag('pulse', 72, unit: 'bpm'), isNull);
      expect(vitalFlag('weight', 140, unit: 'kg'), isNull);
    });

    test('units: Fahrenheit temperature and mmol/L glucose', () {
      expect(vitalFlag('temperature', 98.6, unit: '°F'), isNull);
      expect(vitalFlag('temperature', 103, unit: 'F'), VitalFlag.high);
      expect(vitalFlag('temperature', 103, unit: ''), VitalFlag.high);
      expect(vitalFlag('pulse', 45, unit: 'bpm'), VitalFlag.low);
      expect(vitalFlag('blood_glucose', 250, unit: 'mg/dL'), VitalFlag.high);
      expect(vitalFlag('blood_glucose', 6, unit: 'mmol/L'), isNull);
      expect(vitalFlag('blood_glucose', 3, unit: 'mmol/L'), VitalFlag.low);
    });

    testWidgets('snapshot tiles highlight out-of-range values', (tester) async {
      final j = snapshotJson();
      j['recentVitals'] = [
        {'id': 'a', 'type': 'bp_systolic', 'value': 185, 'unit': 'mmHg', 'measuredAt': '2026-10-05T08:00:00.000Z'},
        {'id': 'b', 'type': 'spo2', 'value': 89, 'unit': '%', 'measuredAt': '2026-10-05T08:00:00.000Z'},
        {'id': 'c', 'type': 'pulse', 'value': 72, 'unit': 'bpm', 'measuredAt': '2026-10-05T08:00:00.000Z'},
      ];
      await tester.pumpWidget(
        testApp(SingleChildScrollView(child: SnapshotSummary(snapshot: ClinicalSnapshot.fromJson(j)))),
      );
      BoxDecoration deco(String type) =>
          tester.widget<Container>(find.byKey(Key('vitalTile.$type'))).decoration! as BoxDecoration;
      expect(deco('bp_systolic').color, AppColors.dangerBg);
      expect(deco('spo2').color, AppColors.dangerBg);
      expect(deco('pulse').color, AppColors.mint50);
      expect(find.descendant(of: find.byKey(const Key('vitalTile.bp_systolic')), matching: find.text('High')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('vitalTile.spo2')), matching: find.text('Low')),
          findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('trend card flags the latest reading and pluralizes "1 reading"', (tester) async {
      await tester.pumpWidget(testApp(VitalTrendCard(type: 'temperature', readings: [_vital('temperature', 39.5, '°C')])));
      expect(find.text('High'), findsOneWidget);
      expect(find.textContaining('1 reading'), findsOneWidget);
      expect(find.textContaining('1 readings'), findsNothing);
    });
  });

  test('specialty codes get human labels (B29)', () {
    expect(specialtyLabel(l, 'general_physician'), 'General Physician');
    expect(specialtyLabel(l, 'ent'), 'ENT Specialist');
    expect(specialtyLabel(l, 'sports_medicine'), 'Sports medicine');
    final hi = lookupAppLocalizations(const Locale('hi'));
    expect(specialtyLabel(hi, 'general_physician'), isNot('general_physician'));
    expect(l.readingsCount(1), '1 reading');
    expect(l.readingsCount(3), '3 readings');
  });

  test('disabled filled buttons use the legible theme colours (B26)', () {
    final style = buildAppTheme().filledButtonTheme.style!;
    const disabled = {WidgetState.disabled};
    expect(style.backgroundColor!.resolve(disabled), AppColors.disabledBg);
    expect(style.foregroundColor!.resolve(disabled), AppColors.disabledFg);
    expect(style.backgroundColor!.resolve(const {}), AppColors.primary);
  });
}
