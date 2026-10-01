import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legal_links.dart';
import '../../core/widgets/state_views.dart';
import '../../state/core_providers.dart';

/// Profile → Help & Support. Contact details come from `PublicConfig.support`.
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(publicConfigProvider).support;
    final hasAny = s.hasPhone || s.hasEmail || s.hasWhatsapp;
    return Scaffold(
      appBar: AppBar(title: Text(l.helpSupport)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          CcCard(
            color: context.roseSurface,
            child: Row(
              children: [
                const Icon(Icons.emergency_outlined, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(l.supportEmergencyNote)),
                TextButton(
                  onPressed: () => openExternal(context, telUri(AppConfig.emergencyHelpline)),
                  child: Text(l.callNumber(AppConfig.emergencyHelpline)),
                ),
              ],
            ),
          ),
          if (ref.watch(featureFlagsProvider).supportDesk) ...[
            const SizedBox(height: Space.lg),
            ListRowTile(
              key: const Key('support-tickets'),
              icon: Icons.confirmation_number_outlined,
              accent: Accent.sky,
              title: l.myTickets,
              subtitle: l.myTicketsSub,
              onTap: () => context.push('/support/tickets'),
            ),
          ],
          const SizedBox(height: Space.lg),
          Text(l.helpSupportIntro, style: TextStyle(color: context.textMuted)),
          const SizedBox(height: Space.md),
          if (!hasAny)
            EmptyStateView(icon: Icons.support_agent, title: l.supportUnavailable, compact: true)
          else
            CcCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (s.hasPhone)
                    ListTile(
                      key: const Key('support-call'),
                      leading: Icon(Icons.call_outlined, color: context.brand),
                      title: Text(l.supportCall),
                      subtitle: Text(s.phone),
                      onTap: () => openExternal(context, telUri(s.phone)),
                    ),
                  if (s.hasWhatsapp)
                    ListTile(
                      key: const Key('support-whatsapp'),
                      leading: Icon(Icons.chat_outlined, color: context.brand),
                      title: Text(l.supportWhatsapp),
                      subtitle: Text(s.whatsapp!),
                      onTap: () => openExternal(context, whatsappUri(s.whatsapp!)),
                    ),
                  if (s.hasEmail)
                    ListTile(
                      key: const Key('support-email'),
                      leading: Icon(Icons.mail_outline, color: context.brand),
                      title: Text(l.supportEmail),
                      subtitle: Text(s.email),
                      onTap: () => openExternal(context, mailUri(s.email, subject: l.supportEmailSubject)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Space.xl),
          const LegalLinks(),
        ],
      ),
    );
  }
}
