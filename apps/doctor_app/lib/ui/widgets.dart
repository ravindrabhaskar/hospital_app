import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api/api_exception.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../models/public_config.dart';
import 'l10n_helpers.dart';

/// Colored pill. Always pairs color with text (never color alone).
class TonePill extends StatelessWidget {
  const TonePill({super.key, required this.label, required this.bg, required this.fg, this.icon, this.semanticsPrefix});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsPrefix == null ? label : '$semanticsPrefix: $label',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

const warningFg = Color(0xFF9A5A10);

/// Appointment status chip (contract §7 statuses).
class ApptStatusChip extends StatelessWidget {
  const ApptStatusChip({super.key, required this.status});
  final String status;

  static (Color, Color) colorsFor(String status) => switch (status) {
    'confirmed' => (AppColors.skyBg, AppColors.sky),
    'in_progress' => (AppColors.mint100, AppColors.primary),
    'completed' => (AppColors.mint50, AppColors.primaryLight),
    'cancelled' || 'no_show' => (AppColors.dangerBg, AppColors.dangerDeep),
    _ => (AppColors.warningBg, warningFg),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status);
    return TonePill(
      key: Key('apptStatus.$status'),
      label: apptStatusLabel(context.l10n, status),
      bg: bg,
      fg: fg,
      semanticsPrefix: context.l10n.statusLabel,
    );
  }
}

/// Episode priority chip: routine / urgent / emergency.
class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (priority) {
      'emergency' => (AppColors.dangerBg, AppColors.dangerDeep, Icons.emergency_outlined),
      'urgent' => (AppColors.warningBg, warningFg, Icons.priority_high),
      _ => (AppColors.mint50, AppColors.primaryLight, null),
    };
    return TonePill(
      key: Key('priority.$priority'),
      label: priorityLabel(context.l10n, priority),
      bg: bg,
      fg: fg,
      icon: icon,
      semanticsPrefix: context.l10n.priorityLabel,
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.color, this.icon});
  final String? title;
  final Widget child;
  final Widget? trailing;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title!, style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: context.l10n.commonLoading,
      child: const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
    ),
  );
}

/// Error state. Offline, unauthorized and forbidden errors get their own
/// icon so the doctor can tell them apart at a glance.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = error;
    final icon = e is ApiException
        ? (e.isNetwork
              ? Icons.cloud_off_outlined
              : e.isForbidden || e.isMfaRequired
              ? Icons.lock_outline
              : Icons.error_outline)
        : Icons.error_outline;
    final message = errorMessage(l, error);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                key: const Key('errorMessage'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (onRetry != null && !(e is ApiException && e.isForbidden)) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(l.commonRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.mint100, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

/// Renders an [AsyncValue] with the shared loading / error / data states.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: true,
    data: data,
    loading: () => const LoadingView(),
    error: (e, _) => ErrorView(error: e, onRetry: onRetry),
  );
}

/// "You are offline" banner for the top of the shell.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineStatusProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('offlineBanner'),
        color: AppColors.warningBg,
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: warningFg, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.offlineBanner,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: AppColors.primaryLight), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The lavender "AI-generated · advisory" container used for every piece of
/// AI text (design system: AI content marker).
class AiAdvisoryCard extends StatelessWidget {
  const AiAdvisoryCard({super.key, required this.child, this.title, this.footer});
  final Widget child;
  final String? title;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      key: const Key('aiAdvisoryCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lavenderBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.lavender),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title ?? l.aiSummaryTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF4B3A99)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.aiAdvisoryLabel,
            key: const Key('aiAdvisoryLabel'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lavender),
          ),
          const SizedBox(height: 10),
          child,
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

/// Red-tinted allergy block: allergies are always shown prominently.
class AllergyBanner extends StatelessWidget {
  const AllergyBanner({super.key, required this.allergies});
  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final none = allergies.isEmpty;
    return Semantics(
      container: true,
      label: none ? l.allergiesNone : '${l.allergiesTitle}: ${allergies.join(', ')}',
      excludeSemantics: true,
      child: Container(
        key: const Key('allergyBanner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: none ? AppColors.mint50 : AppColors.dangerBg,
          borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
          border: Border.all(color: none ? AppColors.border : AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              none ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: none ? AppColors.primaryLight : AppColors.dangerDeep,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.allergiesTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: none ? AppColors.textPrimary : AppColors.dangerDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    none ? l.allergiesNone : allergies.join(', '),
                    style: TextStyle(
                      fontWeight: none ? FontWeight.w400 : FontWeight.w600,
                      color: none ? AppColors.textSecondary : AppColors.dangerDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.dangerDeep : null));
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color = Colors.white});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color));
}

/// Opens [uri] outside the app; shows a snackbar if nothing can handle it.
Future<bool> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.linkFailed;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  return ok;
}

Uri supportMailUri(String email) => Uri(scheme: 'mailto', path: email);
Uri supportPhoneUri(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[\s()-]'), ''));
Uri supportWhatsappUri(String number) => Uri.https('wa.me', '/${number.replaceAll(RegExp(r'[^0-9]'), '')}');

/// Call / email / WhatsApp buttons from the public config support block.
class SupportContactButtons extends StatelessWidget {
  const SupportContactButtons({super.key, required this.support});
  final SupportContact support;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (support.phone != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.call_outlined, color: AppColors.primary),
            title: Text(l.supportCall),
            subtitle: Text(support.phone!),
            onTap: () => openExternal(context, supportPhoneUri(support.phone!)),
          ),
        if (support.email != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: Text(l.supportEmail),
            subtitle: Text(support.email!),
            onTap: () => openExternal(context, supportMailUri(support.email!)),
          ),
        if (support.whatsapp != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_outlined, color: AppColors.primary),
            title: Text(l.supportWhatsapp),
            subtitle: Text(support.whatsapp!),
            onTap: () => openExternal(context, supportWhatsappUri(support.whatsapp!)),
          ),
      ],
    );
  }
}

/// Screen scaffold used by pushed full-screen forms.
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.title, required this.children, this.bottom});
  final String title;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(AppSpacing.screen), children: children),
          ),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, AppSpacing.screen),
              child: bottom,
            ),
        ],
      ),
    ),
  );
}

const gap8 = SizedBox(height: 8);
const gap12 = SizedBox(height: 12);
const gap16 = SizedBox(height: 16);
