import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/server/server_actions.dart';
import '../../core/theme.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final cfg = ref.watch(publicConfigProvider).config;
    final p = auth.profile;
    final me = auth.me;
    Widget item(String key, IconData icon, String title, String route, {String? subtitle}) => ListTile(
      key: Key('more.$key'),
      minVerticalPadding: 12,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
    return Scaffold(
      appBar: AppBar(title: Semantics(header: true, child: Text(l.navMore))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Card(
            child: ListTile(
              minVerticalPadding: 16,
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.mint100,
                foregroundImage: p?.photoUrl == null ? null : NetworkImage(p!.photoUrl!),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              title: Text(auth.displayName.isEmpty ? (me?.phone ?? '') : auth.displayName),
              subtitle: Text([p?.specialtyName ?? '', me?.phone ?? ''].where((s) => s.isNotEmpty).join(' · ')),
              onTap: () => context.push('/more/profile'),
            ),
          ),
          gap12,
          Card(
            child: Column(
              children: [
                item('secondOpinions', Icons.rate_review_outlined, l.secondOpinionsTitle, '/more/second-opinions'),
                item('escalations', Icons.warning_amber_outlined, l.escalationsTitle, '/more/escalations'),
                item('schedule', Icons.calendar_month_outlined, l.scheduleTitle, '/more/schedule'),
                item('earnings', Icons.account_balance_wallet_outlined, l.earningsTitle, '/more/earnings'),
                item('profile', Icons.badge_outlined, l.profileTitle, '/more/profile'),
                item(
                  'language',
                  Icons.translate,
                  l.languageTitle,
                  '/more/language',
                  subtitle: LocaleController.nativeName(locale.locale?.languageCode ?? 'en'),
                ),
              ],
            ),
          ),
          gap12,
          Card(
            child: ListTile(
              minVerticalPadding: 12,
              leading: Icon(
                me?.mfaEnrolled == true ? Icons.verified_user_outlined : Icons.shield_outlined,
                color: AppColors.primary,
              ),
              title: Text(l.mfaTitle),
              subtitle: Text(me?.mfaEnrolled == true ? l.mfaStatusOn : l.mfaStatusOff),
            ),
          ),
          if (cfg != null && !cfg.support.isEmpty) ...[
            gap12,
            SectionCard(
              title: l.supportTitle,
              child: SupportContactButtons(support: cfg.support),
            ),
          ],
          if (ref.watch(serverSettingsProvider) case final server when server.overrideAllowed) ...[
            gap12,
            // Demo / QA builds only: point the app at another backend.
            Card(
              child: ListenableBuilder(
                listenable: server,
                builder: (context, _) => ListTile(
                  key: const Key('more.serverAddress'),
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: Text(l.serverAddressTitle),
                  subtitle: Text(server.host),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openServerAddressDialog(context),
                ),
              ),
            ),
          ],
          if (ref.watch(switchAppProvider) case final switchApp?) ...[
            gap12,
            // All-in-one demo build only: back to the role chooser.
            Card(
              child: ListTile(
                key: const Key('more.switchApp'),
                minVerticalPadding: 12,
                leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
                title: const Text('Switch app'),
                subtitle: const Text('Back to the app chooser'),
                trailing: const Icon(Icons.chevron_right),
                onTap: switchApp,
              ),
            ),
          ],
          gap16,
          OutlinedButton.icon(
            key: const Key('logout'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l.logoutConfirmTitle),
                  // Only mention the authenticator when two-step verification is on.
                  content: Text(me?.mfaEnrolled == true ? l.logoutConfirmBody : l.logoutConfirmBodyOtp),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l.commonLogout),
                    ),
                  ],
                ),
              );
              if (ok == true) await auth.logout();
            },
            icon: const Icon(Icons.logout),
            label: Text(l.commonLogout),
          ),
        ],
      ),
    );
  }
}
