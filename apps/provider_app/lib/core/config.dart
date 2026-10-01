import 'package:flutter/foundation.dart';

import 'server/server_settings.dart';

/// Build-time configuration.
///
/// Override the API with `--dart-define=API_BASE_URL=https://host/api/v1`.
class AppConfig {
  AppConfig._();

  static const String _apiFromEnv = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  /// Whether the runtime "Server address" override is available: non-https
  /// (development / demo) builds, or `--dart-define=ALLOW_SERVER_OVERRIDE=true`.
  /// Always false for https production builds.
  static bool get serverOverrideAllowed =>
      ServerSettings.isOverrideAllowed(compiledBaseUrl: apiBaseUrl, allowFlag: ServerSettings.allowFlag);

  /// How often the device location is reported while on duty.
  static const Duration locationInterval = Duration(seconds: 60);

  /// Completed visits older than this are purged from the local cache.
  static const Duration completedVisitRetention = Duration(hours: 24);

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Store listing used by the force-update screen. Android defaults to the
  /// Play listing for the application id; iOS needs the App Store URL
  /// (`--dart-define=APP_STORE_URL=https://apps.apple.com/app/id...`).
  static const String androidApplicationId = 'com.carecompanion.provider';
  static const String _appStoreUrl = String.fromEnvironment('APP_STORE_URL');

  static Uri? get storeUrl {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Uri.https('play.google.com', '/store/apps/details', {'id': androidApplicationId});
      case TargetPlatform.iOS:
        return _appStoreUrl.isEmpty ? null : Uri.parse(_appStoreUrl);
      default:
        return null;
    }
  }
}
