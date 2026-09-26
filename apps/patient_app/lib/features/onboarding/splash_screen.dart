import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Config (flags, gateway, minAppVersion) loads in parallel; the cached
      // copy is already in effect, so the session never waits for it.
      ref.read(publicConfigProvider.notifier).refresh();
      ref.read(sessionProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = ref.watch(sessionProvider).status;
    return Scaffold(
      backgroundColor: context.mintSurface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RobotAssistant(size: 120, semanticLabel: l.robotSemantic),
                const SizedBox(height: Space.xl),
                Text(l.appName,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(color: AppColors.primaryDark)),
                const SizedBox(height: Space.xs),
                Text(l.tagline, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.xxxl),
                if (status == AuthStatus.offline)
                  ErrorStateView(
                    compact: true,
                    error: ApiException(code: ApiException.network, message: ''),
                    onRetry: () {
                      ref.read(publicConfigProvider.notifier).refresh();
                      ref.read(sessionProvider.notifier).bootstrap();
                    },
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
