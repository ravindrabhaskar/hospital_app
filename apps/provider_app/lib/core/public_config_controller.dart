import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json.dart';
import '../models/public_config.dart';
import 'api/api_client.dart';

/// Reads the installed app version ("1.2.0"); null when unknown.
typedef AppVersionReader = Future<String?> Function();

Future<String?> readPackageVersion() async {
  try {
    return (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    return null;
  }
}

/// Loads `GET /config/public` at startup (contract §21) and caches it in
/// shared preferences (it is public, not sensitive), so support contacts and
/// the minimum version still apply when the app starts offline.
///
/// Everything is fail-soft: without config the app simply isn't gated.
class PublicConfigController extends ChangeNotifier {
  PublicConfigController({
    required this.api,
    AppVersionReader? appVersion,
  }) : _readVersion = appVersion ?? readPackageVersion;

  static const _cacheKey = 'config.public';

  final ApiClient api;
  final AppVersionReader _readVersion;

  PublicConfig? _config;
  String? _appVersion;

  PublicConfig? get config => _config;
  String? get appVersion => _appVersion;

  TargetPlatform? get _effectivePlatform => kIsWeb ? null : defaultTargetPlatform;

  /// Minimum provider-app version for this platform, if any.
  String? get minimumVersion => switch (_effectivePlatform) {
        TargetPlatform.android => _config?.minProviderAndroid,
        TargetPlatform.iOS => _config?.minProviderIos,
        _ => null,
      };

  /// True when the installed build is older than the server's minimum.
  bool get updateRequired {
    final min = minimumVersion;
    final current = _appVersion;
    if (min == null || current == null) return false;
    return isVersionBelow(current, min);
  }

  Future<void> load() async {
    _appVersion = await _readVersion();
    await _loadCached();
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final res = await api.get('/config/public');
      if (res is! Map) return;
      _config = PublicConfig.fromJson(asJson(res));
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(_config!.toJson()));
      } catch (_) {}
    } catch (_) {
      // Offline or older backend: keep the cached copy.
    }
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      _config = PublicConfig.fromJson(asJson(jsonDecode(raw)));
      notifyListeners();
    } catch (_) {}
  }
}
