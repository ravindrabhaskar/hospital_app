import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/server/server_actions.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legal_links.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../core/widgets/branding.dart';
import 'appearance_screen.dart' show themeModeLabel;
import 'avatar_upload.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.logout),
        content: Text(l.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.logout)),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(sessionProvider).me;
    final patients = ref.watch(patientsProvider).value;
    final self = patients?.where((p) => p.isSelf).firstOrNull;
    final active = ref.watch(activePatientProvider).value;
    final lang = ref.watch(localeProvider).languageCode;
    final themeMode = ref.watch(themeModeProvider);
    final plan = ref.watch(mySubscriptionProvider).value;
    final flags = ref.watch(featureFlagsProvider);
    final name = me?.name ?? self?.name ?? '';

    final items = <(IconData, String, String?, String)>[
      (Icons.person_outline, l.personalInformation, null, '/profile/personal'),
      (Icons.health_and_safety_outlined, l.healthProfile, l.healthProfileSub, '/profile/health'),
      (Icons.people_outline, l.familyMembers, l.familyMembersSub, '/profile/family'),
      (Icons.watch_outlined, l.linkedDevices, l.linkedDevicesSub, '/wearables'),
      (Icons.language, l.language, '${Labels.language(l, lang)} (${l.change})', '/profile/language'),
      (Icons.dark_mode_outlined, l.appearance, themeModeLabel(l, themeMode), '/profile/appearance'),
      (Icons.notifications_none, l.notifications, null, '/profile/notifications'),
      (Icons.privacy_tip_outlined, l.privacyConsents, null, '/profile/consents'),
      (Icons.contact_phone_outlined, l.emergencyContacts, null, '/profile/emergency-contacts'),
      (Icons.receipt_long_outlined, l.payments, l.paymentsSub, '/profile/payments'),
      if (flags.walletOffers) (Icons.account_balance_wallet_outlined, l.wallet, l.walletSub, '/wallet'),
      if (flags.walletOffers) (Icons.card_giftcard, l.inviteFamilyFriends, l.inviteRewardSub, '/invite'),
      if (flags.insurance) (Icons.shield_outlined, l.insurance, l.insuranceSub, '/insurance'),
      if (flags.dailyCheckin) (Icons.wb_sunny_outlined, l.dailyCheckin, l.dailyCheckinSub, '/checkin'),
      if (flags.dementiaSafety) (Icons.share_location, l.safetyLocation, l.safetyLocationSub, '/safety'),
      (
        Icons.workspace_premium_outlined,
        l.familyCarePlan,
        plan != null && plan.isActive ? plan.planName : l.familyCarePlanSub,
        '/profile/family-plan'
      ),
      (Icons.support_agent, l.helpSupport, l.helpSupportSub, '/profile/help'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.myProfile),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: () => context.push('/profile/personal'), child: Text(l.edit)),
          // Breathing room from the screen edge (longer Hindi/Telugu labels).
          const SizedBox(width: Space.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Row(
            children: [
              EditableAvatar(name: name.isEmpty ? '?' : name, url: self?.avatarUrl, size: 76),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    if (self != null)
                      Text(
                        [
                          if (self.age != null) l.ageYears(self.age!),
                          if (self.gender.isNotEmpty) Labels.gender(l, self.gender),
                        ].join(' • '),
                        style: TextStyle(color: context.textMuted),
                      ),
                    Text(me?.email ?? me?.phone ?? '', style: TextStyle(color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (active != null && !active.isSelf) ...[
            const SizedBox(height: Space.md),
            CcCard(
              color: context.mintSurface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.family_restroom, color: context.brand),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.healthSettingsFor(active.name))),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          CcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(items[i].$1, color: context.textStrong),
                    title: Text(items[i].$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: items[i].$3 == null
                        ? null
                        : Text(items[i].$3!, style: const TextStyle(fontSize: 12.5)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(items[i].$4),
                  ),
                  if (i < items.length - 1) const Divider(indent: 56),
                ],
              ],
            ),
          ),
          if (ref.watch(switchAppProvider) case final switchApp?) ...[
            const SizedBox(height: Space.lg),
            // All-in-one demo build only: back to the role chooser.
            CcCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('switchApp'),
                minTileHeight: 56,
                leading: Icon(Icons.swap_horiz, color: context.textStrong),
                title: const Text('Switch app', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Back to the app chooser', style: TextStyle(fontSize: 12.5)),
                trailing: const Icon(Icons.chevron_right),
                onTap: switchApp,
              ),
            ),
          ],
          if (ref.watch(serverSettingsProvider) case final server when server.overrideAllowed) ...[
            const SizedBox(height: Space.lg),
            // Demo / QA builds only: point the app at another backend.
            CcCard(
              padding: EdgeInsets.zero,
              child: ListenableBuilder(
                listenable: server,
                builder: (context, _) => ListTile(
                  key: const Key('serverAddress'),
                  minTileHeight: 56,
                  leading: Icon(Icons.dns_outlined, color: context.textStrong),
                  title: Text(l.serverAddressTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(server.host, style: const TextStyle(fontSize: 12.5)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openServerAddressDialog(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout),
            label: Text(l.logout),
          ),
          const SizedBox(height: Space.md),
          const LegalLinks(),
          const PoweredByFooter(),
          Center(
            child: Text(l.appVersion(ref.watch(appVersionProvider)),
                style: TextStyle(fontSize: 12, color: context.textMuted)),
          ),
        ],
      ),
    );
  }
}
