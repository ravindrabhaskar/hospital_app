import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../models/home_visit.dart';
import '../models/public_config.dart';
import 'l10n_helpers.dart';

/// Colored status pill. Always pairs color with text (never color alone).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;

  static (Color bg, Color fg) colorsFor(String status) {
    switch (status) {
      case VisitStatus.assigned:
        return (AppColors.skyBg, AppColors.sky);
      case VisitStatus.accepted:
      case VisitStatus.enRoute:
      case VisitStatus.arrived:
        return (AppColors.lavenderBg, AppColors.lavender);
      case VisitStatus.inProgress:
        return (AppColors.mint100, AppColors.primary);
      case VisitStatus.completed:
        return (AppColors.mint50, AppColors.primaryLight);
      case VisitStatus.escalated:
      case VisitStatus.cancelled:
        return (AppColors.dangerBg, AppColors.dangerDeep);
      default:
        return (AppColors.warningBg, const Color(0xFF9A5A10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status);
    final label = visitStatusLabel(context.l10n, status);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.color});
  final String? title;
  final Widget child;
  final Widget? trailing;
  final Color? color;

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
          child: const CircularProgressIndicator(),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.icon = Icons.error_outline});
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textSecondary, semanticLabel: message),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
              ],
            ],
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon = Icons.event_available_outlined});
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
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

/// "You are offline" + "Pending sync (n)" banners, shown at the top of screens.
class SyncBanners extends ConsumerWidget {
  const SyncBanners({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final online = ref.watch(onlineStatusProvider).value ?? true;
    final queue = ref.watch(offlineQueueProvider);
    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final count = queue.pendingCount;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!online)
              _Banner(
                color: AppColors.warningBg,
                icon: Icons.cloud_off_outlined,
                iconColor: const Color(0xFF9A5A10),
                text: l.offlineBanner,
              ),
            if (count > 0)
              _Banner(
                color: AppColors.skyBg,
                icon: Icons.sync,
                iconColor: AppColors.sky,
                text: l.pendingSync(count),
                action: online
                    ? TextButton(
                        onPressed: () => ref.read(visitActionServiceProvider).syncNow(),
                        child: Text(l.syncNow),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.iconColor, required this.text, this.action});
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          color: color,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              ?action,
            ],
          ),
        ),
      );
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
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primaryLight),
                const SizedBox(width: 10),
              ],
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

/// Opens [uri] outside the app; shows a snackbar if nothing can handle it.
Future<void> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = context.l10n.profileLinkFailed;
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failed)));
}

Uri supportMailUri(String email, {String? subject}) =>
    Uri(scheme: 'mailto', path: email, query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}');

Uri supportPhoneUri(String phone) => Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[\s()-]'), ''));

Uri supportWhatsappUri(String number) =>
    Uri.https('wa.me', '/${number.replaceAll(RegExp(r'[^0-9]'), '')}');

/// Call / email / WhatsApp buttons from the public config support block.
class SupportContactButtons extends StatelessWidget {
  const SupportContactButtons({super.key, required this.support, this.emailSubject});

  final SupportContact support;
  final String? emailSubject;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (support.phone != null)
          ListTile(
            key: const Key('supportCall'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.call_outlined, color: AppColors.primary),
            title: Text(l.profileSupportCall),
            subtitle: Text(support.phone!),
            onTap: () => openExternal(context, supportPhoneUri(support.phone!)),
          ),
        if (support.email != null)
          ListTile(
            key: const Key('supportEmail'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: Text(l.profileSupportEmail),
            subtitle: Text(support.email!),
            onTap: () => openExternal(context, supportMailUri(support.email!, subject: emailSubject)),
          ),
        if (support.whatsapp != null)
          ListTile(
            key: const Key('supportWhatsapp'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_outlined, color: AppColors.primary),
            title: Text(l.profileSupportWhatsapp),
            subtitle: Text(support.whatsapp!),
            onTap: () => openExternal(context, supportWhatsappUri(support.whatsapp!)),
          ),
      ],
    );
  }
}
