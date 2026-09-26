import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config.dart';
import 'state/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var version = AppConfig.fallbackAppVersion;
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  runApp(
    ProviderScope(
      // Retries are user-driven (Retry buttons), never automatic, so that
      // 4xx business errors are surfaced instead of silently re-sent.
      retry: (_, _) => null,
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        appVersionProvider.overrideWithValue(version),
      ],
      child: const CareCompanionApp(),
    ),
  );
}
