import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legal_links.dart';
import '../../core/widgets/state_views.dart';
import '../../models/auth.dart';
import '../../state/core_providers.dart';

/// The word the user must type to confirm deletion.
const deleteConfirmWord = 'DELETE';

final deletionRequestProvider = FutureProvider.autoDispose<DeletionRequest?>(
    (ref) => ref.watch(accountRepositoryProvider).deletionRequest());

/// Profile → Privacy & Consents → Delete my account (§23).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _schedule() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final reason = _reason.text.trim();
      final r = await ref
          .read(accountRepositoryProvider)
          .requestDeletion(reason: reason.isEmpty ? null : reason);
      ref.invalidate(deletionRequestProvider);
      if (!mounted) return;
      final when = r.scheduledFor == null ? '' : fmtDate(context, r.scheduledFor!);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.schedule),
          title: Text(l.deletionScheduledTitle),
          content: Text(l.deletionScheduledLogoutBody(when)),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.ok))],
        ),
      );
      await ref.read(sessionProvider.notifier).logout();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider).cancelDeletion();
      ref.invalidate(deletionRequestProvider);
      if (mounted) showSnack(context, l.deletionCancelled);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccount)),
      body: AsyncView<DeletionRequest?>(
        value: ref.watch(deletionRequestProvider),
        onRetry: () => ref.invalidate(deletionRequestProvider),
        data: (r) => r != null && r.isScheduled ? _scheduled(context, r) : _form(context),
      ),
    );
  }

  Widget _scheduled(BuildContext context, DeletionRequest r) {
    final l = context.l10n;
    return ListView(
      key: const Key('deletion-scheduled'),
      padding: const EdgeInsets.all(Space.screen),
      children: [
        CcCard(
          color: context.roseSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.deletionScheduledTitle, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(r.scheduledFor == null
                  ? l.deletionScheduledNoDate
                  : l.deletionScheduledFor(fmtDate(context, r.scheduledFor!))),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(l.deletionCancelHint, style: TextStyle(color: context.textMuted)),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          key: const Key('cancel-deletion'),
          label: l.cancelDeletion,
          icon: Icons.undo,
          loading: _busy,
          onPressed: _cancel,
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final l = context.l10n;
    final confirmed = _confirm.text.trim() == deleteConfirmWord;
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(t)),
            ],
          ),
        );
    return ListView(
      key: const Key('deletion-form'),
      padding: const EdgeInsets.all(Space.screen),
      children: [
        Text(l.deleteAccountIntro),
        const SizedBox(height: Space.lg),
        SectionHeader(title: l.deletionWhatHappens),
        CcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet(l.deletionGracePeriod),
              bullet(l.deletionRemoved),
              bullet(l.deletionDependents),
            ],
          ),
        ),
        SectionHeader(title: l.deletionWhatRetained),
        CcCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bullet(l.deletionRetainedBody),
              bullet(l.deletionExportHint),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _reason,
          maxLines: 2,
          decoration: InputDecoration(labelText: l.deletionReasonOptional),
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: const Key('delete-confirm-field'),
          controller: _confirm,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.typeDeleteToConfirm(deleteConfirmWord)),
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          key: const Key('delete-account-button'),
          label: l.deleteMyAccount,
          icon: Icons.delete_forever_outlined,
          color: AppColors.danger,
          foreground: Colors.white,
          loading: _busy,
          onPressed: confirmed ? _schedule : null,
        ),
        const SizedBox(height: Space.lg),
        const LegalLinks(),
      ],
    );
  }
}
