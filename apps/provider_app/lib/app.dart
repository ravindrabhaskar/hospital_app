import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/gate_screens.dart';
import 'features/auth/login_screen.dart';
import 'features/care_plans/diet_plan_screen.dart';
import 'features/care_plans/exercise_plan_screen.dart';
import 'features/earnings/earnings_screen.dart';
import 'features/field/attendance_screen.dart';
import 'features/field/supplies_screen.dart';
import 'features/offline/visit_action_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/visits/data/visit_providers.dart';
import 'features/visits/ui/home_screen.dart';
import 'features/visits/domain/visit_lifecycle.dart';
import 'features/visits/ui/visit_detail_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'ui/l10n_helpers.dart';

/// Gate routes: the router forces the user onto the one matching auth status.
String? gateLocation(AuthStatus status) => switch (status) {
      AuthStatus.initializing => '/splash',
      AuthStatus.signedOut => '/login',
      AuthStatus.restricted => '/restricted',
      AuthStatus.blocked => '/blocked',
      AuthStatus.error => '/startup-error',
      AuthStatus.mfaRequired => '/mfa-required',
      AuthStatus.ready => null,
    };

const _gateRoutes = {'/splash', '/login', '/restricted', '/blocked', '/startup-error', '/mfa-required', '/update'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final config = ref.watch(publicConfigProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([auth, config]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // The force-update gate wins over everything else (§21 minAppVersion).
      if (config.updateRequired) return loc == '/update' ? null : '/update';
      final gate = gateLocation(auth.status);
      if (gate != null) return loc == gate ? null : gate;
      if (_gateRoutes.contains(loc)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // Accounts without the provider role apply to join (contract §30).
      GoRoute(path: '/restricted', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/blocked', builder: (_, _) => const VerificationBlockedScreen()),
      GoRoute(path: '/startup-error', builder: (_, _) => const StartupErrorScreen()),
      GoRoute(path: '/mfa-required', builder: (_, _) => const MfaRequiredScreen()),
      GoRoute(path: '/update', builder: (_, _) => const UpdateRequiredScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/earnings', builder: (_, _) => const EarningsScreen()),
      GoRoute(path: '/attendance', builder: (_, _) => const AttendanceScreen()),
      GoRoute(path: '/supplies', builder: (_, _) => const SuppliesScreen()),
      GoRoute(
        path: '/visits/:id',
        builder: (_, state) => VisitDetailScreen(visitId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'exercise-plan',
            builder: (_, state) => ExercisePlanScreen(
              patientId: state.uri.queryParameters['patientId'] ?? '',
              patientName: state.uri.queryParameters['patientName'],
              careEpisodeId: state.uri.queryParameters['careEpisodeId'],
            ),
          ),
          GoRoute(
            path: 'diet-plan',
            builder: (_, state) => DietPlanScreen(
              patientId: state.uri.queryParameters['patientId'] ?? '',
              patientName: state.uri.queryParameters['patientName'],
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class ProviderApp extends ConsumerStatefulWidget {
  const ProviderApp({super.key});

  @override
  ConsumerState<ProviderApp> createState() => _ProviderAppState();
}

class _ProviderAppState extends ConsumerState<ProviderApp> {
  StreamSubscription<SyncEvent>? _syncSub;
  StreamSubscription<String>? _pushSub;

  @override
  void initState() {
    super.initState();
    final locale = ref.read(localeControllerProvider);
    locale.load().then((_) {
      final code = locale.locale?.languageCode;
      if (code != null) ref.read(apiClientProvider).languageCode = code;
    });
    ref.read(publicConfigProvider).load();
    final push = ref.read(pushServiceProvider);
    _pushSub = push.openVisit.listen(_openVisitFromPush);
    // Push must be ready before sign-in completes so the device registers.
    push.init().whenComplete(() => ref.read(authControllerProvider).init());
    _syncSub = ref.read(visitActionServiceProvider).events.listen(_onSyncEvent);
  }

  /// Notification tap: open the visit once the provider is signed in.
  void _openVisitFromPush(String visitId) {
    final auth = ref.read(authControllerProvider);
    final router = ref.read(routerProvider);
    if (auth.status == AuthStatus.ready) {
      router.push('/visits/$visitId');
      return;
    }
    void listener() {
      if (auth.status == AuthStatus.ready) {
        auth.removeListener(listener);
        router.push('/visits/$visitId');
      } else if (auth.status != AuthStatus.initializing) {
        auth.removeListener(listener);
      }
    }

    auth.addListener(listener);
  }

  /// Background replay results: refresh data and tell the user when needed.
  void _onSyncEvent(SyncEvent event) {
    ref.invalidate(visitListProvider);
    ref.invalidate(visitDetailProvider(event.visitId));
    if (event.type == VisitActionType.suppliesUsage) ref.invalidate(suppliesProvider);
    if (event.foreground) return; // the screen that triggered it reports itself
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    final ctx = ref.read(scaffoldMessengerKeyProvider).currentContext;
    if (messenger == null || ctx == null) return;
    final l = AppLocalizations.of(ctx);
    if (event.type == VisitActionType.photo) {
      _onPhotoEvent(event, messenger, l);
      return;
    }
    switch (event.kind) {
      case SyncEventKind.accessRevoked:
        messenger.showSnackBar(SnackBar(content: Text(l.syncAccessRevoked), duration: const Duration(seconds: 8)));
      case SyncEventKind.rejected:
        messenger.showSnackBar(SnackBar(
          content: Text(l.syncRejected(event.error?.message ?? l.errorGeneric)),
          duration: const Duration(seconds: 8),
        ));
      case SyncEventKind.synced:
        break;
    }
  }

  void _onPhotoEvent(SyncEvent event, ScaffoldMessengerState messenger, AppLocalizations l) {
    final String? text = switch (event.kind) {
      SyncEventKind.synced => l.photoUploaded,
      SyncEventKind.rejected when event.error?.statusCode == 403 => l.photoNoPermission,
      SyncEventKind.rejected => errorMessage(l, event.error ?? Exception()),
      SyncEventKind.accessRevoked => null,
    };
    if (text != null) {
      messenger.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 8)));
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final localeCtrl = ref.watch(localeControllerProvider);
    return ListenableBuilder(
      listenable: localeCtrl,
      builder: (context, _) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
        theme: buildAppTheme(),
        locale: localeCtrl.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    );
  }
}
