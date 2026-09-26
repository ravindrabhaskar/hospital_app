import 'dart:convert';

import 'package:care_companion_provider/core/api/api_client.dart';
import 'package:care_companion_provider/core/api/token_store.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/auth/auth_controller.dart';
import 'package:care_companion_provider/features/auth/auth_repository.dart';
import 'package:care_companion_provider/features/auth/gate_screens.dart';
import 'package:care_companion_provider/features/offline/offline_queue.dart';
import 'package:care_companion_provider/features/offline/visit_cache.dart';
import 'package:care_companion_provider/features/visits/data/provider_repository.dart';
import 'package:care_companion_provider/models/provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

Map<String, dynamic> providerMe(String status, {String? expiresAt}) => {
      'id': 'prov-3',
      'name': 'Anil',
      'type': 'intern',
      'qualification': 'MBBS intern',
      'verificationStatus': status,
      'credentialExpiresAt': expiresAt ?? '2026-08-01T00:00:00.000Z',
      'onDuty': false,
      'zones': [
        {'id': 'z1', 'name': 'Hyderabad-Central'},
      ],
      'capabilities': ['vitals_check'],
    };

Map<String, dynamic> me(List<String> roles) => {
      'id': 'u1',
      'phone': '+919800000203',
      'name': 'Anil',
      'email': null,
      'roles': roles,
      'language': 'en',
      'selfPatientId': null,
      'onboardingComplete': true,
      'mfaRequired': false,
      'providerId': roles.contains('provider') ? 'prov-3' : null,
    };

Future<AuthController> controllerFor(Map<String, (int, Object?)> routes) async {
  final store = MemoryKeyValueStore();
  await store.write(StoreKeys.accessToken, 'a');
  await store.write(StoreKeys.refreshToken, 'r');
  final client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/api/v1', '');
    final r = routes[path];
    if (r == null) return http.Response('{"error":{"code":"NOT_FOUND","message":"nf"}}', 404);
    return http.Response(jsonEncode(r.$2), r.$1, headers: {'content-type': 'application/json'});
  });
  final tokens = TokenStore(store);
  final api = ApiClient(baseUrl: 'http://test/api/v1', tokens: tokens, httpClient: client);
  final providerRepo = ProviderRepository(api);
  return AuthController(
    tokens: tokens,
    authRepository: AuthRepository(api),
    providerRepository: providerRepo,
    store: store,
    queue: OfflineQueue(store: store, sender: providerRepo.sendAction),
    cache: VisitCache(store),
  );
}

void main() {
  group('AuthController gating', () {
    test('account without provider role -> restricted', () async {
      final c = await controllerFor({'/me': (200, me(['patient']))});
      await c.init();
      expect(c.status, AuthStatus.restricted);
    });

    test('provider with expired credential -> blocked', () async {
      final c = await controllerFor({
        '/me': (200, me(['provider'])),
        '/provider/me': (200, providerMe('expired')),
      });
      await c.init();
      expect(c.status, AuthStatus.blocked);
      expect(c.profile!.verificationStatus, 'expired');
    });

    for (final s in ['pending', 'suspended', 'rejected']) {
      test('provider $s -> blocked', () async {
        final c = await controllerFor({
          '/me': (200, me(['provider'])),
          '/provider/me': (200, providerMe(s)),
        });
        await c.init();
        expect(c.status, AuthStatus.blocked);
      });
    }

    test('verified provider -> ready', () async {
      final c = await controllerFor({
        '/me': (200, me(['provider'])),
        '/provider/me': (200, providerMe('verified', expiresAt: '2027-09-01T00:00:00.000Z')),
      });
      await c.init();
      expect(c.status, AuthStatus.ready);
    });

    test('no session -> signed out', () async {
      final c = await controllerFor({});
      await c.tokens.clear();
      final fresh = AuthController(
        tokens: TokenStore(MemoryKeyValueStore()),
        authRepository: c.authRepository,
        providerRepository: c.providerRepository,
        store: MemoryKeyValueStore(),
        queue: c.queue,
        cache: c.cache,
      );
      await fresh.init();
      expect(fresh.status, AuthStatus.signedOut);
    });
  });

  group('VerificationBlockedView', () {
    Future<void> pump(WidgetTester tester, String status, {DateTime? expiresAt}) =>
        tester.pumpWidget(testApp(
          VerificationBlockedView(
            status: status,
            credentialExpiresAt: expiresAt,
            onCheckAgain: () {},
            onLogout: () {},
          ),
          wrap: false,
        ));

    testWidgets('expired: explains the credential expiry and that no visits can be assigned', (tester) async {
      await pump(tester, 'expired', expiresAt: DateTime.utc(2026, 8, 1));
      expect(find.text("You can't receive visits right now"), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.textContaining('credential has expired'), findsOneWidget);
      expect(find.textContaining('Credential expired on'), findsOneWidget);
      expect(find.text('No home visits can be assigned to you until your verification is active.'), findsOneWidget);
      expect(find.text('Check status again'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('pending', (tester) async {
      await pump(tester, 'pending');
      expect(find.textContaining('pending review'), findsOneWidget);
      expect(find.textContaining('Credential expired on'), findsNothing);
    });

    testWidgets('suspended', (tester) async {
      await pump(tester, 'suspended');
      expect(find.textContaining('has been suspended'), findsOneWidget);
    });

    testWidgets('renders localized (Hindi)', (tester) async {
      await tester.pumpWidget(testApp(
        VerificationBlockedView(status: 'expired', onCheckAgain: () {}, onLogout: () {}),
        locale: const Locale('hi'),
        wrap: false,
      ));
      expect(find.text('अभी आपको विज़िट नहीं मिल सकतीं'), findsOneWidget);
    });
  });

  test('credential expiry warning threshold is 30 days', () {
    final now = DateTime.utc(2026, 9, 26);
    ProviderProfile p(DateTime exp) =>
        ProviderProfile.fromJson({...providerMe('verified'), 'credentialExpiresAt': exp.toIso8601String()});
    expect(p(now.add(const Duration(days: 10))).credentialExpiringSoon(now), isTrue);
    expect(p(now.add(const Duration(days: 45))).credentialExpiringSoon(now), isFalse);
  });
}
