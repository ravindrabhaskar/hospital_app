import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale_controller.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/public_config.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'profile_photo.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final pending = ref.read(offlineQueueProvider).pendingCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.profileLogoutConfirm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending > 0) ...[
              Text(l.profileLogoutPending(pending),
                  style: const TextStyle(color: AppColors.dangerDeep, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
            ],
            Text(l.profileLogoutBody),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
          TextButton(
            key: const Key('logoutConfirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonLogout),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider).logout();
  }

  /// Staff cannot self-delete (contract §23); closure goes through support.
  Future<void> _requestClosure(BuildContext context, SupportContact? support) async {
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.profileCloseAccount),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.profileCloseAccountBody, key: const Key('closeAccountBody')),
              const SizedBox(height: 12),
              if (support == null || support.isEmpty)
                Text(l.profileSupportUnavailable, style: const TextStyle(fontWeight: FontWeight.w600))
              else
                SupportContactButtons(support: support, emailSubject: l.profileCloseAccountSubject),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonBack)),
        ],
      ),
    );
  }

  Future<void> _changeLanguage(WidgetRef ref, String code) async {
    await ref.read(localeControllerProvider).setLocale(code);
    ref.read(apiClientProvider).languageCode = code;
    try {
      await ref.read(authRepositoryProvider).updateLanguage(code);
    } catch (_) {
      // Server preference is best effort (offline etc.).
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final localeCtrl = ref.watch(localeControllerProvider);
    final configCtrl = ref.watch(publicConfigProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([auth, localeCtrl, configCtrl]),
        builder: (context, _) {
          final p = auth.profile;
          final me = auth.me;
          if (p == null) {
            return ErrorView(message: l.errorGeneric, onRetry: auth.refreshProfile);
          }
          final now = DateTime.now();
          final days = p.daysUntilCredentialExpiry(now);
          final config = configCtrl.config;
          final support = config?.support;
          final privacy = Uri.tryParse(config?.legal.privacyUrl ?? '');
          final terms = Uri.tryParse(config?.legal.termsUrl ?? '');
          final currentLang = localeCtrl.locale?.languageCode ?? Localizations.localeOf(context).languageCode;
          return RefreshIndicator(
            onRefresh: auth.refreshProfile,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                SectionCard(
                  color: AppColors.mint50,
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: l.avatarChange,
                        child: InkWell(
                          key: const Key('changePhoto'),
                          customBorder: const CircleBorder(),
                          onTap: () => changeProfilePhoto(context, ref),
                          child: Stack(
                            children: [
                              ProviderAvatar(name: p.name, photoUrl: auth.photoUrl, radius: 32),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.photo_camera, size: 16, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: Theme.of(context).textTheme.titleLarge),
                            Text('${providerTypeLabel(l, p.type)} · ${p.qualification}',
                                style: const TextStyle(color: AppColors.textSecondary)),
                            if (p.rating != null)
                              Text(
                                l.profileRating(p.rating!.toStringAsFixed(1), p.ratingCount ?? 0),
                                key: const Key('profileRating'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (p.credentialExpiringSoon(now) && days != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('credentialWarning'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5A10)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(l.profileCredentialExpiring(days))),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    key: const Key('earningsEntry'),
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                    title: Text(l.earnTitle),
                    subtitle: Text(l.earnEntrySubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/earnings'),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(
                    children: [
                      if (me != null) LabeledValue(icon: Icons.phone_outlined, label: l.profilePhone, value: me.phone),
                      LabeledValue(icon: Icons.badge_outlined, label: l.profileType, value: providerTypeLabel(l, p.type)),
                      LabeledValue(icon: Icons.school_outlined, label: l.profileQualification, value: p.qualification),
                      LabeledValue(
                        icon: Icons.verified_outlined,
                        label: l.profileVerification,
                        value: verificationLabel(l, p.verificationStatus),
                      ),
                      LabeledValue(
                        icon: Icons.event_outlined,
                        label: l.profileCredentialExpiry,
                        value: formatDate(context, p.credentialExpiresAt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: l.profileZones,
                  child: p.zones.isEmpty
                      ? Text(l.commonNotAvailable)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final z in p.zones) Chip(label: Text(z.name))],
                        ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: l.profileCapabilities,
                  child: p.capabilities.isEmpty
                      ? Text(l.commonNotAvailable)
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final c in p.capabilities) Chip(label: Text(c.replaceAll('_', ' ')))],
                        ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: l.profileLanguage,
                  child: RadioGroup<String>(
                    groupValue: currentLang,
                    onChanged: (v) {
                      if (v != null) _changeLanguage(ref, v);
                    },
                    child: Column(
                      children: [
                        for (final code in LocaleController.supported)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: code,
                            title: Text(LocaleController.nativeName(code)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  key: const Key('supportCard'),
                  title: l.profileSupport,
                  child: support == null || support.isEmpty
                      ? Text(l.profileSupportUnavailable)
                      : SupportContactButtons(support: support),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: l.profileAccount,
                  child: Column(
                    children: [
                      if (privacy != null && privacy.hasScheme)
                        ListTile(
                          key: const Key('privacyLink'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: Text(l.profilePrivacy),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => openExternal(context, privacy),
                        ),
                      if (terms != null && terms.hasScheme)
                        ListTile(
                          key: const Key('termsLink'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(l.profileTerms),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => openExternal(context, terms),
                        ),
                      ListTile(
                        key: const Key('closeAccount'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.no_accounts_outlined, color: AppColors.dangerDeep),
                        title: Text(l.profileCloseAccount),
                        onTap: () => _requestClosure(context, support),
                      ),
                    ],
                  ),
                ),
                if (ref.watch(switchAppProvider) case final switchApp?) ...[
                  const SizedBox(height: 12),
                  // All-in-one demo build only: back to the role chooser.
                  Card(
                    child: ListTile(
                      key: const Key('switchApp'),
                      leading: const Icon(Icons.swap_horiz),
                      title: const Text('Switch app'),
                      subtitle: const Text('Back to the app chooser'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: switchApp,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  key: const Key('logoutButton'),
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout),
                  label: Text(l.commonLogout),
                ),
                if (configCtrl.appVersion != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l.profileAppVersion(configCtrl.appVersion!),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
