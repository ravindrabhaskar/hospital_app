import 'package:care_companion_doctor/app.dart';
import 'package:care_companion_doctor/core/storage/key_value_store.dart';
import 'package:care_companion_doctor/core/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<List> boot(WidgetTester tester, Handler handler, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = MemoryKeyValueStore();
    if (signedIn) {
      await store.write(StoreKeys.accessToken, 'access-1');
      await store.write(StoreKeys.refreshToken, 'refresh-1');
    }
    final b = mockBackend(handler);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [...commonOverrides(b.client, store: store)],
        child: const DoctorApp(),
      ),
    );
    await tester.pumpAndSettle();
    return b.requests;
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('signed-out user sees the OTP login', (tester) async {
    await boot(tester, (req, path) => null, signedIn: false);
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('MFA_REQUIRED on the first data call routes to the MFA step', (tester) async {
    await boot(
      tester,
      (req, path) => switch (path) {
        '/me' => meJson(enrolled: true),
        '/doctor/me/profile' => errorResponse(403, 'MFA_REQUIRED', 'MFA'),
        _ => null,
      },
    );
    expect(find.byKey(const Key('mfaVerify')), findsOneWidget);
    expect(find.byKey(const Key('mfaSwitchMode')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mfaSwitchMode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mfaRecovery')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('verifying the TOTP code unlocks the app', (tester) async {
    var verified = false;
    await boot(tester, (req, path) {
      switch (path) {
        case '/me':
          return meJson(enrolled: true, verified: verified);
        case '/doctor/me/profile':
          return verified ? profileJson() : errorResponse(403, 'MFA_REQUIRED', 'MFA');
        case '/auth/mfa/verify':
          verified = true;
          return sessionJson();
        case '/clinician/queue':
          return {'items': [], 'nextCursor': null};
      }
      return null;
    });
    await tester.enterText(find.byKey(const Key('mfaCodeField')), '123456');
    await tester.tap(find.byKey(const Key('mfaSubmit')));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Dr. Ananya Rao'), findsOneWidget);
    expect(find.text('No consultations on this day.'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('a non-doctor account gets the "use the right app" screen', (tester) async {
    await boot(tester, (req, path) => path == '/me' ? meJson(roles: ['patient']) : null);
    expect(find.byKey(const Key('restrictedBody')), findsOneWidget);
    expect(find.textContaining('CareCompanion app for patients'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('provider accounts are pointed at the Pro app', (tester) async {
    await boot(tester, (req, path) => path == '/me' ? meJson(roles: ['provider']) : null);
    expect(find.textContaining('CareCompanion Pro'), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('force update: minAppVersion.doctorAndroid above the installed version blocks the app', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await boot(
      tester,
      (req, path) => switch (path) {
        '/config/public' => {
          'minAppVersion': {'doctorAndroid': '2.0.0'},
          'support': {'phone': '+911234'},
        },
        _ => null,
      },
      signedIn: false,
    );
    expect(find.byKey(const Key('updateBody')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await teardown(tester);
  });

  testWidgets('bottom navigation reaches Patients, Messages and More', (tester) async {
    await boot(
      tester,
      (req, path) => switch (path) {
        '/me' => meJson(verified: true),
        '/doctor/me/profile' => profileJson(),
        '/clinician/queue' => {'items': [], 'nextCursor': null},
        '/clinician/patients' => {
          'items': [
            {'id': 'pat-1', 'name': 'Ramesh Kumar', 'age': 68, 'gender': 'male'},
          ],
          'nextCursor': null,
        },
        '/inbox' => {'items': [], 'nextCursor': null},
        _ => null,
      },
    );
    await tester.tap(find.byKey(const Key('nav.patients')));
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav.messages')));
    await tester.pumpAndSettle();
    expect(find.text('No care-team conversations yet.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav.more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more.schedule')), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsOneWidget);
    await teardown(tester);
  });
}
