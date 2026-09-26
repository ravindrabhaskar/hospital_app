import 'dart:convert';

import 'package:care_companion_patient/core/api/api_client.dart';
import 'package:care_companion_patient/core/api/api_exception.dart';
import 'package:care_companion_patient/core/api/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'http://api.test/api/v1';

Map<String, dynamic> session(String access, String refresh) => {
      'accessToken': access,
      'refreshToken': refresh,
      'expiresIn': 900,
      'user': {'id': 'u1', 'phone': '+919800000001', 'roles': ['patient'], 'language': 'en'},
    };

http.Response jsonRes(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('ApiClient', () {
    test('refreshes once on 401, rotates tokens and replays the request', () async {
      final store = InMemoryTokenStore(const StoredTokens(accessToken: 'a1', refreshToken: 'r1'));
      var refreshCalls = 0;
      final seenKeys = <String?>[];
      final seenCorrelation = <String?>[];
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          expect(jsonDecode(req.body), {'refreshToken': 'r1'});
          expect(req.headers.containsKey('Authorization'), isFalse);
          return jsonRes(session('a2', 'r2'), 200);
        }
        seenKeys.add(req.headers['Idempotency-Key']);
        seenCorrelation.add(req.headers['X-Correlation-Id']);
        if (req.headers['Authorization'] == 'Bearer a1') {
          return jsonRes({'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'}}, 401);
        }
        expect(req.headers['Authorization'], 'Bearer a2');
        return jsonRes({'ok': true}, 201);
      });
      Map<String, dynamic>? refreshedUser;
      final api = ApiClient(baseUrl: base, httpClient: client, tokenStore: store)
        ..onSessionRefreshed = (s) => refreshedUser = s;

      final res = await api.post('/appointments', body: {'x': 1}, idempotencyKey: 'key-123');

      expect(res, {'ok': true});
      expect(refreshCalls, 1);
      final t = await store.read();
      expect(t!.accessToken, 'a2');
      expect(t.refreshToken, 'r2');
      expect(refreshedUser?['accessToken'], 'a2');
      // Same idempotency key and correlation id on the original and the replay.
      expect(seenKeys, ['key-123', 'key-123']);
      expect(seenCorrelation.toSet().length, 1);
      expect(seenCorrelation.first, isNotEmpty);
    });

    test('concurrent 401s share a single refresh call', () async {
      final store = InMemoryTokenStore(const StoredTokens(accessToken: 'a1', refreshToken: 'r1'));
      var refreshCalls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonRes(session('a2', 'r2'), 200);
        }
        if (req.headers['Authorization'] == 'Bearer a1') {
          return jsonRes({'error': {'code': 'UNAUTHENTICATED', 'message': 'expired'}}, 401);
        }
        return jsonRes({'path': req.url.path}, 200);
      });
      final api = ApiClient(baseUrl: base, httpClient: client, tokenStore: store);
      final results = await Future.wait([api.get('/me'), api.get('/patients'), api.get('/consents')]);
      expect(results.length, 3);
      expect(refreshCalls, 1);
    });

    test('failed refresh clears tokens, fires onSessionExpired and throws UNAUTHENTICATED', () async {
      final store = InMemoryTokenStore(const StoredTokens(accessToken: 'a1', refreshToken: 'bad'));
      var expired = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return jsonRes({'error': {'code': 'UNAUTHENTICATED', 'message': 'bad refresh'}}, 401);
        }
        return jsonRes({'error': {'code': 'UNAUTHENTICATED', 'message': 'expired', 'correlationId': 'c-1'}}, 401);
      });
      final api = ApiClient(baseUrl: base, httpClient: client, tokenStore: store)..onSessionExpired = () => expired++;

      await expectLater(
        api.get('/me'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')
            .having((e) => e.correlationId, 'correlationId', 'c-1')),
      );
      expect(await store.read(), isNull);
      expect(expired, 1);
    });

    test('maps the error envelope and transport errors to typed exceptions', () async {
      final store = InMemoryTokenStore(const StoredTokens(accessToken: 'a1', refreshToken: 'r1'));
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/appointments')) {
          return jsonRes({
            'error': {'code': 'SLOT_UNAVAILABLE', 'message': 'Slot taken', 'details': {'slotId': 's1'}}
          }, 409);
        }
        throw http.ClientException('socket closed');
      });
      final api = ApiClient(baseUrl: base, httpClient: client, tokenStore: store);

      await expectLater(
        api.post('/appointments', body: {}, idempotencyKey: 'k'),
        throwsA(isA<ApiException>()
            .having((e) => e.isSlotUnavailable, 'slot', true)
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.details['slotId'], 'details', 's1')),
      );
      await expectLater(
        api.get('/me'),
        throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', true)),
      );
    });

    test('skips null/empty query params and sends Accept-Language', () async {
      final store = InMemoryTokenStore(const StoredTokens(accessToken: 'a1', refreshToken: 'r1'));
      late http.BaseRequest seen;
      final client = MockClient((req) async {
        seen = req;
        return jsonRes({'items': [], 'nextCursor': null}, 200);
      });
      final api = ApiClient(baseUrl: base, httpClient: client, tokenStore: store)..languageCode = () => 'te';
      await api.get('/doctors', query: {'specialty': 'ent', 'q': null, 'availableToday': true, 'mode': ''});
      expect(seen.url.queryParameters, {'specialty': 'ent', 'availableToday': 'true'});
      expect(seen.headers['Accept-Language'], 'te');
      expect(seen.headers['Authorization'], 'Bearer a1');
    });
  });
}
