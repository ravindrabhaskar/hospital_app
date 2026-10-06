import 'package:care_companion_provider/core/server/server_address_dialog.dart';
import 'package:care_companion_provider/core/server/server_settings.dart';
import 'package:care_companion_provider/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _default = 'http://10.0.2.2:4000/api/v1';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );

/// A button that opens the dialog; the result lands in [changed].
Widget _opener(ServerSettings settings, http.Client client, List<bool> changed) => _wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            changed.add(await showServerAddressDialog(context, settings: settings, httpClient: client)),
        child: const Text('open'),
      ),
    ));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('normalizeServerUrl', () {
    test('bare IP gets http, the dev port and /api/v1', () {
      expect(normalizeServerUrl('10.10.17.134'), 'http://10.10.17.134:4000/api/v1');
      expect(normalizeServerUrl('  10.10.17.134:5000 '), 'http://10.10.17.134:5000/api/v1');
      expect(normalizeServerUrl('localhost'), 'http://localhost:4000/api/v1');
    });

    test('missing /api/v1 is appended, trailing slashes removed', () {
      expect(normalizeServerUrl('http://10.10.17.134:4000'), 'http://10.10.17.134:4000/api/v1');
      expect(normalizeServerUrl('http://10.10.17.134:4000/'), 'http://10.10.17.134:4000/api/v1');
      expect(normalizeServerUrl('http://10.10.17.134:4000/api/v1/'), 'http://10.10.17.134:4000/api/v1');
      expect(normalizeServerUrl('http://10.10.17.134:4000/api/v1'), 'http://10.10.17.134:4000/api/v1');
    });

    test('https tunnel URLs keep https and get /api/v1', () {
      expect(normalizeServerUrl('https://xyz.trycloudflare.com'), 'https://xyz.trycloudflare.com/api/v1');
      expect(normalizeServerUrl('https://xyz.trycloudflare.com/'), 'https://xyz.trycloudflare.com/api/v1');
      expect(normalizeServerUrl('xyz.trycloudflare.com'), 'https://xyz.trycloudflare.com/api/v1');
    });

    test('garbage is rejected', () {
      for (final bad in ['', '   ', 'ftp://host', 'http://', 'not a url', '999.1.1.1', 'http://u:p@host']) {
        expect(normalizeServerUrl(bad), isNull, reason: bad);
      }
    });

    test('malformed / pasted-together addresses are rejected (QA B22)', () {
      for (final bad in [
        'http://10.10.17.http//10.0.2.2:9999/api/v134:4000/api/v1',
        'http://10.0.2.2:4000http://10.0.2.2:4000/api/v1',
        '10.10.17.http',
        'http://10.10.17/api/v1',
        'http://host_name:4000',
        'http://10.0.2.2:4000/api//v1',
        'http://10.0.2.2:4000/api/v1?x=1',
        'http://10.0.2.2:4000/#frag',
        'http://-bad-.example.com',
      ]) {
        expect(normalizeServerUrl(bad), isNull, reason: bad);
      }
    });

    test('ordinary addresses still pass', () {
      expect(normalizeServerUrl('http://10.0.2.2:4000/api/v1'), 'http://10.0.2.2:4000/api/v1');
      expect(normalizeServerUrl('https://api.care-companion.in'), 'https://api.care-companion.in/api/v1');
      expect(normalizeServerUrl('http://my-server:4000'), 'http://my-server:4000/api/v1');
      expect(normalizeServerUrl('https://example.com/backend'), 'https://example.com/backend/api/v1');
    });

    test('hostOf shows host[:port]', () {
      expect(hostOf('http://10.10.17.134:4000/api/v1'), '10.10.17.134:4000');
      expect(hostOf('https://xyz.trycloudflare.com/api/v1'), 'xyz.trycloudflare.com');
    });
  });

  group('override-allowed rule', () {
    test('https production builds can never override', () {
      expect(ServerSettings.isOverrideAllowed(compiledBaseUrl: 'https://api.carecompanion.in/api/v1'), isFalse);
      expect(ServerSettings.isOverrideAllowed(compiledBaseUrl: 'HTTPS://api.carecompanion.in/api/v1'), isFalse);
    });

    test('http (dev / LAN) builds and ALLOW_SERVER_OVERRIDE builds can', () {
      expect(ServerSettings.isOverrideAllowed(compiledBaseUrl: 'http://10.0.2.2:4000/api/v1'), isTrue);
      expect(
        ServerSettings.isOverrideAllowed(compiledBaseUrl: 'https://staging.example.in/api/v1', allowFlag: true),
        isTrue,
      );
    });

    test('a disallowed build refuses to set, ignores and wipes a stored override', () async {
      SharedPreferences.setMockInitialValues({ServerSettings.prefsKey: 'http://evil.example:4000/api/v1'});
      final prefs = await SharedPreferences.getInstance();
      final s = await ServerSettings.load(
          defaultUrl: 'https://api.carecompanion.in/api/v1', overrideAllowed: false, prefs: prefs);
      expect(s.effectiveUrl, 'https://api.carecompanion.in/api/v1');
      expect(s.override, isNull);
      expect(prefs.getString(ServerSettings.prefsKey), isNull);
      await expectLater(s.setOverride('10.0.0.1'), throwsStateError);
      expect(s.effectiveUrl, 'https://api.carecompanion.in/api/v1');
    });
  });

  group('persistence and effective URL', () {
    test('no override → compiled URL; saved override → used and persisted globally', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true, prefs: prefs);
      expect(s.effectiveUrl, _default);
      var notified = 0;
      s.addListener(() => notified++);

      await s.setOverride('10.10.17.134');
      expect(s.effectiveUrl, 'http://10.10.17.134:4000/api/v1');
      expect(notified, 1);
      // Global, unprefixed key (shared by all roles of the all-in-one build).
      expect(prefs.getString('server.baseUrl.override'), 'http://10.10.17.134:4000/api/v1');

      final again = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true, prefs: prefs);
      expect(again.effectiveUrl, 'http://10.10.17.134:4000/api/v1');

      await s.reset();
      expect(s.effectiveUrl, _default);
      expect(prefs.containsKey(ServerSettings.prefsKey), isFalse);
      expect(notified, 2);
    });

    test('invalid input is rejected without changing anything', () async {
      final s = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      await expectLater(s.setOverride('not a url'), throwsFormatException);
      expect(s.effectiveUrl, _default);
    });
  });

  group('dialog', () {
    testWidgets('test connection: success shows one tick and the version; Save applies it', (tester) async {
      final requests = <Uri>[];
      final client = MockClient((r) async {
        requests.add(r.url);
        return http.Response('{"status":"ok","version":"1.4.2"}', 200);
      });
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      final changed = <bool>[];
      await tester.pumpWidget(_opener(settings, client, changed));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, _default), findsOneWidget, reason: 'prefilled with the current URL');
      await tester.enterText(find.byKey(const Key('serverUrlField')), '10.10.17.134');
      await tester.tap(find.byKey(const Key('serverTest')));
      await tester.pumpAndSettle();

      expect(requests.single.toString(), 'http://10.10.17.134:4000/api/v1/health');
      expect(find.text('Connected. Server version 1.4.2'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('✓'), findsNothing, reason: 'the tick is the icon only, not repeated in the text');

      await tester.tap(find.byKey(const Key('serverSave')));
      await tester.pumpAndSettle();
      expect(changed, [true]);
      expect(settings.effectiveUrl, 'http://10.10.17.134:4000/api/v1');
    });

    testWidgets('test connection: unreachable server shows the helpful error', (tester) async {
      final client = MockClient((r) async => throw http.ClientException('Connection refused', r.url));
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      await tester.pumpWidget(_opener(settings, client, []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('serverTest')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.textContaining('START-CARECOMPANION.bat'), findsOneWidget);
      expect(find.textContaining('✓'), findsNothing);
    });

    testWidgets('a non-CareCompanion answer and invalid input are reported', (tester) async {
      final client = MockClient((r) async => http.Response('<html>nginx</html>', 404));
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      await tester.pumpWidget(_opener(settings, client, []));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('serverTest')));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 404'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('serverUrlField')), 'not a url');
      await tester.tap(find.byKey(const Key('serverSave')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter an address like'), findsOneWidget);
      expect(settings.isOverridden, isFalse);
    });

    testWidgets('Save refuses a garbled address instead of storing it', (tester) async {
      final requests = <Uri>[];
      final client = MockClient((r) async {
        requests.add(r.url);
        return http.Response('{"status":"ok"}', 200);
      });
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      final changed = <bool>[];
      await tester.pumpWidget(_opener(settings, client, changed));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('serverUrlField')), 'http://10.10.17.http//10.0.2.2:9999/api/v134:4000/api/v1');
      await tester.tap(find.byKey(const Key('serverSave')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter an address like'), findsOneWidget);
      expect(find.byKey(const Key('serverSave')), findsOneWidget, reason: 'dialog stays open');
      expect(settings.isOverridden, isFalse);
      expect(changed, isEmpty);

      await tester.tap(find.byKey(const Key('serverTest')));
      await tester.pumpAndSettle();
      expect(requests, isEmpty, reason: 'Test applies the same validation');
    });

    testWidgets('large text + keyboard: Test connection stays reachable', (tester) async {
      tester.view.physicalSize = const Size(1080, 1300);
      tester.view.devicePixelRatio = 2.625;
      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      addTearDown(tester.view.reset);
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _opener(settings, MockClient((r) async => http.Response('', 500)), []),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const Key('serverUrlField')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byKey(const Key('serverTest')));
      final visible = tester.getRect(find.byType(SingleChildScrollView).last);
      expect(button.top >= visible.top && button.bottom <= visible.bottom, isTrue,
          reason: 'not clipped: $button inside $visible');
      await tester.tap(find.byKey(const Key('serverTest')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('serverResult')), findsOneWidget);
    });

    testWidgets('Reset to default drops the override', (tester) async {
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      await settings.setOverride('https://xyz.trycloudflare.com');
      final changed = <bool>[];
      await tester.pumpWidget(_opener(settings, MockClient((r) async => http.Response('', 500)), changed));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'https://xyz.trycloudflare.com/api/v1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('serverReset')));
      await tester.pumpAndSettle();
      expect(changed, [true]);
      expect(settings.effectiveUrl, _default);
    });

    testWidgets('signed in: warns, and signs out before switching servers', (tester) async {
      final settings = await ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
      final events = <String>[];
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => showServerAddressDialog(
            context,
            settings: settings,
            httpClient: MockClient((r) async => http.Response('', 500)),
            signedIn: true,
            beforeChange: () async => events.add('logout while on ${settings.effectiveUrl}'),
            afterChange: () async => events.add('reload from ${settings.effectiveUrl}'),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Changing the server signs you out.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('serverUrlField')), 'https://xyz.trycloudflare.com');
      await tester.tap(find.byKey(const Key('serverSave')));
      await tester.pumpAndSettle();
      expect(events, [
        'logout while on $_default',
        'reload from https://xyz.trycloudflare.com/api/v1',
      ]);
    });

    testWidgets('chip shows the host, and is hidden when overrides are not allowed', (tester) async {
      final settings = ServerSettings(defaultUrl: 'http://10.10.17.134:4000/api/v1', overrideAllowed: true);
      await tester.pumpWidget(_wrap(ServerAddressChip(settings: settings, onTap: () {})));
      expect(find.text('Server: 10.10.17.134:4000'), findsOneWidget);

      final prod = ServerSettings(defaultUrl: 'https://api.carecompanion.in/api/v1', overrideAllowed: false);
      await tester.pumpWidget(_wrap(ServerAddressChip(settings: prod, onTap: () {})));
      expect(find.byKey(const Key('serverChip')), findsNothing);
    });
  });
}
