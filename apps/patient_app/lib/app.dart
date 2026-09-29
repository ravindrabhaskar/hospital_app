import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/branding.dart';
import 'core/utils/format.dart';
import 'features/home/notifications_screen.dart' show resolveDeepLink;
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'state/core_providers.dart';

const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class CareCompanionApp extends ConsumerStatefulWidget {
  const CareCompanionApp({super.key});

  @override
  ConsumerState<CareCompanionApp> createState() => _CareCompanionAppState();
}

class _CareCompanionAppState extends ConsumerState<CareCompanionApp> {
  @override
  void initState() {
    super.initState();
    _initPush();
  }

  /// Push is initialised only when Firebase options were provided via
  /// --dart-define; otherwise every call below is a silent no-op.
  Future<void> _initPush() async {
    final push = ref.read(pushServiceProvider);
    push.onOpenDeepLink = _openDeepLink;
    push.askPermission = _askPushPermission;
    final ok = await push.init();
    if (ok && mounted && ref.read(sessionProvider).isAuthenticated) {
      await push.onSignedIn();
    }
  }

  void _openDeepLink(String link) {
    final target = resolveDeepLink(link);
    if (target != null) ref.read(routerProvider).push(target);
  }

  /// A polite explanation before the OS prompt (Android 13+ / iOS).
  Future<bool> _askPushPermission() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return true;
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: Text(l.pushPermissionTitle),
        content: Text(l.pushPermissionBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.notNow)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.allow)),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (prev, next) {
      bool ready(SessionState? s) => s != null && s.isAuthenticated && !s.needsOnboarding;
      if (!ready(prev) && ready(next)) {
        final push = ref.read(pushServiceProvider);
        push.onSignedIn().then((_) {
          final pending = push.takePendingDeepLink();
          if (pending != null) _openDeepLink(pending);
        });
      }
    });
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    // White-label (§58): the tenant's name and primary colour.
    final branding = ref.watch(brandingProvider);
    final seed = brandSeedColor(branding);
    return MaterialApp.router(
      onGenerateTitle: (c) => (branding?.displayName.isNotEmpty ?? false)
          ? branding!.displayName
          : AppLocalizations.of(c).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed: seed),
      darkTheme: AppTheme.dark(seed: seed),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: localizationsDelegates,
      routerConfig: router,
    );
  }
}
