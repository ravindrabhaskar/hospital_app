import 'package:care_companion_patient/core/api/api_client.dart';
import 'package:care_companion_patient/core/api/token_store.dart';
import 'package:care_companion_patient/core/server/server_settings.dart';
import 'package:care_companion_patient/features/onboarding/phone_screen.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  testWidgets('OTP network failure: "Can\'t reach the server at host" + Change server opens the dialog',
      (tester) async {
    useTallPhone(tester);
    final base = await baseOverrides();
    final server = ServerSettings(defaultUrl: 'http://10.10.17.134:4000/api/v1', overrideAllowed: true);
    final offline = ApiClient(
      baseUrl: server.effectiveUrl,
      httpClient: MockClient((r) async => throw http.ClientException('Connection refused', r.url)),
      tokenStore: InMemoryTokenStore(),
    );
    await tester.pumpWidget(testApp(const PhoneScreen(), overrides: [
      // baseOverrides() starts with prefs + the dead API client; keep the rest.
      ...base.skip(2),
      sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
      serverSettingsProvider.overrideWithValue(server),
      apiClientProvider.overrideWithValue(offline),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Server: 10.10.17.134:4000'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '9800000001');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text("Can't reach the server at 10.10.17.134:4000"), findsOneWidget);
    await tester.tap(find.byKey(const Key('changeServer')));
    await tester.pumpAndSettle();
    expect(find.text('Server address'), findsOneWidget);
    expect(find.byKey(const Key('serverUrlField')), findsOneWidget);
  });

  test('the API client follows the server setting without a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final server = await ServerSettings.load(
        defaultUrl: 'http://10.0.2.2:4000/api/v1', overrideAllowed: true, prefs: prefs);
    final seen = <Uri>[];
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      serverSettingsProvider.overrideWithValue(server),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      httpClientProvider.overrideWithValue(MockClient((r) async {
        seen.add(r.url);
        return http.Response('{}', 200);
      })),
    ]);
    addTearDown(container.dispose);

    final api = container.read(apiClientProvider);
    await api.get('/config/public', auth: false);
    await server.setOverride('https://xyz.trycloudflare.com');
    await container.read(apiClientProvider).get('/config/public', auth: false);

    expect(seen.map((u) => u.toString()), [
      'http://10.0.2.2:4000/api/v1/config/public',
      'https://xyz.trycloudflare.com/api/v1/config/public',
    ]);
  });
}
