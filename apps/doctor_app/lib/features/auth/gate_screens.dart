import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/public_config.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// Shown when the signed-in account is not a doctor: patients, providers and
/// ops staff are pointed at the right app / portal.
class RestrictedScreen extends ConsumerWidget {
  const RestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final roles = ref.watch(authControllerProvider).me?.roles ?? const <String>[];
    final String hint;
    if (roles.contains('provider')) {
      hint = l.restrictedProvider;
    } else if (roles.any(
      (r) => const ['coordinator', 'ops_admin', 'super_admin', 'support_agent', 'hospital_staff'].contains(r),
    )) {
      hint = l.restrictedStaff;
    } else {
      hint = l.restrictedPatient;
    }
    return GateScaffold(
      icon: Icons.lock_outline,
      iconColor: AppColors.dangerDeep,
      iconBg: AppColors.dangerBg,
      title: l.restrictedTitle,
      actions: [
        OutlinedButton(
          key: const Key('restrictedLogout'),
          onPressed: () => ref.read(authControllerProvider).logout(),
          child: Text(l.commonLogout),
        ),
      ],
      children: [
        Text(l.restrictedBody, textAlign: TextAlign.center, key: const Key('restrictedBody')),
        gap12,
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.mint50, borderRadius: BorderRadius.circular(16)),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Session exists but identity couldn't be loaded and nothing is cached.
class StartupErrorScreen extends ConsumerWidget {
  const StartupErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: ErrorView(error: auth.error ?? Exception(), onRetry: auth.loadIdentity),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: TextButton(onPressed: auth.logout, child: Text(l.commonLogout)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: LoadingView());
}

class GateScaffold extends StatelessWidget {
  const GateScaffold({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.children,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                      child: Icon(icon, size: 44, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  gap12,
                  ...children,
                  const SizedBox(height: 24),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Blocking "please update" screen driven by `minAppVersion` (contract §21).
class UpdateRequiredView extends StatelessWidget {
  const UpdateRequiredView({
    super.key,
    required this.currentVersion,
    required this.minimumVersion,
    this.storeUrl,
    this.support,
  });

  final String currentVersion;
  final String minimumVersion;
  final Uri? storeUrl;
  final SupportContact? support;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GateScaffold(
      icon: Icons.system_update_outlined,
      iconColor: AppColors.primary,
      iconBg: AppColors.mint50,
      title: l.updateTitle,
      actions: [
        if (storeUrl != null)
          FilledButton.icon(
            key: const Key('updateNow'),
            onPressed: () => openExternal(context, storeUrl!),
            icon: const Icon(Icons.download_outlined),
            label: Text(l.updateNow),
          ),
      ],
      children: [
        Text(l.updateBody, textAlign: TextAlign.center, key: const Key('updateBody')),
        gap8,
        Text(
          l.updateVersions(currentVersion, minimumVersion),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (support != null && !support!.isEmpty) ...[gap16, SupportContactButtons(support: support!)],
      ],
    );
  }
}

class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(publicConfigProvider);
    return ListenableBuilder(
      listenable: cfg,
      builder: (context, _) => UpdateRequiredView(
        currentVersion: cfg.appVersion ?? '?',
        minimumVersion: cfg.minimumVersion ?? '?',
        storeUrl: AppConfig.storeUrl,
        support: cfg.config?.support,
      ),
    );
  }
}
