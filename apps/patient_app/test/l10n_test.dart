import 'package:care_companion_patient/features/shell/app_shell.dart';
import 'package:care_companion_patient/models/auth.dart';
import 'package:care_companion_patient/router.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  testWidgets('switching locale updates UI strings live (en → hi → te) and persists', (tester) async {
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(
      Scaffold(body: const SizedBox.expand(), bottomNavigationBar: CcBottomNav(index: 0, onTap: (_) {})),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ask AI'), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(CcBottomNav)));
    await container.read(localeProvider.notifier).set('hi');
    await tester.pumpAndSettle();
    expect(find.text('होम'), findsOneWidget);
    expect(find.text('एआई से पूछें'), findsOneWidget);
    expect(find.text('Home'), findsNothing);

    await container.read(localeProvider.notifier).set('te');
    await tester.pumpAndSettle();
    expect(find.text('హోమ్'), findsOneWidget);
    expect(find.text('రికార్డులు'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cc_locale'), 'te');

    // Unsupported codes are ignored.
    await container.read(localeProvider.notifier).set('fr');
    await tester.pumpAndSettle();
    expect(find.text('హోమ్'), findsOneWidget);
  });

  group('router redirect', () {
    Me me(bool complete) => Me(
          id: 'u',
          phone: '+91',
          name: complete ? 'A' : null,
          email: null,
          roles: const ['patient'],
          language: 'en',
          selfPatientId: 'p',
          onboardingComplete: complete,
          mfaRequired: false,
          providerId: null,
        );

    test('unauthenticated users go to language select or phone', () {
      const s = SessionState(AuthStatus.unauthenticated);
      expect(appRedirect(session: s, languageChosen: false, location: '/home'), '/welcome/language');
      expect(appRedirect(session: s, languageChosen: true, location: '/home'), '/auth/phone');
      expect(appRedirect(session: s, languageChosen: true, location: '/auth/otp'), isNull);
    });

    test('incomplete onboarding is forced through onboarding', () {
      final s = SessionState(AuthStatus.authenticated, me(false));
      expect(appRedirect(session: s, languageChosen: true, location: '/home'), '/onboarding/consents');
      expect(appRedirect(session: s, languageChosen: true, location: '/onboarding/profile'), isNull);
    });

    test('signed-in users skip auth screens', () {
      final s = SessionState(AuthStatus.authenticated, me(true));
      expect(appRedirect(session: s, languageChosen: true, location: '/auth/phone'), '/home');
      expect(appRedirect(session: s, languageChosen: true, location: '/doctors'), isNull);
      expect(appRedirect(session: s, languageChosen: true, location: '/onboarding/emergency'), isNull);
    });
  });
}
