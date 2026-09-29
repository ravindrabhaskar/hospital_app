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

final dietTemplatesProvider = FutureProvider.autoDispose<List<DietTemplate>>((ref) {
  return ref.watch(carePlanRepositoryProvider).dietTemplates();
});

String mealSlotLabel(AppLocalizations l, String slot) => switch (slot) {
      'early_morning' => l.slotEarlyMorning,
      'breakfast' => l.slotBreakfast,
      'mid_morning' => l.slotMidMorning,
      'lunch' => l.slotLunch,
      'evening' => l.slotEvening,
      'dinner' => l.slotDinner,
      'bedtime' => l.slotBedtime,
      _ => slot,
    };

String dietPlanErrorText(AppLocalizations l, DietPlanError e) => switch (e) {
      DietPlanError.noMeals => l.dietErrNoMeals,
      DietPlanError.noConditions => l.dietErrNoConditions,
      DietPlanError.calories =>
        l.dietErrCalories(DietPlanLimits.minCalories, DietPlanLimits.maxCalories),
      DietPlanError.validUntil => l.dietErrValidUntil,
    };

/// Dietitian: create a diet plan for the visit's patient (§54).
class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key, required this.patientId, this.patientName, this.now});
  final String patientId;
  final String? patientName;
  final DateTime? now;

  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> {
  late final DateTime _today = widget.now ?? DateTime.now();
  late final DietPlanDraft _draft = DietPlanDraft(
    patientId: widget.patientId,
    validUntil: DateTime(_today.year, _today.month, _today.day).add(const Duration(days: 30)),
  );
  final String _idempotencyKey = const Uuid().v4();
  final _condition = TextEditingController();
  Set<DietPlanError> _errors = {};
  bool _saving = false;

  @override
  void dispose() {
    _condition.dispose();
    super.dispose();
  }

  void _revalidate() {
    if (_errors.isNotEmpty) setState(() => _errors = _draft.validate(_today));
  }

  void _addConditions(List<String> values) => setState(() {
        for (final v in values) {
          if (!_draft.conditions.any((c) => c.toLowerCase() == v.toLowerCase())) _draft.conditions.add(v);
        }
        if (_errors.isNotEmpty) _errors = _draft.validate(_today);
      });

  void _pickTemplate(DietTemplate? t) {
    setState(() => _draft.templateCode = t?.code);
    if (t != null) _addConditions(t.conditions);
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.validUntil,
      firstDate: _today.add(const Duration(days: 1)),
      lastDate: _today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _draft.validUntil = picked);
      _revalidate();
    }
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
      await ref.read(carePlanRepositoryProvider).createDietPlan(_draft, idempotencyKey: _idempotencyKey);
      messenger.showSnackBar(SnackBar(content: Text(l.dietCreated)));
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
    final templates = ref.watch(dietTemplatesProvider);
    DietTemplate? selected;
    for (final t in templates.value ?? const <DietTemplate>[]) {
      if (t.code == _draft.templateCode) selected = t;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.dietCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (widget.patientName != null) Text(l.planFor(widget.patientName!), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SectionCard(
            title: l.dietTemplate,
            child: templates.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text(errorMessage(l, e), style: const TextStyle(color: AppColors.textSecondary)),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    key: const Key('dietTemplate'),
                    initialValue: _draft.templateCode,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.dietTemplate),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l.dietNoTemplate)),
                      for (final t in list) DropdownMenuItem<String?>(value: t.code, child: Text(t.name)),
                    ],
                    onChanged: (code) => _pickTemplate(list.where((t) => t.code == code).firstOrNull),
                  ),
                  if (selected != null && selected.unapproved) ...[
                    const SizedBox(height: 8),
                    Text(l.dietGovernance,
                        key: const Key('dietGovernance'),
                        style: const TextStyle(color: Color(0xFF9A5A10), fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.dietConditions,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in _draft.conditions)
                      InputChip(
                        key: Key('dietCond.$c'),
                        label: Text(c),
                        onDeleted: () {
                          setState(() => _draft.conditions.remove(c));
                          _revalidate();
                        },
                      ),
                  ],
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const Key('dietConditionField'),
                      controller: _condition,
                      decoration: InputDecoration(labelText: l.dietAddCondition, isDense: true),
                      onSubmitted: (v) {
                        _addConditions(splitList(v));
                        _condition.clear();
                      },
                    ),
                  ),
                  IconButton(
                    key: const Key('dietConditionAdd'),
                    tooltip: l.dietAddCondition,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      _addConditions(splitList(_condition.text));
                      _condition.clear();
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('dietCalories'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: InputDecoration(labelText: l.dietCalories, helperText: l.optionalHint),
                  onChanged: (v) {
                    _draft.calorieTarget = int.tryParse(v);
                    _revalidate();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.dietMeals,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.dietMealsHint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                for (final slot in mealSlots)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      key: Key('dietMeal.$slot'),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: mealSlotLabel(l, slot), isDense: true),
                      onChanged: (v) {
                        _draft.meals[slot] = splitList(v);
                        _revalidate();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l.dietAvoid,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('dietAvoid'),
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: l.dietAvoidHint, isDense: true),
                  onChanged: (v) => _draft.avoid
                    ..clear()
                    ..addAll(splitList(v)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('dietNotes'),
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(labelText: l.dietNotes),
                  onChanged: (v) => _draft.notes = v,
                ),
                ListTile(
                  key: const Key('dietValidUntil'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(l.dietValidUntil),
                  subtitle: Text(formatDate(context, _draft.validUntil)),
                  onTap: _pickValidUntil,
                ),
              ],
            ),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('dietErrors'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _errors)
                    Text('• ${dietPlanErrorText(l, e)}', style: const TextStyle(color: AppColors.dangerDeep)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('dietSave'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(l.dietSave),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Visit card for a dietitian.
class DietPlanCard extends StatelessWidget {
  const DietPlanCard({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      key: const Key('dietPlanCard'),
      title: l.dietCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.dietCardBody, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('createDietPlan'),
            onPressed: onCreate,
            icon: const Icon(Icons.restaurant_menu),
            label: Text(l.dietCreateTitle),
          ),
        ],
      ),
    );
  }
}
