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
import 'features/auth/mfa_screen.dart';
import 'features/consultation/consultation_screen.dart';
import 'features/messages/inbox_screen.dart';
import 'features/messages/thread_screen.dart';
import 'features/more/earnings_screen.dart';
import 'features/more/escalations_screen.dart';
import 'features/more/language_screen.dart';
import 'features/more/more_screen.dart';
import 'features/more/profile_screen.dart';
import 'features/more/schedule_screen.dart';
import 'features/more/second_opinions_screen.dart';
import 'features/patients/patient_detail_screen.dart';
import 'features/patients/patients_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/today/today_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'models/clinical.dart';

/// Gate routes: the router forces the user onto the one matching auth status.
String? gateLocation(AuthStatus status) => switch (status) {
  AuthStatus.initializing => '/splash',
  AuthStatus.signedOut => '/login',
  AuthStatus.mfa => '/mfa',
  AuthStatus.restricted => '/restricted',
  AuthStatus.error => '/startup-error',
  AuthStatus.ready => null,
};

const _gateRoutes = {'/splash', '/login', '/mfa', '/restricted', '/startup-error', '/update'};

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) => GlobalKey<NavigatorState>());

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final config = ref.watch(publicConfigProvider);
  final rootKey = ref.watch(rootNavigatorKeyProvider);
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([auth, config]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // The force-update gate wins over everything else (§21 minAppVersion).
      if (config.updateRequired) return loc == '/update' ? null : '/update';
      final gate = gateLocation(auth.status);
      if (gate != null) return loc == gate ? null : gate;
      if (_gateRoutes.contains(loc) || loc == '/') return '/today';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/today'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/mfa', builder: (_, _) => const MfaScreen()),
      GoRoute(path: '/restricted', builder: (_, _) => const RestrictedScreen()),
      GoRoute(path: '/startup-error', builder: (_, _) => const StartupErrorScreen()),
      GoRoute(path: '/update', builder: (_, _) => const UpdateRequiredScreen()),
      GoRoute(
        path: '/consultation/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => ConsultationScreen(
          appointmentId: state.pathParameters['id']!,
          initial: state.extra is Appointment ? state.extra as Appointment : null,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                builder: (_, _) => const PatientsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootKey,
                    builder: (_, state) => PatientDetailScreen(patientId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, _) => const InboxScreen(),
                routes: [
                  GoRoute(
                    path: ':episodeId',
                    parentNavigatorKey: rootKey,
                    builder: (_, state) => ThreadScreen(
                      episodeId: state.pathParameters['episodeId']!,
                      title: state.extra is String ? state.extra as String : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'second-opinions',
                    parentNavigatorKey: rootKey,
                    builder: (_, _) => const SecondOpinionsScreen(),
                  ),
                  GoRoute(
                    path: 'escalations',
                    parentNavigatorKey: rootKey,
                    builder: (_, _) => const EscalationsScreen(),
                  ),
                  GoRoute(path: 'schedule', parentNavigatorKey: rootKey, builder: (_, _) => const ScheduleScreen()),
                  GoRoute(path: 'earnings', parentNavigatorKey: rootKey, builder: (_, _) => const EarningsScreen()),
                  GoRoute(path: 'profile', parentNavigatorKey: rootKey, builder: (_, _) => const ProfileScreen()),
                  GoRoute(path: 'language', parentNavigatorKey: rootKey, builder: (_, _) => const LanguageScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class DoctorApp extends ConsumerStatefulWidget {
  const DoctorApp({super.key});

  @override
  ConsumerState<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends ConsumerState<DoctorApp> {
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
    _pushSub = push.openRoute.listen(_openFromPush);
    // Push must be ready before sign-in completes so the device registers.
    push.init().whenComplete(() => ref.read(authControllerProvider).init());
  }

  /// Notification tap: open the route once the doctor is signed in.
  void _openFromPush(String route) {
    final auth = ref.read(authControllerProvider);
    final router = ref.read(routerProvider);
    if (auth.status == AuthStatus.ready) {
      router.push(route);
      return;
    }
    void listener() {
      if (auth.status == AuthStatus.ready) {
        auth.removeListener(listener);
        router.push(route);
      } else if (auth.status == AuthStatus.signedOut) {
        auth.removeListener(listener);
      }
    }

    auth.addListener(listener);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
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
