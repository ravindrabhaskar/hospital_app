import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/trend_chart.dart';
import '../../models/monitoring.dart';
import '../../state/v13_providers.dart';

// Physiotherapy & exercise programs (API_CONTRACT §53).

class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.exercisePlan)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(exercisePlansProvider.future),
        child: AsyncView<List<ExercisePlan>>(
          value: ref.watch(exercisePlansProvider),
          onRetry: () => ref.invalidate(exercisePlansProvider),
          isEmpty: (p) => !p.any((x) => x.isActive),
          empty: ListView(padding: const EdgeInsets.all(Space.screen), children: [
            EmptyStateView(icon: Icons.fitness_center, title: l.noExercisePlan, message: l.noExercisePlanBody),
            const _BookPhysioCard(),
          ]),
          data: (plans) {
            final plan = plans.firstWhere((p) => p.isActive);
            return _PlanView(plan: plan);
          },
        ),
      ),
    );
  }
}

class _BookPhysioCard extends StatelessWidget {
  const _BookPhysioCard();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListRowTile(
      icon: Icons.accessibility_new,
      accent: Accent.peach,
      title: l.bookPhysioVisit,
      subtitle: l.bookPhysioVisitSub,
      onTap: () => context.push('/home-checkup/book?service=physiotherapy'),
    );
  }
}

class _PlanView extends ConsumerStatefulWidget {
  const _PlanView({required this.plan});
  final ExercisePlan plan;

  @override
  ConsumerState<_PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<_PlanView> {
  final _done = <String>{};
  bool _saving = false;

  Future<void> _finish() async {
    final l = context.l10n;
    final result = await showModalBottomSheet<(int, String)>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => const PainScoreSheet(),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(exerciseRepositoryProvider).logSession(widget.plan.id,
          completedExerciseIds: _done.toList(), painScore: result.$1, note: result.$2);
      ref.invalidate(exerciseProgressProvider(widget.plan.id));
      if (!mounted) return;
      setState(_done.clear);
      showSnack(context, result.$1 >= 8 ? l.sessionSavedHighPain : l.sessionSaved);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.plan;
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: [
        Text(l.planBy(p.authorName), style: TextStyle(color: context.textMuted)),
        Text(l.planDates(fmtYmd(context, p.startDate), fmtYmd(context, p.endDate)),
            style: TextStyle(color: context.textMuted, fontSize: 12.5)),
        _ProgressCard(planId: p.id),
        SectionHeader(title: l.todaysExercises),
        for (final item in p.items)
          ExerciseItemCard(
            item: item,
            done: _done.contains(item.exerciseId),
            onDone: (v) => setState(() => v ? _done.add(item.exerciseId) : _done.remove(item.exerciseId)),
          ),
        const SizedBox(height: Space.md),
        PrimaryButton(
          key: const Key('exercise-finish'),
          label: l.finishSession(_done.length, p.items.length),
          loading: _saving,
          onPressed: _done.isEmpty ? null : _finish,
        ),
        const SizedBox(height: Space.md),
        const _BookPhysioCard(),
        Text(l.exerciseSafetyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
      ],
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.planId});
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(exerciseProgressProvider(planId));
    final pr = v.value;
    if (pr == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: CcCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.sessionsDone(pr.sessionsDone, pr.sessionsPlanned))),
            Text('${pr.adherencePct.round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (pr.adherencePct / 100).clamp(0, 1).toDouble(),
            minHeight: 6,
            semanticsLabel: l.adherence,
            semanticsValue: '${pr.adherencePct.round()}%',
          ),
          if (pr.painTrend.length > 1) ...[
            const SizedBox(height: Space.md),
            Text(l.painTrend, style: const TextStyle(fontWeight: FontWeight.w600)),
            TrendChart(
              height: 110,
              color: AppColors.peachFg,
              points: [for (final (d, s) in pr.painTrend) ChartPoint(d, s.toDouble())],
              semanticLabel: l.painTrendSemantic(pr.painTrend.last.$2),
            ),
          ],
        ]),
      ),
    );
  }
}

class ExerciseItemCard extends StatelessWidget {
  const ExerciseItemCard({super.key, required this.item, required this.done, required this.onDone});
  final ExercisePlanItem item;
  final bool done;
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = item.exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('exercise-${item.exerciseId}'),
        borderColor: done ? AppColors.primaryLight : null,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          leading: Checkbox(
            value: done,
            onChanged: (v) => onDone(v ?? false),
            semanticLabel: l.markExerciseDone(e?.title ?? item.exerciseId),
          ),
          title: Text(e?.title ?? item.exerciseId, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([
            l.setsReps(item.sets, item.reps),
            if (item.holdSecs != null) l.holdSeconds(item.holdSecs!),
            l.timesPerDay(item.perDay),
          ].join(' · ')),
          childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.holdSecs != null && item.holdSecs! > 0) HoldTimer(seconds: item.holdSecs!),
            if (e != null && e.instructions.isNotEmpty) ...[
              Text(l.instructions, style: const TextStyle(fontWeight: FontWeight.w700)),
              for (var i = 0; i < e.instructions.length; i++)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('${i + 1}. ${e.instructions[i]}')),
            ],
            if (e != null && e.precautions.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(l.precautions, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.peachFg)),
              for (final p in e.precautions) Text('• $p'),
            ],
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              Text(item.notes!, style: TextStyle(color: context.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A countdown for "hold for N seconds".
class HoldTimer extends StatefulWidget {
  const HoldTimer({super.key, required this.seconds});
  final int seconds;

  @override
  State<HoldTimer> createState() => _HoldTimerState();
}

class _HoldTimerState extends State<HoldTimer> {
  Timer? _t;
  late int _left = widget.seconds;

  void _start() {
    _t?.cancel();
    setState(() => _left = widget.seconds);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final running = _t?.isActive ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(children: [
        Semantics(
          liveRegion: true,
          child: Text(running ? l.secondsLeft(_left) : l.holdSeconds(widget.seconds),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _start,
          icon: Icon(running ? Icons.restart_alt : Icons.timer_outlined),
          label: Text(running ? l.restart : l.startTimer),
        ),
      ]),
    );
  }
}

/// Pain score 0–10 after a session (+ optional note).
class PainScoreSheet extends StatefulWidget {
  const PainScoreSheet({super.key});

  @override
  State<PainScoreSheet> createState() => _PainScoreSheetState();
}

class _PainScoreSheetState extends State<PainScoreSheet> {
  double _score = 2;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.howIsYourPain, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.sm),
            Text(l.painScoreValue(_score.round()), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Slider(
              key: const Key('pain-slider'),
              value: _score,
              min: 0,
              max: 10,
              divisions: 10,
              label: '${_score.round()}',
              semanticFormatterCallback: (v) => l.painScoreValue(v.round()),
              onChanged: (v) => setState(() => _score = v),
            ),
            Row(children: [
              Text(l.noPain, style: TextStyle(fontSize: 12, color: context.textMuted)),
              const Spacer(),
              Text(l.worstPain, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ]),
            if (_score >= 8)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(l.highPainNote, style: const TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: Space.md),
            TextField(controller: _note, decoration: InputDecoration(labelText: l.noteOptional)),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              key: const Key('pain-save'),
              label: l.save,
              onPressed: () => Navigator.pop(context, (_score.round(), _note.text)),
            ),
          ],
        ),
      ),
    );
  }
}
