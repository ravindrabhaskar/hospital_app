import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/storage/namespaced_prefs.dart';
import 'state/core_providers.dart';

/// Builds the complete patient app (what `main()` runs).
///
/// * [storagePrefix] namespaces every secure-storage and shared-preferences
///   key, so the app can share a process with the other CareCompanion apps
///   (all-in-one demo build) without sharing tokens, caches or settings.
///   Empty (the default) keeps the standalone keys and existing data.
/// * [onSwitchApp], when given, adds a "Switch app" entry to Profile.
Future<Widget> buildPatientApp({String storagePrefix = '', VoidCallback? onSwitchApp}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var version = AppConfig.fallbackAppVersion;
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  return ProviderScope(
    // Retries are user-driven (Retry buttons), never automatic, so that
    // 4xx business errors are surfaced instead of silently re-sent.
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(namespacedPrefs(prefs, storagePrefix)),
      appVersionProvider.overrideWithValue(version),
      storagePrefixProvider.overrideWithValue(storagePrefix),
      switchAppProvider.overrideWithValue(onSwitchApp),
    ],
    child: const CareCompanionApp(),
  );
}
