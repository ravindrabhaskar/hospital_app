import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/token_store.dart';
import '../core/config.dart';
import '../core/push/push_service.dart';
import '../data/repositories.dart';
import '../models/auth.dart';
import '../models/config.dart';
import '../models/json.dart';
import '../models/patient.dart';

// ------------------------------------------------------------------ Infra

/// Overridden in `main()` with the loaded instance (and in tests).
final sharedPrefsProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'));

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    httpClient: ref.watch(httpClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
  client.languageCode = () => ref.read(localeProvider).languageCode;
  client.onSessionExpired = () => ref.read(sessionProvider.notifier).expire();
  client.onSessionRefreshed = (json) {
    final user = json['user'];
    if (user is Map) {
      ref.read(sessionProvider.notifier).updateMe(Me.fromJson(asJson(user)));
    }
  };
  return client;
});

final configRepositoryProvider =
    Provider((ref) => ConfigRepository(ref.watch(apiClientProvider)));
final accountRepositoryProvider =
    Provider((ref) => AccountRepository(ref.watch(apiClientProvider)));
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));
final consentRepositoryProvider =
    Provider((ref) => ConsentRepository(ref.watch(apiClientProvider)));
final patientRepositoryProvider =
    Provider((ref) => PatientRepository(ref.watch(apiClientProvider)));
final episodeRepositoryProvider =
    Provider((ref) => EpisodeRepository(ref.watch(apiClientProvider)));
final doctorRepositoryProvider =
    Provider((ref) => DoctorRepository(ref.watch(apiClientProvider)));
final appointmentRepositoryProvider =
    Provider((ref) => AppointmentRepository(ref.watch(apiClientProvider)));
final homeVisitRepositoryProvider =
    Provider((ref) => HomeVisitRepository(ref.watch(apiClientProvider)));
final recordsRepositoryProvider =
    Provider((ref) => RecordsRepository(ref.watch(apiClientProvider)));
final aiRepositoryProvider = Provider((ref) => AiRepository(ref.watch(apiClientProvider)));
final carePlanRepositoryProvider =
    Provider((ref) => CarePlanRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository(ref.watch(apiClientProvider)));
final paymentRepositoryProvider =
    Provider((ref) => PaymentRepository(ref.watch(apiClientProvider)));
final pharmacyRepositoryProvider =
    Provider((ref) => PharmacyRepository(ref.watch(apiClientProvider)));
final wellnessRepositoryProvider =
    Provider((ref) => WellnessRepository(ref.watch(apiClientProvider)));
final woundRepositoryProvider = Provider((ref) => WoundRepository(ref.watch(apiClientProvider)));
final wearablesRepositoryProvider =
    Provider((ref) => WearablesRepository(ref.watch(apiClientProvider)));
final safetyRepositoryProvider =
    Provider((ref) => SafetyRepository(ref.watch(apiClientProvider)));
final prescriptionRepositoryProvider =
    Provider((ref) => PrescriptionRepository(ref.watch(apiClientProvider)));
final reviewRepositoryProvider = Provider((ref) => ReviewRepository(ref.watch(apiClientProvider)));
final messagingRepositoryProvider =
    Provider((ref) => MessagingRepository(ref.watch(apiClientProvider)));
final subscriptionRepositoryProvider =
    Provider((ref) => SubscriptionRepository(ref.watch(apiClientProvider)));
final schemeRepositoryProvider = Provider((ref) => SchemeRepository(ref.watch(apiClientProvider)));

// ------------------------------------------------------------------ App version & public config

/// The installed app version (`version:` in pubspec). Overridden in `main()`
/// with package_info_plus; tests override it directly.
final appVersionProvider = Provider<String>((ref) => AppConfig.fallbackAppVersion);

/// 'android' | 'ios' | 'web' | 'other'. Overridable in tests.
final appPlatformProvider = Provider<String>((ref) {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
});

/// `GET /config/public` (§21). Starts from the last cached copy (or the
/// built-in defaults on first run) and is refreshed from the server at
/// startup; failures keep the cached value so the app works offline.
class PublicConfigNotifier extends Notifier<PublicConfig> {
  static const cacheKey = 'cc_public_config';

  @override
  PublicConfig build() {
    try {
      final cached = ref.read(sharedPrefsProvider).getString(cacheKey);
      if (cached != null) {
        final j = jsonDecode(cached);
        if (j is Map) return PublicConfig.fromJson(Map<String, dynamic>.from(j));
      }
    } catch (_) {}
    return PublicConfig.defaults;
  }

  /// Fetches the latest config. Returns true when the server answered.
  Future<bool> refresh() async {
    try {
      final repo = ref.read(configRepositoryProvider);
      final tenant = ref.read(tenantCodeProvider);
      final json = tenant.isEmpty ? await repo.publicConfigJson() : await repo.publicConfigJsonForTenant(tenant);
      state = PublicConfig.fromJson(json);
      try {
        await ref.read(sharedPrefsProvider).setString(cacheKey, jsonEncode(json));
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }
}

final publicConfigProvider =
    NotifierProvider<PublicConfigNotifier, PublicConfig>(PublicConfigNotifier.new);

/// The white-label tenant of this build (§58); empty for CareCompanion.
final tenantCodeProvider = Provider<String>((ref) => AppConfig.tenantCode);

/// Branding to apply (null = the default CareCompanion look).
final brandingProvider = Provider<Branding?>((ref) => ref.watch(publicConfigProvider).branding);

/// Server-backed feature flags (never hard-coded; see [FeatureFlags.defaults]).
final featureFlagsProvider = Provider<FeatureFlags>((ref) => ref.watch(publicConfigProvider).flags);

/// The minimum supported version for this platform, or null (web/desktop).
String? minVersionFor(PublicConfig c, String platform) => switch (platform) {
      'android' => c.minAppVersion.patientAndroid,
      'ios' => c.minAppVersion.patientIos,
      _ => null,
    };

/// True when the installed version is below `minAppVersion` → blocking
/// "Please update" screen.
final updateRequiredProvider = Provider<bool>((ref) {
  final min = minVersionFor(ref.watch(publicConfigProvider), ref.watch(appPlatformProvider));
  return min != null && isUpdateRequired(ref.watch(appVersionProvider), min);
});

// ------------------------------------------------------------------ Push

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    config: PushConfig.fromEnvironment(),
    registerToken: (token, platform) =>
        ref.read(notificationRepositoryProvider).registerDevice(token, platform),
    unregisterToken: (token) => ref.read(notificationRepositoryProvider).unregisterDevice(token),
  );
  return service;
});

// ------------------------------------------------------------------ Locale

const supportedLanguageCodes = ['en', 'hi', 'te'];

class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'cc_locale';

  @override
  Locale build() {
    try {
      final code = ref.read(sharedPrefsProvider).getString(_key);
      if (code != null && supportedLanguageCodes.contains(code)) return Locale(code);
    } catch (_) {}
    return const Locale('en');
  }

  bool get hasChosen {
    try {
      return ref.read(sharedPrefsProvider).getString(_key) != null;
    } catch (_) {
      return false;
    }
  }

  /// Changes the UI language immediately; persists locally.
  Future<void> set(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    state = Locale(code);
    try {
      await ref.read(sharedPrefsProvider).setString(_key, code);
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

// ------------------------------------------------------------------ Appearance

/// Profile → Appearance: System / Light / Dark, persisted locally.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const key = 'cc_theme_mode';

  @override
  ThemeMode build() {
    try {
      final v = ref.read(sharedPrefsProvider).getString(key);
      return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(sharedPrefsProvider).setString(key, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ------------------------------------------------------------------ Session

enum AuthStatus { unknown, offline, unauthenticated, authenticated }

class SessionState {
  const SessionState(this.status, [this.me]);
  final AuthStatus status;
  final Me? me;

  bool get isAuthenticated => status == AuthStatus.authenticated && me != null;
  bool get needsOnboarding => isAuthenticated && !me!.onboardingComplete;
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState(AuthStatus.unknown);

  TokenStore get _tokens => ref.read(tokenStoreProvider);

  /// Restores a stored session (splash).
  Future<void> bootstrap() async {
    final t = await _tokens.read();
    if (t == null) {
      state = const SessionState(AuthStatus.unauthenticated);
      return;
    }
    try {
      final me = await ref.read(authRepositoryProvider).me();
      _applyLanguage(me);
      state = SessionState(AuthStatus.authenticated, me);
    } on ApiException catch (e) {
      if (e.isOffline || e.isServerError) {
        state = const SessionState(AuthStatus.offline);
      } else {
        await _tokens.clear();
        state = const SessionState(AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> signIn(AuthSession session) async {
    await _tokens.write(
        StoredTokens(accessToken: session.accessToken, refreshToken: session.refreshToken));
    var me = session.user;
    // Keep the language the user picked before sign-in.
    final chosen = ref.read(localeProvider).languageCode;
    if (me.language != chosen) {
      try {
        me = await ref.read(authRepositoryProvider).updateMe(language: chosen);
      } catch (_) {}
    }
    ref.invalidate(activePatientIdProvider);
    state = SessionState(AuthStatus.authenticated, me);
  }

  void updateMe(Me me) {
    if (state.status == AuthStatus.authenticated || state.me != null) {
      state = SessionState(AuthStatus.authenticated, me);
    }
  }

  Future<void> refreshMe() async {
    final me = await ref.read(authRepositoryProvider).me();
    state = SessionState(AuthStatus.authenticated, me);
  }

  void _applyLanguage(Me me) {
    if (supportedLanguageCodes.contains(me.language)) {
      ref.read(localeProvider.notifier).set(me.language);
    }
  }

  /// Called by the API client when refresh failed.
  void expire() {
    if (state.status != AuthStatus.unauthenticated) {
      state = const SessionState(AuthStatus.unauthenticated);
    }
  }

  Future<void> logout() async {
    final t = await _tokens.read();
    if (t != null) {
      // Stop pushes to this device while the access token is still valid.
      try {
        await ref.read(pushServiceProvider).unregister();
      } catch (_) {}
      try {
        await ref.read(authRepositoryProvider).logout(t.refreshToken);
      } catch (_) {
        // Logging out locally must always succeed.
      }
    }
    await _tokens.clear();
    try {
      await ref.read(sharedPrefsProvider).remove(ActivePatientIdNotifier._key);
    } catch (_) {}
    state = const SessionState(AuthStatus.unauthenticated);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

// ------------------------------------------------------------------ Family / active patient

final patientsProvider = FutureProvider<List<PatientSummary>>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.me?.id));
  if (userId == null) return const [];
  final list = await ref.watch(patientRepositoryProvider).list();
  // Self first, as the contract promises; be defensive anyway.
  list.sort((a, b) => (b.isSelf ? 1 : 0) - (a.isSelf ? 1 : 0));
  return list;
});

class ActivePatientIdNotifier extends Notifier<String?> {
  static const _key = 'cc_active_patient';

  @override
  String? build() {
    try {
      return ref.read(sharedPrefsProvider).getString(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> select(String id) async {
    state = id;
    try {
      await ref.read(sharedPrefsProvider).setString(_key, id);
    } catch (_) {}
  }
}

final activePatientIdProvider =
    NotifierProvider<ActivePatientIdNotifier, String?>(ActivePatientIdNotifier.new);

/// The patient the user is currently acting for (self or a family member).
/// All patient-scoped calls use this.
final activePatientProvider = FutureProvider<PatientSummary>((ref) async {
  final list = await ref.watch(patientsProvider.future);
  if (list.isEmpty) {
    throw ApiException(code: 'NOT_FOUND', message: 'No patient profile');
  }
  final id = ref.watch(activePatientIdProvider);
  return list.firstWhere((p) => p.id == id, orElse: () => list.first);
});
