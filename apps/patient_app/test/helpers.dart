import 'package:care_companion_patient/app.dart' show localizationsDelegates;
import 'package:care_companion_patient/core/api/api_client.dart';
import 'package:care_companion_patient/core/api/token_store.dart';
import 'package:care_companion_patient/core/theme/app_theme.dart';
import 'package:care_companion_patient/l10n/app_localizations.dart';
import 'package:care_companion_patient/models/auth.dart';
import 'package:care_companion_patient/models/patient.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An ApiClient that must never be hit in widget tests (fakes are used).
ApiClient deadApiClient() => ApiClient(
      baseUrl: 'http://test.invalid/api/v1',
      httpClient: MockClient((r) async => http.Response('{"error":{"code":"NOT_FOUND","message":"no"}}', 404)),
      tokenStore: InMemoryTokenStore(),
    );

final testMe = Me(
  id: 'u1',
  phone: '+919800000001',
  name: 'Vaibhav',
  email: 'vaibhav@example.com',
  roles: const ['patient'],
  language: 'en',
  selfPatientId: 'p-self',
  onboardingComplete: true,
  mfaRequired: false,
  providerId: null,
);

final selfPatient = PatientSummary(
  id: 'p-self',
  name: 'Vaibhav',
  dob: '2002-01-01',
  age: 24,
  gender: 'male',
  relation: 'self',
  isSelf: true,
  permissions: FamilyPermission.all,
  avatarUrl: null,
);

class FakeSession extends SessionNotifier {
  @override
  SessionState build() => SessionState(AuthStatus.authenticated, testMe);
}

Future<List<Override>> baseOverrides({PatientSummary? patient}) async {
  SharedPreferences.setMockInitialValues({'cc_locale': 'en'});
  final prefs = await SharedPreferences.getInstance();
  final p = patient ?? selfPatient;
  return [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(deadApiClient()),
    sessionProvider.overrideWith(FakeSession.new),
    patientsProvider.overrideWith((ref) async => [p]),
    activePatientProvider.overrideWith((ref) async => p),
  ];
}

/// Wraps [child] in ProviderScope + a localized MaterialApp (no network fonts).
Widget testApp(Widget child, {required List<Override> overrides}) {
  AppTheme.useGoogleFonts = false;
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: AppTheme.light(),
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: child,
      ),
    ),
  );
}

void useTallPhone(WidgetTester tester, {double height = 3200}) {
  tester.view.physicalSize = Size(430 * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Like [testApp] but with a router (for screens that navigate).
Widget testAppRouter(GoRouter router, {required List<Override> overrides, ThemeMode themeMode = ThemeMode.light}) {
  AppTheme.useGoogleFonts = false;
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}
