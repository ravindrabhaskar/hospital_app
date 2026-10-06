import 'dart:convert';

import 'package:care_companion_provider/core/api/api_client.dart';
import 'package:care_companion_provider/core/api/api_exception.dart';
import 'package:care_companion_provider/core/api/token_store.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/server/server_settings.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/auth/login_screen.dart';
import 'package:care_companion_provider/l10n/gen/app_localizations.dart';
import 'package:care_companion_provider/l10n/gen/app_localizations_en.dart';
import 'package:care_companion_provider/l10n/gen/app_localizations_hi.dart';
import 'package:care_companion_provider/ui/l10n_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _error(int status, String code, String message, [Map<String, dynamic> details = const {}]) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'message': message, 'details': details, 'correlationId': 'c-1'},
      }),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  final l = AppLocalizationsEn();

  group('B6: error message mapping', () {
    test('wrong OTP (401 on an unauthenticated call) is "Incorrect OTP", never "session expired"', () {
      const e = ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'Incorrect OTP',
        details: {'attemptsRemaining': 4},
        authenticated: false,
      );
      expect(otpErrorMessage(l, e), 'Incorrect OTP. 4 attempts left.');
      expect(otpErrorMessage(l, e), isNot(l.errorSessionExpired));
      expect(errorMessage(l, e), 'Incorrect OTP', reason: 'generic mapping uses the server message');
    });

    test('attempts wording: one left, none left, expired, rate limited', () {
      ApiException wrong(int? left) => ApiException(
            statusCode: 401,
            code: 'UNAUTHENTICATED',
            message: 'Incorrect OTP',
            details: {'attemptsRemaining': ?left},
            authenticated: false,
          );
      expect(otpErrorMessage(l, wrong(1)), 'Incorrect OTP. 1 attempt left.');
      expect(otpErrorMessage(l, wrong(0)), l.errorOtpTooManyAttempts);
      expect(otpErrorMessage(l, wrong(null)), l.errorOtpExpired);
      const limited = ApiException(statusCode: 429, code: 'RATE_LIMITED', message: 'Too many', authenticated: false);
      expect(otpErrorMessage(l, limited), l.errorOtpTooManyAttempts);
      expect(otpErrorMessage(l, const ApiException.network()), l.errorNetwork);
    });

    test('Hindi uses the localized text', () {
      final hi = AppLocalizationsHi();
      const e = ApiException(
          statusCode: 401, code: 'UNAUTHENTICATED', message: 'Incorrect OTP', details: {'attemptsRemaining': 3}, authenticated: false);
      expect(otpErrorMessage(hi, e), contains('3'));
      expect(otpErrorMessage(hi, e), isNot(contains('Incorrect')));
    });

    test('a 401 on an authenticated call still means the session expired', () {
      const e = ApiException(statusCode: 401, code: 'UNAUTHENTICATED', message: 'Token expired');
      expect(errorMessage(l, e), l.errorSessionExpired);
    });

    test('the API client keeps details and marks unauthenticated calls', () async {
      final api = ApiClient(
        baseUrl: 'http://test/api/v1',
        tokens: TokenStore(MemoryKeyValueStore()),
        httpClient: MockClient((r) async => _error(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 2})),
      );
      var expired = 0;
      api.onSessionExpired = () => expired++;
      try {
        await api.post('/auth/otp/verify', body: {'phone': '+919800000201', 'otp': '111111'}, auth: false);
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.authenticated, isFalse);
        expect(e.attemptsRemaining, 2);
        expect(e.isSessionExpired, isFalse);
      }
      expect(expired, 0);
    });
  });

  testWidgets('B6: login screen shows "Incorrect OTP" with attempts left on a wrong code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final server = ServerSettings(defaultUrl: 'http://10.0.2.2:4000/api/v1', overrideAllowed: true);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        serverSettingsProvider.overrideWithValue(server),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        httpClientProvider.overrideWithValue(MockClient((r) async {
          if (r.url.path.endsWith('/auth/otp/request')) {
            return http.Response(jsonEncode({'requestId': 'r1', 'expiresAt': '2026-10-06T10:00:00.000Z'}), 200,
                headers: {'content-type': 'application/json'});
          }
          return _error(401, 'UNAUTHENTICATED', 'Incorrect OTP', {'attemptsRemaining': 4});
        })),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LoginScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phoneField')), '9800000201');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otpField')), '111111');
    await tester.tap(find.text(l.loginVerify));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect OTP. 4 attempts left.'), findsOneWidget);
    expect(find.text('Your session has expired. Please log in again.'), findsNothing);
  });
}
