import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/providers.dart';
import 'core/server/server_settings.dart';

/// Builds the complete doctor app (what `main()` runs).
///
/// * [storagePrefix] namespaces every secure-storage and shared-preferences
///   key (and the private file directories), so the app can share a process
///   with the other CareCompanion apps (all-in-one demo build) without sharing
///   tokens, the offline queue, caches or settings. Empty (the default) keeps
///   the standalone keys and existing data.
/// * [onSwitchApp], when given, adds a "Switch app" entry to More.
Future<Widget> buildDoctorApp({String storagePrefix = '', VoidCallback? onSwitchApp}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Runtime "Server address" (demo builds). Global, unprefixed key: in the
  // all-in-one build every role shares one server setting.
  final server = await ServerSettings.load(
    defaultUrl: AppConfig.apiBaseUrl,
    overrideAllowed: AppConfig.serverOverrideAllowed,
  );
  return ProviderScope(
    // Riverpod 3 retries failing providers by default; our screens show an
    // explicit error + retry instead.
    retry: (retryCount, error) => null,
    overrides: [
      storagePrefixProvider.overrideWithValue(storagePrefix),
      switchAppProvider.overrideWithValue(onSwitchApp),
      serverSettingsProvider.overrideWithValue(server),
    ],
    child: const DoctorApp(),
  );
}
