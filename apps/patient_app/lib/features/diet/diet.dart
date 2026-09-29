import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../models/json.dart';
import '../../models/monitoring.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

// Diet plans (API_CONTRACT §54).

String dietSlotLabel(AppLocalizations l, String s) => switch (s) {
      'early_morning' => l.slotEarlyMorning,
      'breakfast' => l.slotBreakfast,
      'mid_morning' => l.slotMidMorning,
      'lunch' => l.slotLunch,
      'evening' => l.slotEvening,
      'dinner' => l.slotDinner,
      'bedtime' => l.slotBedtime,
      _ => humanize(s),
    };

class DietScreen extends ConsumerWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.dietPlan)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dietPlansProvider.future),
        child: AsyncView<List<DietPlan>>(
          value: ref.watch(dietPlansProvider),
          onRetry: () => ref.invalidate(dietPlansProvider),
          isEmpty: (p) => !p.any((x) => x.isActive),
          empty: ListView(children: [
            EmptyStateView(icon: Icons.restaurant_menu, title: l.noDietPlan, message: l.noDietPlanBody),
          ]),
          data: (plans) => DietPlanView(plan: plans.firstWhere((p) => p.isActive)),
        ),
      ),
    );
  }
}

class DietPlanView extends ConsumerStatefulWidget {
  const DietPlanView({super.key, required this.plan});
  final DietPlan plan;

  @override
  ConsumerState<DietPlanView> createState() => _DietPlanViewState();
}

class _DietPlanViewState extends ConsumerState<DietPlanView> {
  /// Today's logs (slot → followed), remembered on this device because the
  /// contract has no endpoint to read back one day's logs.
  Map<String, bool> _today = {};

  String get _key => 'cc_diet_${widget.plan.id}_${ymd(DateTime.now())}';

  @override
  void initState() {
    super.initState();
    try {
      final raw = ref.read(sharedPrefsProvider).getString(_key);
      if (raw != null) _today = Map<String, bool>.from(jsonDecode(raw) as Map);
    } catch (_) {}
  }

  Future<void> _log(String slot, bool followed) async {
    final prev = Map<String, bool>.from(_today);
    setState(() => _today = {..._today, slot: followed});
    try {
      await ref.read(dietRepositoryProvider).log(widget.plan.id, date: DateTime.now(), slot: slot, followed: followed);
      try {
        await ref.read(sharedPrefsProvider).setString(_key, jsonEncode(_today));
      } catch (_) {}
      ref.invalidate(dietAdherenceProvider(widget.plan.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _today = prev);
      showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.plan;
    final adherence = ref.watch(dietAdherenceProvider(p.id)).value;
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: [
        CcCard(
          color: context.mintSurface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.planBy(p.authorName), style: const TextStyle(fontWeight: FontWeight.w600)),
            if (p.conditions.isNotEmpty) Text(p.conditions.join(', '), style: TextStyle(color: context.textMuted)),
            if (p.calorieTarget != null) Text(l.calorieTarget(p.calorieTarget!)),
            Text(l.validUntil(fmtYmd(context, p.validUntil)), style: TextStyle(fontSize: 12, color: context.textMuted)),
          ]),
        ),
        if (adherence != null) ...[
          SectionHeader(title: l.adherence14d),
          CcCard(
            key: const Key('diet-adherence'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${adherence.adherencePct.round()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: Space.sm),
              Semantics(
                label: l.dietAdherenceSemantic(adherence.adherencePct.round()),
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 44,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final d in adherence.days)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FractionallySizedBox(
                              heightFactor: d.slotsLogged == 0 ? 0.08 : (d.slotsFollowed / d.slotsLogged).clamp(0.08, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: d.slotsLogged == 0 ? context.borderColor : AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ],
        SectionHeader(title: l.todaysMeals),
        for (final m in p.orderedMeals)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: CcCard(
              key: Key('meal-${m.slot}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dietSlotLabel(l, m.slot), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final i in m.items) Text('• $i'),
                if (m.notes != null && m.notes!.isNotEmpty)
                  Text(m.notes!, style: TextStyle(fontSize: 12, color: context.textMuted)),
                const SizedBox(height: Space.sm),
                Wrap(spacing: Space.sm, children: [
                  ChoiceChip(
                    key: Key('meal-${m.slot}-yes'),
                    label: Text(l.followed),
                    avatar: const Icon(Icons.check, size: 18),
                    selected: _today[m.slot] == true,
                    onSelected: (_) => _log(m.slot, true),
                  ),
                  ChoiceChip(
                    key: Key('meal-${m.slot}-no'),
                    label: Text(l.notFollowed),
                    avatar: const Icon(Icons.close, size: 18),
                    selected: _today[m.slot] == false,
                    onSelected: (_) => _log(m.slot, false),
                  ),
                ]),
              ]),
            ),
          ),
        if (p.avoid.isNotEmpty) ...[
          SectionHeader(title: l.foodsToAvoid),
          CcCard(
            color: context.roseSurface,
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in p.avoid) StatusPill(label: a, color: AppColors.danger, icon: Icons.block),
            ]),
          ),
        ],
        if (p.notes != null && p.notes!.isNotEmpty) ...[
          SectionHeader(title: l.instructions),
          CcCard(child: Text(p.notes!)),
        ],
        const SizedBox(height: Space.md),
        Text(l.dietDisclaimer, style: TextStyle(fontSize: 12, color: context.textMuted)),
      ],
    );
  }
}
