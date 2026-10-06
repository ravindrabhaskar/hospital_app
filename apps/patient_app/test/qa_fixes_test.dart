// Regression tests for the QA round of 2026-10-05 (docs/qa/TEST_RESULTS_2026-10-05.md §9).
import 'package:care_companion_patient/core/api/api_exception.dart';
import 'package:care_companion_patient/core/utils/format.dart';
import 'package:care_companion_patient/core/utils/permissions.dart';
import 'package:care_companion_patient/core/widgets/common.dart';
import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/ai/ask_ai_screen.dart';
import 'package:care_companion_patient/features/care/dose_display.dart';
import 'package:care_companion_patient/features/lab/lab_screens.dart';
import 'package:care_companion_patient/features/onboarding/otp_screen.dart';
import 'package:care_companion_patient/features/shell/app_shell.dart';
import 'package:care_companion_patient/l10n/app_localizations.dart';
import 'package:care_companion_patient/models/auth.dart';
import 'package:care_companion_patient/models/care.dart';
import 'package:care_companion_patient/models/services.dart';
import 'package:care_companion_patient/router.dart';
import 'package:care_companion_patient/features/onboarding/onboarding_resume.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:care_companion_patient/state/v13_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _CountingAuthRepository extends AuthRepository {
  _CountingAuthRepository() : super(deadApiClient());
  int verifyCalls = 0;
  int requestCalls = 0;

  @override
  Future<AuthSession> verifyOtp(String phone, String otp, {String? deviceName}) async {
    verifyCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw ApiException(code: 'VALIDATION_ERROR', message: 'wrong code');
  }

  @override
  Future<OtpRequestResult> requestOtp(String phone) async {
    requestCalls++;
    return OtpRequestResult(requestId: 'r2', devOtp: '654321');
  }
}

LabOrder labOrder({String status = 'scheduled'}) => LabOrder.fromJson({
      'id': 'lo1',
      'patientId': 'p-self',
      'patientName': 'Vaibhav',
      'tests': [
        {'id': 't1', 'name': 'HbA1c'},
        {'id': 't2', 'name': 'Lipid profile'},
      ],
      'total': 1798,
      'discount': 179,
      'status': status,
      'partnerName': 'Partner Labs',
      'timeline': [
        {'status': 'pending_payment', 'at': '2026-10-05T09:00:00.000Z'},
      ],
    });

void main() {
  group('B17 lab order totals', () {
    test('amount due is the subtotal minus the coupon', () {
      final o = labOrder();
      expect(o.subtotal, 1798);
      expect(o.amountDue, 1619);
    });

    testWidgets('order detail shows subtotal, discount and the amount paid', (tester) async {
      useTallPhone(tester);
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const LabOrderScreen(id: 'lo1'), overrides: [
        ...overrides,
        labOrderProvider.overrideWith((ref, id) async => labOrder()),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text(money(1798)), findsOneWidget);
      expect(find.text('−${money(179)}'), findsOneWidget);
      expect(find.text('Amount paid'), findsOneWidget);
      expect(find.text(money(1619)), findsOneWidget);
      expect(find.text('Total amount'), findsNothing);
    });
  });

  group('B23 OTP verify', () {
    testWidgets('auto-submit plus a Verify tap sends one request; the rejected code is not re-sent',
        (tester) async {
      final repo = _CountingAuthRepository();
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const OtpScreen(phone: '+919800000001'), overrides: [
        ...overrides,
        authRepositoryProvider.overrideWithValue(repo),
      ]));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '111111'); // auto-submits
      await tester.tap(find.byKey(const Key('otp-verify')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(repo.verifyCalls, 1);
      expect(find.text('That code is not correct or has expired'), findsWidgets);

      // Tapping Verify again with the same rejected code does not burn an attempt.
      await tester.tap(find.byKey(const Key('otp-verify')));
      await tester.pumpAndSettle();
      expect(repo.verifyCalls, 1);

      // Resend clears the stale error and the old code.
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(repo.requestCalls, 1);
      expect(find.text('That code is not correct or has expired'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });
  });

  group('B10 Ask AI localisation', () {
    testWidgets('server chips show translated labels', (tester) async {
      late AppLocalizations hi;
      await tester.pumpWidget(Localizations(
        locale: const Locale('hi'),
        delegates: AppLocalizations.localizationsDelegates,
        child: Builder(builder: (c) {
          hi = AppLocalizations.of(c);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      expect(localizedQuickReply(hi, 'Fever'), 'बुखार');
      expect(localizedQuickReply(hi, 'Headache'), 'सिरदर्द');
      expect(localizedQuickReply(hi, 'Something new'), 'Something new');
      expect(hi.aiGreeting, startsWith('नमस्ते'));
    });
  });

  group('B13 picker permissions', () {
    test('camera/photo denials are recognised; other errors are generic', () {
      expect(pickerDenial(PlatformException(code: 'camera_access_denied')), PickerDenial.camera);
      expect(pickerDenial(PlatformException(code: 'photo_access_denied')), PickerDenial.photos);
      expect(pickerDenial(PlatformException(code: 'no_available_camera')), isNull);
      expect(pickerDenial(Exception('x')), isNull);
    });

    testWidgets('denied camera shows a specific message with Open settings', (tester) async {
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showPickerError(c, PlatformException(code: 'camera_access_denied')),
              child: const Text('go'),
            ),
          ),
        ),
        overrides: overrides,
      ));
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(find.textContaining('Camera permission is off'), findsOneWidget);
      expect(find.byKey(const Key('open-app-settings')), findsOneWidget);
      expect(find.text('Could not open the file. Please try again.'), findsNothing);
    });
  });

  group('B18 doses before a medicine was added', () {
    Reminder dose(DateTime at, String status) => Reminder(
        id: 'medication:m1:08:00',
        kind: 'medication',
        title: 'Metformin 500 mg',
        subtitle: null,
        at: at,
        status: status,
        refId: 'm1');

    test('an 08:00 dose is not "missed" for a medicine added at 17:40', () {
      final added = DateTime(2026, 10, 5, 17, 40);
      final morning = dose(DateTime(2026, 10, 5, 8), 'missed');
      final evening = dose(DateTime(2026, 10, 5, 20), 'pending');
      expect(visibleReminders([morning, evening], {'m1': added}), [evening]);
      // Without a known add time the server status is shown as is.
      expect(visibleReminders([morning], const {}), [morning]);
      // A dose the user logged is always kept.
      expect(isPreAddMissedDose('taken', DateTime(2026, 10, 5, 8), added), isFalse);
    });
  });

  group('B21 word-only wrapping', () {
    testWidgets('a long word scales down instead of breaking', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 60,
              child: WordWrapLabel('Online Consultation', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('Online Consultation'));
      expect(text.style!.fontSize, lessThan(12));
      // The widest word now fits on one line.
      final tp = TextPainter(
        text: TextSpan(text: 'Consultation', style: text.style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1.3),
      )..layout();
      expect(tp.width, lessThanOrEqualTo(60));
    });
  });

  group('B30 onboarding resume', () {
    test('a reload after the profile step resumes the optional steps', () {
      final s = SessionState(AuthStatus.authenticated, testMe);
      expect(
          appRedirect(
              session: s, languageChosen: true, location: '/splash', onboardingResume: '/onboarding/emergency'),
          '/onboarding/emergency');
      expect(appRedirect(session: s, languageChosen: true, location: '/splash'), '/home');
      // Deep links elsewhere are not hijacked.
      expect(
          appRedirect(
              session: s, languageChosen: true, location: '/doctors', onboardingResume: '/onboarding/emergency'),
          isNull);
    });

    testWidgets('the resume step is per user and cleared on leaving onboarding', (tester) async {
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const SizedBox(), overrides: overrides));
      final c = ProviderScope.containerOf(tester.element(find.byType(SizedBox)));
      final n = c.read(onboardingResumeProvider.notifier);
      await n.set('u1', '/onboarding/invite');
      expect(n.routeFor('u1'), '/onboarding/invite');
      expect(n.routeFor('someone-else'), isNull);
      await n.set('u1', '/home');
      expect(n.routeFor('u1'), isNull);
      expect(c.read(sharedPrefsProvider).getString(OnboardingResume.key), isNull);
    });
  });

  testWidgets('B20 the selected bottom-nav item has the butter pill', (tester) async {
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(
      Scaffold(body: const SizedBox.expand(), bottomNavigationBar: CcBottomNav(index: 1, onTap: (_) {})),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();
    final pill = tester.widget<AnimatedContainer>(find.byKey(const Key('nav-indicator')));
    expect((pill.decoration as BoxDecoration).color, const Color(0xFFFFEC8E));
    expect(find.byKey(const Key('nav-indicator')), findsOneWidget);
  });
}
