import 'package:care_companion_doctor/data/auth_repository.dart';
import 'package:care_companion_doctor/features/auth/mfa_controller.dart';
import 'package:care_companion_doctor/features/auth/mfa_screen.dart';
import 'package:care_companion_doctor/core/theme.dart';
import 'package:care_companion_doctor/models/me.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(() => useGoogleFonts = false);

  Future<(MfaController, List<AuthSession>, List<String>)> make(Handler handler) async {
    final b = mockBackend(handler);
    final api = await apiWith(b.client);
    final verified = <AuthSession>[];
    final c = MfaController(repository: AuthRepository(api), onVerified: (s) async => verified.add(s));
    return (c, verified, b.requests.map((r) => r.url.path).toList());
  }

  final notEnrolled = Me.fromJson(meJson(enrolled: false));
  final enrolled = Me.fromJson(meJson(enrolled: true));

  test('enrol -> confirm -> recovery codes -> done with the verified session', () async {
    final (c, verified, _) = await make(
      (req, path) => switch (path) {
        '/auth/mfa/totp/enroll' => {
          'secret': 'JBSWY3DPEHPK3PXP',
          'otpauthUrl': 'otpauth://totp/CC?secret=JBSWY3DPEHPK3PXP',
          'qrSvg': '<svg/>',
        },
        '/auth/mfa/totp/confirm' => {'recoveryCodes': List.generate(10, (i) => 'CODE-$i'), 'session': sessionJson()},
        _ => null,
      },
    );
    await c.begin(notEnrolled);
    expect(c.step, MfaStep.enrol);
    expect(c.enrollment!.groupedSecret, 'JBSW Y3DP EHPK 3PXP');
    await c.confirmEnrolment('123456');
    expect(c.step, MfaStep.recoveryCodes);
    expect(c.recoveryCodes, hasLength(10));
    expect(verified, isEmpty, reason: 'not finished until the codes are acknowledged');
    await c.acknowledgeRecoveryCodes();
    expect(c.step, MfaStep.done);
    expect(verified.single.accessToken, 'access-2');
    expect(c.recoveryCodes, isEmpty, reason: 'codes are dropped from memory');
  });

  test('enrolled account goes straight to verify', () async {
    final (c, _, _) = await make((req, path) => null);
    await c.begin(enrolled);
    expect(c.step, MfaStep.verify);
  });

  test('enrol CONFLICT (already enrolled elsewhere) falls back to verify', () async {
    final (c, _, _) = await make((req, path) => errorResponse(409, 'CONFLICT', 'already'));
    await c.begin(notEnrolled);
    expect(c.step, MfaStep.verify);
  });

  test('wrong code reports attempts remaining; then RATE_LIMITED locks', () async {
    var n = 0;
    final (c, verified, _) = await make((req, path) {
      n++;
      return n == 1
          ? errorResponse(400, 'VALIDATION_ERROR', 'Incorrect code', {'attemptsRemaining': 3})
          : errorResponse(429, 'RATE_LIMITED', 'Too many');
    });
    await c.begin(enrolled);
    await c.verifyCode('000000');
    expect(c.error, MfaError.wrongCode);
    expect(c.attemptsRemaining, 3);
    expect(c.step, MfaStep.verify);
    await c.verifyCode('111111');
    expect(c.error, MfaError.locked);
    expect(verified, isEmpty);
  });

  test('bad format never calls the API', () async {
    final b = mockBackend((req, path) => sessionJson());
    final api = await apiWith(b.client);
    final c = MfaController(repository: AuthRepository(api), onVerified: (_) async {});
    await c.begin(enrolled);
    await c.verifyCode('12ab');
    expect(c.error, MfaError.invalidFormat);
    expect(b.requests, isEmpty);
  });

  test('recovery-code fallback verifies with {recoveryCode}', () async {
    final b = mockBackend((req, path) => path == '/auth/mfa/verify' ? sessionJson() : null);
    final api = await apiWith(b.client);
    final verified = <AuthSession>[];
    final c = MfaController(repository: AuthRepository(api), onVerified: (s) async => verified.add(s));
    await c.begin(enrolled);
    c.useRecoveryCode();
    expect(c.step, MfaStep.recovery);
    await c.verifyRecoveryCode('ABCD-1234');
    expect(c.step, MfaStep.done);
    expect(verified, hasLength(1));
    expect(b.requests.single.body, contains('"recoveryCode":"ABCD-1234"'));
    expect(b.requests.single.body, isNot(contains('"code"')));
  });

  test('verify on a not-enrolled account switches to enrolment', () async {
    final (c, _, _) = await make(
      (req, path) => switch (path) {
        '/auth/mfa/verify' => errorResponse(409, 'CONFLICT', 'not enrolled', {'enrolled': false}),
        '/auth/mfa/totp/enroll' => {'secret': 'AAAA', 'otpauthUrl': 'otpauth://totp/x'},
        _ => null,
      },
    );
    await c.begin(enrolled);
    await c.verifyCode('123456');
    expect(c.step, MfaStep.enrol);
  });

  testWidgets('recovery codes: Continue is disabled until "saved" is ticked', (tester) async {
    final (c, verified, _) = await make(
      (req, path) => switch (path) {
        '/auth/mfa/totp/enroll' => {'secret': 'JBSWY3DPEHPK3PXP', 'otpauthUrl': 'otpauth://totp/x'},
        '/auth/mfa/totp/confirm' => {
          'recoveryCodes': ['AAAA-1111', 'BBBB-2222'],
          'session': sessionJson(),
        },
        _ => null,
      },
    );
    await tester.pumpWidget(testApp(SingleChildScrollView(child: MfaStepView(controller: c))));
    await c.begin(notEnrolled);
    await tester.pump();
    expect(find.byKey(const Key('mfaEnrol')), findsOneWidget);
    expect(find.byKey(const Key('mfaOpenAuthenticator')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mfaCodeField')), '123456');
    await tester.tap(find.byKey(const Key('mfaSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('AAAA-1111'), findsOneWidget);
    final cont = find.byKey(const Key('mfaContinue'));
    expect(tester.widget<FilledButton>(cont).onPressed, isNull);
    await tester.tap(find.byKey(const Key('mfaSavedCheckbox')));
    await tester.pump();
    await tester.tap(cont);
    await tester.pump();
    expect(verified, hasLength(1));
    expect(c.step, MfaStep.done);
  });
}
