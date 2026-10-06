import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/care.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import '../common/file_viewer.dart';

final secondOpinionsProvider = FutureProvider.autoDispose.family<List<SecondOpinion>, String>(
  (ref, scope) => ref.watch(clinicianRepositoryProvider).secondOpinions(scope),
);

/// Specialist second opinions (contract §49): open requests in the doctor's
/// specialty (claim) and the doctor's own (respond).
class SecondOpinionsScreen extends ConsumerWidget {
  const SecondOpinionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.secondOpinionsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.soTabOpen),
              Tab(text: l.soTabMine),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _List(scope: 'open'),
            _List(scope: 'mine'),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.scope});
  final String scope;

  Future<void> _claim(BuildContext context, WidgetRef ref, SecondOpinion so) async {
    final l = context.l10n;
    try {
      await ref.read(clinicianRepositoryProvider).claimSecondOpinion(so.id);
      ref.invalidate(secondOpinionsProvider);
      if (context.mounted) showSnack(context, l.soClaimedMsg);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(l, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(clinicianRepositoryProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(secondOpinionsProvider(scope).future),
      child: AsyncBody<List<SecondOpinion>>(
        value: ref.watch(secondOpinionsProvider(scope)),
        onRetry: () => ref.invalidate(secondOpinionsProvider(scope)),
        data: (items) => items.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 320,
                    child: EmptyView(message: l.soEmpty, icon: Icons.rate_review_outlined),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screen),
                itemCount: items.length,
                separatorBuilder: (_, _) => gap12,
                itemBuilder: (context, i) {
                  final so = items[i];
                  return SectionCard(
                    key: Key('so.${so.id}'),
                    title: '${so.patientName} · ${specialtyLabel(l, so.specialty)}',
                    trailing: TonePill(
                      label: secondOpinionStatusLabel(l, so.status),
                      bg: AppColors.lavenderBg,
                      fg: AppColors.lavender,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(so.question),
                        if (so.dueAt != null) ...[
                          gap8,
                          Text(
                            l.soDue(formatDateTime(context, so.dueAt)),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                        if (so.records.isNotEmpty) ...[
                          gap8,
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final r in so.records)
                                ActionChip(
                                  avatar: const Icon(Icons.description_outlined, size: 18),
                                  label: Text(r.title),
                                  onPressed: so.isOpen
                                      ? null
                                      : () => openFile(context, title: r.title, load: () => repo.recordFile(r.id)),
                                ),
                            ],
                          ),
                        ],
                        if (so.opinion != null) ...[gap8, LabeledValue(label: l.soOpinion, value: so.opinion!)],
                        if (so.recommendations.isNotEmpty)
                          LabeledValue(label: l.soRecommendations, value: so.recommendations.join('\n')),
                        gap8,
                        if (so.isOpen)
                          FilledButton(
                            key: Key('soClaim.${so.id}'),
                            onPressed: () => _claim(context, ref, so),
                            child: Text(l.soClaim),
                          ),
                        if (so.isClaimed)
                          FilledButton(
                            key: Key('soRespond.${so.id}'),
                            onPressed: () async {
                              final ok = await Navigator.of(
                                context,
                                rootNavigator: true,
                              ).push<bool>(MaterialPageRoute(builder: (_) => RespondScreen(opinion: so)));
                              if (ok == true) ref.invalidate(secondOpinionsProvider);
                            },
                            child: Text(l.soRespond),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class RespondScreen extends ConsumerStatefulWidget {
  const RespondScreen({super.key, required this.opinion});
  final SecondOpinion opinion;

  @override
  ConsumerState<RespondScreen> createState() => _RespondScreenState();
}

class _RespondScreenState extends ConsumerState<RespondScreen> {
  final _opinion = TextEditingController();
  final _recs = TextEditingController();
  bool _tele = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _opinion.addListener(() => setState(() {}));
  }

  Future<void> _send() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(clinicianRepositoryProvider)
          .respondSecondOpinion(
            widget.opinion.id,
            opinion: _opinion.text.trim(),
            recommendations: _recs.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
            suggestTeleconsult: _tele,
          );
      if (!mounted) return;
      showSnack(context, l.soSent);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FormPage(
      title: l.soRespond,
      bottom: FilledButton(
        onPressed: _busy || _opinion.text.trim().length < 10 ? null : _send,
        child: _busy ? const ButtonSpinner() : Text(l.send),
      ),
      children: [
        Text(widget.opinion.question, style: Theme.of(context).textTheme.titleMedium),
        gap12,
        TextField(
          controller: _opinion,
          minLines: 5,
          maxLines: 12,
          decoration: InputDecoration(labelText: l.soOpinion),
        ),
        gap12,
        TextField(
          controller: _recs,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: l.soRecommendations, helperText: l.onePerLine),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _tele,
          onChanged: (v) => setState(() => _tele = v),
          title: Text(l.soSuggestTele),
        ),
      ],
    );
  }
}
