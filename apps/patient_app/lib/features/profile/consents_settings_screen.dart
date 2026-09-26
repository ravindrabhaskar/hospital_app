import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/utils/save_file/save_file.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legal_links.dart';
import '../../core/widgets/state_views.dart';
import '../../models/auth.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

class ConsentsSettingsScreen extends ConsumerStatefulWidget {
  const ConsentsSettingsScreen({super.key});

  @override
  ConsumerState<ConsentsSettingsScreen> createState() => _State();
}

class _State extends ConsumerState<ConsentsSettingsScreen> {
  String? _busy;
  bool _exporting = false;

  /// "Download my data" (§23): generate the export, then hand the JSON file
  /// to the user (browser download on web, share sheet on mobile).
  Future<void> _export() async {
    final l = context.l10n;
    setState(() => _exporting = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final export = await repo.createExport();
      final bytes = await repo.exportFile(export.id);
      final now = DateTime.now();
      final name =
          'carecompanion-data-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      await saveOrShareFile(bytes: bytes, fileName: name, mimeType: 'application/json', subject: l.myDataExport);
      if (mounted) showSnack(context, l.dataExportReady);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _toggle(ConsentCatalogItem item, Consent? current, bool grant) async {
    final l = context.l10n;
    if (!grant && current != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l.revokeConsentTitle),
          content: Text(item.required ? l.revokeRequiredConsentBody : l.revokeConsentBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.revoke)),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = item.purpose);
    try {
      final repo = ref.read(consentRepositoryProvider);
      if (grant) {
        await repo.grant(item.purpose, item.version);
      } else if (current != null) {
        await repo.revoke(current.id);
      }
      ref.invalidate(consentsProvider);
      await ref.read(sessionProvider.notifier).refreshMe();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = ref.watch(consentCatalogProvider);
    final consents = ref.watch(consentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyConsents)),
      body: AsyncView<List<ConsentCatalogItem>>(
        value: catalog,
        onRetry: () {
          ref.invalidate(consentCatalogProvider);
          ref.invalidate(consentsProvider);
        },
        data: (items) => AsyncView<List<Consent>>(
          value: consents,
          onRetry: () => ref.invalidate(consentsProvider),
          data: (list) {
            Consent? currentFor(String purpose) =>
                list.where((c) => c.purpose == purpose && c.isGranted).firstOrNull;
            return ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                Text(l.privacyIntro, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.lg),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: CcCard(
                      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(item.title.isEmpty ? Labels.consentPurpose(l, item.purpose) : item.title,
                                        style: Theme.of(context).textTheme.titleSmall),
                                    if (item.required)
                                      StatusPill(label: l.required, color: AppColors.danger),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.description, style: const TextStyle(fontSize: 12.5)),
                                if (currentFor(item.purpose)?.grantedAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l.grantedOn(fmtDate(context, currentFor(item.purpose)!.grantedAt!)),
                                      style: TextStyle(fontSize: 11.5, color: context.textMuted),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _busy == item.purpose
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : Switch(
                                  value: currentFor(item.purpose) != null,
                                  onChanged: _busy != null
                                      ? null
                                      : (v) => _toggle(item, currentFor(item.purpose), v),
                                ),
                        ],
                      ),
                    ),
                  ),
                SectionHeader(title: l.yourData),
                ListRowTile(
                  key: const Key('download-my-data'),
                  icon: Icons.download_outlined,
                  accent: Accent.sky,
                  title: l.downloadMyData,
                  subtitle: l.downloadMyDataSub,
                  trailing: _exporting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _exporting ? null : _export,
                ),
                ListRowTile(
                  key: const Key('delete-my-account'),
                  icon: Icons.delete_outline,
                  accent: Accent.rose,
                  title: l.deleteMyAccount,
                  subtitle: l.deleteMyAccountSub,
                  onTap: () => context.push('/profile/delete-account'),
                ),
                const SizedBox(height: Space.md),
                const LegalLinks(),
              ],
            );
          },
        ),
      ),
    );
  }
}
