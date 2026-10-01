import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/server/server_settings.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/auth/login_screen.dart';
import 'package:care_companion_provider/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('OTP network failure: "Can\'t reach the server at host" + Change server opens the dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final server = ServerSettings(defaultUrl: 'http://10.10.17.134:4000/api/v1', overrideAllowed: true);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        serverSettingsProvider.overrideWithValue(server),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        httpClientProvider.overrideWithValue(
            MockClient((r) async => throw http.ClientException('Connection refused', r.url))),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LoginScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Server: 10.10.17.134:4000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('phoneField')), '9800000001');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text("Can't reach the server at 10.10.17.134:4000"), findsOneWidget);
    await tester.tap(find.byKey(const Key('changeServer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('serverUrlField')), findsOneWidget);
  });

  testWidgets('no server chip when overrides are not allowed (https production)', (tester) async {
    final server = ServerSettings(defaultUrl: 'https://api.carecompanion.in/api/v1', overrideAllowed: false);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        serverSettingsProvider.overrideWithValue(server),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const LoginScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('serverChip')), findsNothing);
  });

  test('the API client follows the server setting without a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final server = await ServerSettings.load(
        defaultUrl: 'http://10.0.2.2:4000/api/v1', overrideAllowed: true, prefs: prefs);
    final seen = <Uri>[];
    final container = ProviderContainer(overrides: [
      serverSettingsProvider.overrideWithValue(server),
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      httpClientProvider.overrideWithValue(MockClient((r) async {
        seen.add(r.url);
        return http.Response('{}', 200);
      })),
    ]);
    addTearDown(container.dispose);

    await container.read(apiClientProvider).get('/config/public');
    await server.setOverride('https://xyz.trycloudflare.com');
    await container.read(apiClientProvider).get('/config/public');

    expect(seen.map((u) => u.toString()), [
      'http://10.0.2.2:4000/api/v1/config/public',
      'https://xyz.trycloudflare.com/api/v1/config/public',
    ]);
  });
}
