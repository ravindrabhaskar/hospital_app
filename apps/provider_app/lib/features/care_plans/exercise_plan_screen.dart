import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/care_plans.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// `GET /exercise-library?bodyArea=` (§53); null = every body area.
final exerciseLibraryProvider = FutureProvider.autoDispose.family<List<Exercise>, String?>((ref, bodyArea) {
  return ref.watch(carePlanRepositoryProvider).exerciseLibrary(bodyArea: bodyArea);
});

/// `GET /exercise-plans?patientId=` plus each plan's progress.
final exerciseProgressProvider =
    FutureProvider.autoDispose.family<List<(ExercisePlan, ExerciseProgress?)>, String>((ref, patientId) async {
  final repo = ref.watch(carePlanRepositoryProvider);
  final plans = await repo.exercisePlans(patientId);
  final result = <(ExercisePlan, ExerciseProgress?)>[];
  for (final p in plans.take(5)) {
    ExerciseProgress? progress;
    try {
      progress = await repo.exerciseProgress(p.id);
    } catch (_) {}
    result.add((p, progress));
  }
  return result;
});

String exercisePlanErrorText(AppLocalizations l, ExercisePlanError e) => switch (e) {
      ExercisePlanError.noExercises => l.exErrNoExercises,
      ExercisePlanError.sets => l.exErrRange(l.exSets, 1, ExercisePlanLimits.maxSets),
      ExercisePlanError.reps => l.exErrRange(l.exReps, 1, ExercisePlanLimits.maxReps),
      ExercisePlanError.hold => l.exErrRange(l.exHold, 0, ExercisePlanLimits.maxHoldSecs),
      ExercisePlanError.perDay => l.exErrRange(l.exPerDay, 1, ExercisePlanLimits.maxPerDay),
      ExercisePlanError.weeks => l.exErrRange(l.exWeeks, 1, ExercisePlanLimits.maxWeeks),
      ExercisePlanError.startDate => l.exErrStartDate,
    };

/// Physiotherapist: build an exercise plan for the visit's patient (§53).
class ExercisePlanScreen extends ConsumerStatefulWidget {
  const ExercisePlanScreen({super.key, required this.patientId, this.patientName, this.careEpisodeId, this.now});
  final String patientId;
  final String? patientName;
  final String? careEpisodeId;
  final DateTime? now;

  @override
  ConsumerState<ExercisePlanScreen> createState() => _ExercisePlanScreenState();
}

class _ExercisePlanScreenState extends ConsumerState<ExercisePlanScreen> {
  late final DateTime _today = widget.now ?? DateTime.now();
  late final ExercisePlanDraft _draft = ExercisePlanDraft(
    patientId: widget.patientId,
    careEpisodeId: widget.careEpisodeId,
    startDate: DateTime(_today.year, _today.month, _today.day),
  );

  /// One key per form instance, so a retried save is de-duplicated.
  final String _idempotencyKey = const Uuid().v4();
  String? _bodyArea;
  Set<ExercisePlanError> _errors = {};
  bool _saving = false;

  void _toggle(Exercise e) => setState(() {
        if (_draft.contains(e.id)) {
          _draft.items.removeWhere((i) => i.exercise.id == e.id);
        } else {
          _draft.items.add(ExercisePlanItemDraft(e));
        }
        if (_errors.isNotEmpty) _errors = _draft.validate(_today);
      });

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.startDate,
      firstDate: DateTime(_today.year, _today.month, _today.day),
      lastDate: _today.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _draft.startDate = picked);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final errors = _draft.validate(_today);
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(carePlanRepositoryProvider).createExercisePlan(_draft, idempotencyKey: _idempotencyKey);
      ref.invalidate(exerciseProgressProvider(widget.patientId));
      messenger.showSnackBar(SnackBar(content: Text(l.exCreated)));
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(l, e)), backgroundColor: AppColors.dangerDeep));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(exerciseLibraryProvider(null));
    final filtered = ref.watch(exerciseLibraryProvider(_bodyArea));
    final areas = <String>{for (final e in all.value ?? const <Exercise>[]) e.bodyArea}.where((a) => a.isNotEmpty).toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: Text(l.exCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (widget.patientName != null) Text(l.planFor(widget.patientName!), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SectionCard(
            title: l.exChooseTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      key: const Key('exArea.all'),
                      label: Text(l.exAllAreas),
                      selected: _bodyArea == null,
                      onSelected: (_) => setState(() => _bodyArea = null),
                    ),
                    for (final a in areas)
                      ChoiceChip(
                        key: Key('exArea.$a'),
                        label: Text(a),
                        selected: _bodyArea == a,
                        onSelected: (_) => setState(() => _bodyArea = a),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                filtered.when(
                  loading: () => const SizedBox(height: 80, child: LoadingView()),
                  error: (e, _) => ErrorView(
                    message: errorMessage(l, e),
                    onRetry: () => ref.invalidate(exerciseLibraryProvider(_bodyArea)),
                  ),
                  data: (list) => list.isEmpty
                      ? Padding(padding: const EdgeInsets.all(12), child: Text(l.exLibraryEmpty))
                      : Column(
                          children: [
                            for (final e in list)
                              CheckboxListTile(
                                key: Key('exPick.${e.id}'),
                                value: _draft.contains(e.id),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(e.title),
                                subtitle: Text([e.bodyArea, e.level].where((s) => s.isNotEmpty).join(' · ')),
                                onChanged: (_) => _toggle(e),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.exDosageTitle,
            child: _draft.items.isEmpty
                ? Text(l.exNoneSelected, style: const TextStyle(color: AppColors.textSecondary))
                : Column(
                    children: [
                      for (final item in _draft.items)
                        _DosageEditor(
                          key: ValueKey('dose.${item.exercise.id}'),
                          item: item,
                          onChanged: () {
                            if (_errors.isNotEmpty) setState(() => _errors = _draft.validate(_today));
                          },
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.exScheduleTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  key: const Key('exStartDate'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(l.exStartDate),
                  subtitle: Text(formatDate(context, _draft.startDate)),
                  onTap: _pickStart,
                ),
                TextFormField(
                  key: const Key('exWeeks'),
                  initialValue: '${_draft.weeks}',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(labelText: l.exWeeks),
                  onChanged: (v) => _draft.weeks = int.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('exErrors'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _errors)
                    Text('• ${exercisePlanErrorText(l, e)}', style: const TextStyle(color: AppColors.dangerDeep)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('exSave'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(l.exSave),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DosageEditor extends StatelessWidget {
  const _DosageEditor({super.key, required this.item, required this.onChanged});
  final ExercisePlanItemDraft item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget numField(String key, String label, String initial, void Function(String) set) => Expanded(
          child: TextFormField(
            key: Key('$key.${item.exercise.id}'),
            initialValue: initial,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: InputDecoration(labelText: label, isDense: true),
            onChanged: (v) {
              set(v);
              onChanged();
            },
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.exercise.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            numField('exSets', l.exSets, '${item.sets}', (v) => item.sets = int.tryParse(v) ?? 0),
            const SizedBox(width: 8),
            numField('exReps', l.exReps, '${item.reps}', (v) => item.reps = int.tryParse(v) ?? 0),
            const SizedBox(width: 8),
            numField('exHold', l.exHold, item.holdSecs?.toString() ?? '', (v) => item.holdSecs = int.tryParse(v)),
            const SizedBox(width: 8),
            numField('exPerDay', l.exPerDay, '${item.perDay}', (v) => item.perDay = int.tryParse(v) ?? 0),
          ]),
          TextFormField(
            key: Key('exNotes.${item.exercise.id}'),
            decoration: InputDecoration(labelText: l.exNotes, isDense: true),
            maxLength: 300,
            onChanged: (v) => item.notes = v,
          ),
        ],
      ),
    );
  }
}

/// Visit card for a physiotherapist: create a plan and see the patient's
/// existing plans with adherence and pain trend (when the API allows it).
class ExercisePlanCard extends ConsumerWidget {
  const ExercisePlanCard({super.key, required this.patientId, required this.onCreate, this.canCreate = true});
  final String patientId;
  final VoidCallback onCreate;
  final bool canCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(exerciseProgressProvider(patientId));
    return SectionCard(
      key: const Key('exercisePlanCard'),
      title: l.exCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          async.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(minHeight: 2)),
            error: (e, _) => Text(l.exProgressUnavailable, style: const TextStyle(color: AppColors.textSecondary)),
            data: (plans) => plans.isEmpty
                ? Text(l.exNoPlans, style: const TextStyle(color: AppColors.textSecondary))
                : Column(
                    children: [
                      for (final (plan, progress) in plans)
                        ListTile(
                          key: Key('exPlan.${plan.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.accessibility_new),
                          title: Text(l.exPlanLine(plan.itemCount, plan.authorName)),
                          subtitle: Text(progress == null
                              ? '${plan.startDate ?? ''} – ${plan.endDate ?? ''}'
                              : [
                                  l.exProgressLine(progress.sessionsDone, progress.sessionsPlanned,
                                      progress.adherencePct.round()),
                                  if (progress.latestPain != null) l.exLatestPain(progress.latestPain!.round()),
                                ].join(' · ')),
                        ),
                    ],
                  ),
          ),
          if (canCreate) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('createExercisePlan'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l.exCreateTitle),
            ),
          ],
        ],
      ),
    );
  }
}
