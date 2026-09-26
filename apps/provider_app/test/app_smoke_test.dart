import 'dart:convert';

import 'package:care_companion_provider/app.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'verification_gate_test.dart' show me, providerMe;

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<(MemoryKeyValueStore, List<http.Request>)> boot(WidgetTester tester,
      {required String verification, List<String> roles = const ['provider']}) async {
    final store = MemoryKeyValueStore();
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
}
