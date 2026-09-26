import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../models/public_config.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// Shown when the signed-in account lacks the `provider` role.
class RestrictedScreen extends ConsumerWidget {
  const RestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return _GateScaffold(
      icon: Icons.lock_outline,
      iconColor: AppColors.dangerDeep,
      iconBg: AppColors.dangerBg,
      title: l.restrictedTitle,
      actions: [
        OutlinedButton(
          onPressed: () => ref.read(authControllerProvider).logout(),
          child: Text(l.commonLogout),
        ),
      ],
      children: [Text(l.restrictedBody, textAlign: TextAlign.center)],
    );
  }
}

/// Blocking screen for providers whose verification is not `verified`.
/// Pure presentation so it can be tested for every status.
class VerificationBlockedView extends StatelessWidget {
  const VerificationBlockedView({
    super.key,
    required this.status,
    this.credentialExpiresAt,
    required this.onCheckAgain,
    required this.onLogout,
    this.busy = false,
  });

  final String status;
  final DateTime? credentialExpiresAt;
  final VoidCallback onCheckAgain;
  final VoidCallback onLogout;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final String reason;
    IconData icon = Icons.hourglass_top;
    switch (status) {
      case 'expired':
        reason = l.blockedExpired;
        icon = Icons.event_busy_outlined;
      case 'suspended':
        reason = l.blockedSuspended;
        icon = Icons.block;
      case 'rejected':
        reason = l.blockedRejected;
        icon = Icons.cancel_outlined;
      default:
        reason = l.blockedPending;
    }
    return _GateScaffold(
      icon: icon,
      iconColor: const Color(0xFF9A5A10),
      iconBg: AppColors.warningBg,
      title: l.blockedTitle,
      actions: [
        FilledButton(
          onPressed: busy ? null : onCheckAgain,
          child: Text(l.blockedCheckAgain),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onLogout, child: Text(l.commonLogout)),
      ],
      children: [
        Semantics(
          label: '${l.profileVerification}: ${verificationLabel(l, status)}',
          excludeSemantics: true,
          child: Chip(
            key: const Key('verificationStatusChip'),
            label: Text(verificationLabel(l, status)),
            backgroundColor: AppColors.warningBg,
          ),
        ),
        const SizedBox(height: 12),
        Text(reason, textAlign: TextAlign.center, key: const Key('blockedReason')),
        if (status == 'expired' && credentialExpiresAt != null) ...[
          const SizedBox(height: 8),
          Text(l.blockedExpiredOn(formatDate(context, credentialExpiresAt)),
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.mint50, borderRadius: BorderRadius.circular(16)),
          child: Text(l.blockedNoVisits, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class VerificationBlockedScreen extends ConsumerStatefulWidget {
  const VerificationBlockedScreen({super.key});

  @override
  ConsumerState<VerificationBlockedScreen> createState() => _VerificationBlockedScreenState();
}

class _VerificationBlockedScreenState extends ConsumerState<VerificationBlockedScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final profile = auth.profile;
        return VerificationBlockedView(
          status: profile?.verificationStatus ?? 'pending',
          credentialExpiresAt: profile?.credentialExpiresAt,
          busy: _busy,
          onCheckAgain: () async {
            setState(() => _busy = true);
            await auth.refreshProfile();
            if (mounted) setState(() => _busy = false);
          },
          onLogout: auth.logout,
        );
      },
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
                child: ErrorView(
                  message: errorMessage(l, auth.error ?? Exception()),
                  onRetry: auth.loadIdentity,
                ),
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

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({
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
                    child: Text(title,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 12),
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

/// `403 MFA_REQUIRED` (contract §22): providers aren't MFA-enforced, so the
/// account needs attention from support. Nothing queued is discarded.
class MfaRequiredScreen extends ConsumerWidget {
  const MfaRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final support = ref.watch(publicConfigProvider).config?.support;
    return _GateScaffold(
      icon: Icons.phonelink_lock_outlined,
      iconColor: const Color(0xFF9A5A10),
      iconBg: AppColors.warningBg,
      title: l.mfaTitle,
      actions: [
        FilledButton(onPressed: auth.loadIdentity, child: Text(l.blockedCheckAgain)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: auth.logout, child: Text(l.commonLogout)),
      ],
      children: [
        Text(l.mfaBody, textAlign: TextAlign.center, key: const Key('mfaBody')),
        if (support != null && !support.isEmpty) ...[
          const SizedBox(height: 16),
          SupportContactButtons(support: support),
        ],
      ],
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
    return _GateScaffold(
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
        const SizedBox(height: 8),
        Text(
          l.updateVersions(currentVersion, minimumVersion),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (support != null && !support!.isEmpty) ...[
          const SizedBox(height: 16),
          SupportContactButtons(support: support!),
        ],
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
