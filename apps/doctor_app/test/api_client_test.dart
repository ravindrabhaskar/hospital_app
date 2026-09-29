import 'package:care_companion_doctor/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  test('adds auth, correlation id, language and idempotency headers', () async {
    final b = mockBackend((req, path) => {'ok': true});
    final api = await apiWith(b.client);
    api.languageCode = 'te';
    await api.post('/clinician/prescriptions', body: {'x': 1}, idempotencyKey: 'idem-1');
    final r = b.requests.single;
    expect(r.headers['Authorization'], 'Bearer access-1');
    expect(r.headers['X-Correlation-Id'], isNotEmpty);
    expect(r.headers['Accept-Language'], 'te');
    expect(r.headers['Idempotency-Key'], 'idem-1');
    expect(r.headers['Content-Type'], startsWith('application/json'));
  });

  test('401 -> refreshes once, then retries with the rotated token and same correlation id', () async {
    var calls = 0;
    final b = mockBackend((req, path) {
      if (path == '/auth/refresh') return {'accessToken': 'access-new', 'refreshToken': 'refresh-new'};
      calls++;
      if (req.headers['Authorization'] == 'Bearer access-1') return errorResponse(401, 'UNAUTHENTICATED');
      return {'items': [], 'nextCursor': null};
    });
    final api = await apiWith(b.client);
    final res = await api.get('/inbox');
    expect(res, isA<Map>());
    expect(calls, 2);
    expect(api.tokens.accessToken, 'access-new');
    expect(api.tokens.refreshToken, 'refresh-new');
    final attempts = b.requests.where((r) => r.url.path.endsWith('/inbox')).toList();
    expect(attempts.last.headers['Authorization'], 'Bearer access-new');
    expect(attempts.first.headers['X-Correlation-Id'], attempts.last.headers['X-Correlation-Id']);
  });

  test('concurrent 401s share a single refresh', () async {
    var refreshes = 0;
    final b = mockBackend((req, path) {
      if (path == '/auth/refresh') {
        refreshes++;
        return {'accessToken': 'access-new', 'refreshToken': 'refresh-new'};
      }
      if (req.headers['Authorization'] == 'Bearer access-1') return errorResponse(401, 'UNAUTHENTICATED');
      return {'ok': true};
    });
    final api = await apiWith(b.client);
    await Future.wait([api.get('/a'), api.get('/b'), api.get('/c')]);
    expect(refreshes, 1);
  });

  test('refused refresh clears the session and reports expiry', () async {
    var expired = false;
    final b = mockBackend((req, path) {
      if (path == '/auth/refresh') return errorResponse(401, 'UNAUTHENTICATED');
      return errorResponse(401, 'UNAUTHENTICATED');
    });
    final api = await apiWith(b.client);
    api.onSessionExpired = () => expired = true;
    await expectLater(api.get('/inbox'), throwsA(isA<ApiException>().having((e) => e.isUnauthenticated, '401', true)));
    expect(expired, isTrue);
    expect(api.tokens.hasSession, isFalse);
  });

  test('403 MFA_REQUIRED fires onMfaRequired and throws a typed error (no refresh)', () async {
    var mfa = 0;
    final b = mockBackend((req, path) => errorResponse(403, 'MFA_REQUIRED', 'MFA needed'));
    final api = await apiWith(b.client);
    api.onMfaRequired = () => mfa++;
    try {
      await api.get('/clinician/queue');
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.isMfaRequired, isTrue);
      expect(e.isForbidden, isFalse, reason: 'MFA is a session state, not a lost permission');
      expect(e.statusCode, 403);
    }
    expect(mfa, 1);
    expect(b.requests.any((r) => r.url.path.endsWith('/auth/refresh')), isFalse);
    expect(api.tokens.hasSession, isTrue, reason: 'the session is kept for the TOTP step');
  });

  test('error envelope is parsed with details and correlation id', () async {
    final b = mockBackend(
      (req, path) => errorResponse(400, 'VALIDATION_ERROR', 'Major warnings', {
        'warnings': [
          {'severity': 'major'},
        ],
      }),
    );
    final api = await apiWith(b.client);
    try {
      await api.post('/clinician/prescriptions', body: {});
      fail('should throw');
    } on ApiException catch (e) {
      expect(e.isValidation, isTrue);
      expect(e.message, 'Major warnings');
      expect(e.correlationId, 'c-1');
      expect((e.details['warnings'] as List).length, 1);
    }
  });

  test('transport failures become network errors', () async {
    final client = MockClient((_) async => throw const SocketLikeException());
    final api = await apiWith(client);
    await expectLater(api.get('/inbox'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', true)));
  });

  test('getBytes returns raw bytes (PDF)', () async {
    final client = MockClient((_) async => http.Response.bytes([37, 80, 68, 70], 200));
    final api = await apiWith(client);
    expect(await api.getBytes('/prescriptions/x/pdf'), [37, 80, 68, 70]);
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
