import 'package:flutter/foundation.dart';

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

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Uploads (scribe audio up to 25 MB, photos) get more time.
  static const Duration uploadTimeout = Duration(seconds: 120);

  /// Care-team threads poll while open (contract §34).
  static const Duration messagePollInterval = Duration(seconds: 10);

  /// Debounce for the live prescription interaction check (contract §47).
  static const Duration rxCheckDebounce = Duration(milliseconds: 600);

  /// Store listing used by the force-update screen. Android defaults to the
  /// Play listing for the application id; iOS needs the App Store URL
  /// (`--dart-define=APP_STORE_URL=https://apps.apple.com/app/id...`).
  static const String androidApplicationId = 'com.carecompanion.doctor';
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
