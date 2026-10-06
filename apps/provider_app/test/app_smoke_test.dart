import 'dart:convert';

import 'package:care_companion_provider/app.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:care_companion_provider/core/location_permission.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'verification_gate_test.dart' show me, providerMe;

/// Scriptable location permission (no platform plugin in tests).
class FakeLocationPermissions implements LocationPermissions {
  FakeLocationPermissions(this.state, {this.onRequest = LocationAccess.denied});
  LocationAccess state;
  LocationAccess onRequest;
  int requests = 0;

  @override
  Future<LocationAccess> check() async => state;

  @override
  Future<LocationAccess> request() async {
    requests++;
    return state = onRequest;
  }

  @override
  Future<bool> openSettings({bool locationService = false}) async => true;
}

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<(MemoryKeyValueStore, List<http.Request>)> boot(WidgetTester tester,
      {required String verification,
      List<String> roles = const ['provider'],
      List<Override> extra = const [],
      MemoryKeyValueStore? existingStore,
      List<String> capabilities = const []}) async {
    final store = existingStore ?? MemoryKeyValueStore();
    await store.write(StoreKeys.accessToken, 'a');
    await store.write(StoreKeys.refreshToken, 'r');
    final requests = <http.Request>[];
    var status = 'assigned';
    final client = MockClient((req) async {
      requests.add(req);
      final path = req.url.path.replaceFirst('/api/v1', '');
      Object? body;
      if (path == '/me') body = me(roles);
      if (path == '/provider/me') {
        body = providerMe(verification, expiresAt: DateTime.now().add(const Duration(days: 12)).toUtc().toIso8601String());
        if (capabilities.isNotEmpty) (body as Map<String, dynamic>)['capabilities'] = capabilities;
      }
      if (path == '/provider/visits') {
        body = {
          'items': req.url.queryParameters['scope'] == 'today' ? [visitJson(status: status)] : [],
          'nextCursor': null,
        };
      }
      if (path == '/home-visits/visit-1') body = visitJson(status: status);
      if (path == '/home-visits/visit-1/accept') {
        status = 'accepted';
        body = visitJson(status: status);
      }
      if (body == null) return http.Response('{"error":{"code":"NOT_FOUND","message":"nf"}}', 404);
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });

    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        httpClientProvider.overrideWithValue(client),
        connectivityProvider.overrideWithValue(FakeConnectivityService(online: true)),
        ...extra,
      ],
      child: const ProviderApp(),
    ));
    await tester.pumpAndSettle();
    return (store, requests);
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('verified provider: home -> visit detail -> accept (with Idempotency-Key)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final (_, requests) = await boot(tester, verification: 'verified');
    expect(find.text('Hello, Anil'), findsOneWidget);
    expect(find.text('Vitals Check'), findsOneWidget);
    expect(find.text('Hyderabad – 500001'), findsOneWidget);
    expect(find.text('12 MG Road, Hyderabad, 500001'), findsNothing, reason: 'address hidden on cards');

    await tester.tap(find.text('Vitals Check'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action.accept')), findsOneWidget);
    expect(find.byKey(const Key('areaOnly')), findsOneWidget, reason: 'full address hidden before accept');
    expect(find.text('Penicillin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('action.accept')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action.startTravel')), findsOneWidget);
    expect(find.byKey(const Key('fullAddress')), findsOneWidget);

    final accept = requests.firstWhere((r) => r.url.path.endsWith('/accept'));
    expect(accept.headers['Idempotency-Key'], isNotEmpty);
    expect(accept.headers['Authorization'], 'Bearer a');

    // Profile shows the credential expiry warning (< 30 days).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('credentialWarning')), findsOneWidget);

    await teardown(tester);
  });

  testWidgets('expired provider sees the blocking verification screen', (tester) async {
    await boot(tester, verification: 'expired');
    expect(find.text("You can't receive visits right now"), findsOneWidget);
    expect(find.text('Vitals Check'), findsNothing);
    await teardown(tester);
  });

  testWidgets('account without the provider role gets the application form (§30)', (tester) async {
    await boot(tester, verification: 'verified', roles: ['patient']);
    expect(find.byKey(const Key('onbIntro')), findsOneWidget);
    expect(find.byKey(const Key('applicationStepper')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('profile links to earnings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await boot(tester, verification: 'verified');
    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('changePhoto')), findsOneWidget);
    await tester.tap(find.byKey(const Key('earningsEntry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('earnMonth')), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('B16: credential expiring within 30 days is also shown on Home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await boot(tester, verification: 'verified');
    expect(find.byKey(const Key('homeCredentialWarning')), findsOneWidget);
    expect(find.textContaining('Your credential expires in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homeCredentialWarning')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('credentialWarning')), findsOneWidget, reason: 'opens the profile');
    await teardown(tester);
  });

  testWidgets('B21: tabs are equal width when the labels fit', (tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await boot(tester, verification: 'verified');
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
    await teardown(tester);
  });

  testWidgets('B21: Home tab labels are not truncated at 412 dp and font scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(1082, 2400); // ~412 dp at 2.625
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await boot(tester, verification: 'verified');
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue, reason: 'labels do not fit as fixed tabs');
    for (final label in ['Today', 'Upcoming', 'Completed']) {
      final p = tester.renderObject<RenderParagraph>(find.text(label));
      expect(p.size.width, greaterThanOrEqualTo(p.getMaxIntrinsicWidth(double.infinity) - 0.5), reason: label);
      expect(p.didExceedMaxLines, isFalse, reason: label);
    }
    expect(tester.takeException(), isNull);
    await teardown(tester);
  });

  testWidgets('B10: capability chips are localized (Hindi)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'app.locale': 'hi'});
    await boot(tester, verification: 'verified', capabilities: ['vitals_check', 'sample_collection']);
    await tester.tap(find.byTooltip('प्रोफ़ाइल'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('वाइटल्स जाँच'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('वाइटल्स जाँच'), findsOneWidget);
    expect(find.text('सैंपल संग्रह'), findsOneWidget);
    expect(find.text('vitals check'), findsNothing);
    await teardown(tester);
  });

  group('location permission', () {
    testWidgets('rationale first; "Not now" shows a message and is not asked again on the next launch',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final perms = FakeLocationPermissions(LocationAccess.denied);
      final (store, _) = await boot(tester,
          verification: 'verified', extra: [locationPermissionsProvider.overrideWithValue(perms)]);
      expect(find.byKey(const Key('locationRationale')), findsOneWidget);
      expect(perms.requests, 0, reason: 'no system prompt before the explanation');
      await tester.tap(find.byKey(const Key('locationNotNow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('locationDeniedSnack')), findsOneWidget);
      expect(perms.requests, 0);
      await teardown(tester);

      // Next launch: no automatic prompt; the Route tab offers it instead.
      await boot(tester,
          verification: 'verified',
          existingStore: store,
          extra: [locationPermissionsProvider.overrideWithValue(perms)]);
      expect(find.byKey(const Key('locationRationale')), findsNothing);
      // The test font is wide, so the tab bar scrolls: bring Route into view.
      await tester.ensureVisible(find.byKey(const Key('tabRoute')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tabRoute')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('locationOffBanner')), findsOneWidget);
      perms.onRequest = LocationAccess.granted;
      await tester.tap(find.byKey(const Key('locationTurnOn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('locationContinue')));
      await tester.pumpAndSettle();
      expect(perms.requests, 1);
      expect(find.byKey(const Key('locationOffBanner')), findsNothing);
      await teardown(tester);
    });

    testWidgets('Continue -> system prompt; a denial shows a non-blocking message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final perms = FakeLocationPermissions(LocationAccess.denied);
      await boot(tester, verification: 'verified', extra: [locationPermissionsProvider.overrideWithValue(perms)]);
      await tester.tap(find.byKey(const Key('locationContinue')));
      await tester.pumpAndSettle();
      expect(perms.requests, 1);
      expect(find.byKey(const Key('locationDeniedSnack')), findsOneWidget);
      expect(find.text('Vitals Check'), findsOneWidget, reason: 'home stays usable');
      await teardown(tester);
    });

    testWidgets('already allowed: no prompt', (tester) async {
      final perms = FakeLocationPermissions(LocationAccess.granted);
      await boot(tester, verification: 'verified', extra: [locationPermissionsProvider.overrideWithValue(perms)]);
      expect(find.byKey(const Key('locationRationale')), findsNothing);
      await teardown(tester);
    });
  });
}
