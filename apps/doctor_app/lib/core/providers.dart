import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/auth_repository.dart';
import '../data/clinician_repository.dart';
import '../features/auth/auth_controller.dart';
import '../features/common/audio_recorder.dart';
import '../features/common/file_pickers.dart';
import 'api/api_client.dart';
import 'api/token_store.dart';
import 'config.dart';
import 'connectivity.dart';
import 'locale_controller.dart';
import 'public_config_controller.dart';
import 'push/push_service.dart';
import 'server/server_settings.dart';
import 'storage/key_value_store.dart';

// Overridable infrastructure (tests swap these).
/// Storage namespace (all-in-one demo build: `provider.` / `doctor.`); empty
/// when standalone, which keeps the existing keys and data.
final storagePrefixProvider = Provider<String>((ref) => '');

/// "Switch app" callback of the all-in-one demo build; null when standalone.
final switchAppProvider = Provider<VoidCallback?>((ref) => null);

final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  final prefix = ref.watch(storagePrefixProvider);
  return prefix.isEmpty ? SecureKeyValueStore() : PrefixedKeyValueStore(SecureKeyValueStore(), prefix);
});
final connectivityProvider = Provider<ConnectivityService>((ref) => PlusConnectivityService());
final httpClientProvider = Provider<http.Client>((ref) => http.Client());
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final appVersionReaderProvider = Provider<AppVersionReader>((ref) => readPackageVersion);
final firebaseSettingsProvider = Provider<FirebaseSettings>((ref) => FirebaseSettings.fromEnvironment());
final audioRecorderProvider = Provider<ScribeRecorder Function()>((ref) => RecordScribeRecorder.new);
final photoPickerProvider = Provider<PhotoPicker>((ref) => pickProfilePhoto);

final scaffoldMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(keyValueStoreProvider)));

/// Runtime "Server address" (demo builds). The bootstraps override it with the
/// persisted setting (global, unprefixed key); the default here has no
/// override and simply uses the compiled `API_BASE_URL`.
final serverSettingsProvider = Provider<ServerSettings>((ref) {
  final s = ServerSettings(defaultUrl: AppConfig.apiBaseUrl, overrideAllowed: AppConfig.serverOverrideAllowed);
  ref.onDispose(s.dispose);
  return s;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final server = ref.watch(serverSettingsProvider);
  final client = ApiClient(
    baseUrl: server.effectiveUrl,
    tokens: ref.watch(tokenStoreProvider),
    httpClient: ref.watch(httpClientProvider),
  );
  // A changed server address applies immediately, without a restart.
  void followServer() => client.baseUrl = server.effectiveUrl;
  server.addListener(followServer);
  ref.onDispose(() => server.removeListener(followServer));
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final clinicianRepositoryProvider = Provider<ClinicianRepository>(
  (ref) => ClinicianRepository(ref.watch(apiClientProvider)),
);

/// Public config (§21): support contacts, legal links, minimum app version.
final publicConfigProvider = Provider<PublicConfigController>((ref) {
  final c = PublicConfigController(
    api: ref.watch(apiClientProvider),
    appVersion: ref.watch(appVersionReaderProvider),
    storagePrefix: ref.watch(storagePrefixProvider),
  );
  ref.onDispose(c.dispose);
  return c;
});

/// FCM push; a no-op unless the Firebase dart-defines are provided.
final pushServiceProvider = Provider<PushService>((ref) {
  final p = PushService(api: ref.watch(apiClientProvider), settings: ref.watch(firebaseSettingsProvider));
  ref.onDispose(p.dispose);
  return p;
});

final localeControllerProvider = Provider<LocaleController>((ref) {
  final c = LocaleController(keyPrefix: ref.watch(storagePrefixProvider));
  ref.onDispose(c.dispose);
  return c;
});

final authControllerProvider = Provider<AuthController>((ref) {
  final api = ref.watch(apiClientProvider);
  final push = ref.watch(pushServiceProvider);
  final controller = AuthController(
    tokens: ref.watch(tokenStoreProvider),
    authRepository: ref.watch(authRepositoryProvider),
    clinician: ref.watch(clinicianRepositoryProvider),
    store: ref.watch(keyValueStoreProvider),
  );
  controller.onReady = push.registerDevice;
  controller.beforeLogout = push.unregisterDevice;
  controller.onSignedOut = () async => push.forgetSession();
  api.onSessionExpired = () => controller.handleSessionExpired();
  api.onMfaRequired = controller.requireMfa;
  ref.onDispose(controller.dispose);
  return controller;
});

/// Streams connectivity for the offline banner.
final onlineStatusProvider = StreamProvider<bool>((ref) async* {
  final c = ref.watch(connectivityProvider);
  yield await c.isOnline();
  yield* c.onStatusChange;
});
