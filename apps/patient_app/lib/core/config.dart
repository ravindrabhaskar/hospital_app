import 'package:flutter/foundation.dart';

/// Runtime configuration. The API base URL comes from
/// `--dart-define=API_BASE_URL=...`; otherwise a sensible local default is
/// used (Android emulator reaches the host machine through 10.0.2.2).
class AppConfig {
  AppConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _stripSlash(_definedBaseUrl);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  static String _stripSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;

  static const String emergencyHelpline = '108';

  static const Duration requestTimeout = Duration(seconds: 25);

  /// Used until package_info_plus reports the real version (and in tests).
  static const String fallbackAppVersion = '1.0.0';
}

// Feature flags now come from `GET /config/public` (API_CONTRACT §21):
// see `featureFlagsProvider` and `FeatureFlags` in models/config.dart.
