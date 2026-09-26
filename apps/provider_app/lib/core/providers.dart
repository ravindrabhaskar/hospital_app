import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/offline/offline_queue.dart';
import '../features/onboarding/application_repository.dart';
import '../features/onboarding/document_picker.dart';
import '../features/visits/voice/voice_dictation.dart';
import '../features/offline/visit_action_service.dart';
import '../features/offline/visit_cache.dart';
import '../features/visits/data/photo_store.dart';
import '../features/visits/data/provider_repository.dart';
import 'api/api_client.dart';
import 'api/token_store.dart';
import 'config.dart';
import 'connectivity.dart';
import 'locale_controller.dart';
import 'location_reporter.dart';
import 'public_config_controller.dart';
import 'push/push_service.dart';
import 'storage/key_value_store.dart';

// Overridable infrastructure (tests swap these).
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SecureKeyValueStore());
final connectivityProvider = Provider<ConnectivityService>((ref) => PlusConnectivityService());
final httpClientProvider = Provider<http.Client>((ref) => http.Client());
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final photoFileStoreProvider = Provider<PhotoFileStore>((ref) => LocalPhotoFileStore());
final photoCaptureProvider = Provider<PhotoCapture>((ref) => captureWithCamera);
final documentPickerProvider = Provider<DocumentPicker>((ref) => pickDocument);
final voiceDictationProvider = Provider<VoiceDictation>((ref) => SpeechToTextDictation());
final appVersionReaderProvider = Provider<AppVersionReader>((ref) => readPackageVersion);
final firebaseSettingsProvider = Provider<FirebaseSettings>((ref) => FirebaseSettings.fromEnvironment());

final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) => GlobalKey<ScaffoldMessengerState>());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(keyValueStoreProvider)));

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      tokens: ref.watch(tokenStoreProvider),
      httpClient: ref.watch(httpClientProvider),
    ));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final providerRepositoryProvider = Provider<ProviderRepository>(
    (ref) => ProviderRepository(ref.watch(apiClientProvider), photos: ref.watch(photoFileStoreProvider)));

final applicationRepositoryProvider =
    Provider<ApplicationRepository>((ref) => ApplicationRepository(ref.watch(apiClientProvider)));

/// Public config (§21): support contacts, legal links, minimum app version.
final publicConfigProvider = Provider<PublicConfigController>((ref) {
  final c = PublicConfigController(api: ref.watch(apiClientProvider), appVersion: ref.watch(appVersionReaderProvider));
  ref.onDispose(c.dispose);
  return c;
});

/// FCM push; a no-op unless the Firebase dart-defines are provided.
final pushServiceProvider = Provider<PushService>((ref) {
  final p = PushService(api: ref.watch(apiClientProvider), settings: ref.watch(firebaseSettingsProvider));
  ref.onDispose(p.dispose);
  return p;
});

final visitCacheProvider = Provider<VisitCache>(
    (ref) => VisitCache(ref.watch(keyValueStoreProvider), clock: ref.watch(clockProvider)));

final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final repo = ref.watch(providerRepositoryProvider);
  final queue = OfflineQueue(store: ref.watch(keyValueStoreProvider), sender: repo.sendAction);
  ref.onDispose(queue.dispose);
  return queue;
});

final visitActionServiceProvider = Provider<VisitActionService>((ref) {
  final service = VisitActionService(
    queue: ref.watch(offlineQueueProvider),
    cache: ref.watch(visitCacheProvider),
    connectivity: ref.watch(connectivityProvider),
    photos: ref.watch(photoFileStoreProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final repo = ref.watch(providerRepositoryProvider);
  final reporter = LocationReporter(post: repo.postLocation, connectivity: ref.watch(connectivityProvider));
  ref.onDispose(reporter.stop);
  return reporter;
});

final localeControllerProvider = Provider<LocaleController>((ref) {
  final c = LocaleController();
  ref.onDispose(c.dispose);
  return c;
});

final authControllerProvider = Provider<AuthController>((ref) {
  final api = ref.watch(apiClientProvider);
  final actions = ref.watch(visitActionServiceProvider);
  final location = ref.watch(locationReporterProvider);
  final push = ref.watch(pushServiceProvider);
  final photos = ref.watch(photoFileStoreProvider);
  final controller = AuthController(
    tokens: ref.watch(tokenStoreProvider),
    authRepository: ref.watch(authRepositoryProvider),
    providerRepository: ref.watch(providerRepositoryProvider),
    store: ref.watch(keyValueStoreProvider),
    queue: ref.watch(offlineQueueProvider),
    cache: ref.watch(visitCacheProvider),
  );
  controller.onReady = (profile) {
    actions.startAutoSync();
    push.registerDevice();
    if (profile.onDuty) {
      location.start();
    } else {
      location.stop();
    }
  };
  controller.onInactive = () {
    actions.stopAutoSync();
    location.stop();
  };
  controller.beforeLogout = push.unregisterDevice;
  controller.onSignedOut = () async {
    push.forgetSession();
    await photos.clear();
  };
  api.onSessionExpired = () => controller.handleSessionExpired();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Streams connectivity for banners.
final onlineStatusProvider = StreamProvider<bool>((ref) async* {
  final c = ref.watch(connectivityProvider);
  yield await c.isOnline();
  yield* c.onStatusChange;
});
