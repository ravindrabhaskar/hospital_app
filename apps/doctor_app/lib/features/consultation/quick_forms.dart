import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/clinician_repository.dart';
import '../../models/care.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'care_plan_screen.dart' show splitList;

/// Shared save handling for the quick-create forms.
mixin _Saving<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool busy = false;
  final action = IdempotentAction();

  Future<void> save(Future<void> Function(String key) call, String successMessage) async {
    final l = context.l10n;
    setState(() => busy = true);
    try {
      await call(action.key);
      action.complete();
      if (!mounted) return;
      showSnack(context, successMessage);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget saveButton(VoidCallback? onPressed, String label, {Key? key}) =>
      FilledButton(key: key, onPressed: busy ? null : onPressed, child: busy ? const ButtonSpinner() : Text(label));
}

// ------------------------------------------------------------------ Referral

final _hospitalsProvider = FutureProvider.autoDispose.family<List<Facility>, String>(
  (ref, q) => ref.watch(clinicianRepositoryProvider).hospitals(q),
);

/// `POST /clinician/referrals` (contract §36).
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key, required this.careEpisodeId});
  final String careEpisodeId;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> with _Saving {
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _specialty = TextEditingController();
  final _reason = TextEditingController();
  final _summary = TextEditingController();
  String _q = '';
  Facility? _facility;
  String _urgency = 'routine';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hospitals = ref.watch(_hospitalsProvider(_q));
    return Form(
      key: _form,
      child: FormPage(
        title: l.referTitle,
        bottom: saveButton(
          _facility == null
              ? null
              : () {
                  if (!_form.currentState!.validate()) return;
                  save(
                    (key) => ref.read(clinicianRepositoryProvider).createReferral({
                      'careEpisodeId': widget.careEpisodeId,
                      'facilityId': _facility!.id,
                      if (_specialty.text.trim().isNotEmpty) 'specialty': _specialty.text.trim(),
                      'urgency': _urgency,
                      'reason': _reason.text.trim(),
                      if (_summary.text.trim().isNotEmpty) 'clinicalSummary': _summary.text.trim(),
                    }, idempotencyKey: key),
                    l.referSaved,
                  );
                },
          l.referSend,
          key: const Key('referSave'),
        ),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(labelText: l.referSearchHospital, prefixIcon: const Icon(Icons.search)),
            onSubmitted: (v) => setState(() => _q = v),
          ),
          gap8,
          SizedBox(
            height: 220,
            child: AsyncBody<List<Facility>>(
              value: hospitals,
              onRetry: () => ref.invalidate(_hospitalsProvider(_q)),
              data: (items) => items.isEmpty
                  ? EmptyView(message: l.referNoHospitals, icon: Icons.local_hospital_outlined)
                  : RadioGroup<String>(
                      groupValue: _facility?.id,
                      onChanged: (id) => setState(() => _facility = items.firstWhere((f) => f.id == id)),
                      child: ListView(
                        children: [
                          for (final f in items)
                            RadioListTile<String>(
                              value: f.id,
                              title: Text(f.name),
                              subtitle: Text(
                                [
                                  if (f.area != null) f.area!,
                                  if (f.city != null) f.city!,
                                  if (f.emergency24x7) l.emergency24x7,
                                ].join(' · '),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          gap12,
          TextFormField(
            controller: _specialty,
            decoration: InputDecoration(labelText: l.referSpecialty),
          ),
          gap12,
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'routine', label: Text(l.priorityRoutine)),
              ButtonSegment(value: 'urgent', label: Text(l.priorityUrgent)),
            ],
            selected: {_urgency},
            onSelectionChanged: (s) => setState(() => _urgency = s.first),
          ),
          gap12,
          TextFormField(
            key: const Key('referReason'),
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(labelText: l.referReason),
            validator: (v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null,
          ),
          gap12,
          TextFormField(
            controller: _summary,
            maxLines: 4,
            decoration: InputDecoration(labelText: l.referSummary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Programs

final _templatesProvider = FutureProvider.autoDispose<List<ProgramTemplate>>(
  (ref) => ref.watch(clinicianRepositoryProvider).programTemplates(),
);

/// `POST /care-programs/enrollments` (contract §42) with editable thresholds.
class EnrollProgramScreen extends ConsumerStatefulWidget {
  const EnrollProgramScreen({super.key, required this.patientId, this.careEpisodeId});
  final String patientId;
  final String? careEpisodeId;

  @override
  ConsumerState<EnrollProgramScreen> createState() => _EnrollProgramScreenState();
}

class _EnrollProgramScreenState extends ConsumerState<EnrollProgramScreen> with _Saving {
  ProgramTemplate? _template;
  List<ProgramThreshold> _thresholds = [];
  final Map<int, TextEditingController> _values = {};

  void _pick(ProgramTemplate t) {
    setState(() {
      _template = t;
      _thresholds = [...t.defaultThresholds];
      _values.clear();
      for (var i = 0; i < _thresholds.length; i++) {
        _values[i] = TextEditingController(text: formatNumber(_thresholds[i].value));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final templates = ref.watch(_templatesProvider);
    final now = ref.read(clockProvider)();
    return FormPage(
      title: l.enrolTitle,
      bottom: saveButton(
        _template == null
            ? null
            : () {
                final ts = [
                  for (var i = 0; i < _thresholds.length; i++)
                    _thresholds[i].copyWith(value: num.tryParse(_values[i]!.text.trim()) ?? _thresholds[i].value),
                ];
                save(
                  (key) => ref.read(clinicianRepositoryProvider).enroll({
                    'patientId': widget.patientId,
                    'templateCode': _template!.code,
                    'thresholds': ts.map((t) => t.toJson()).toList(),
                    'startDate': ClinicianRepository.isoDate(now),
                    'careEpisodeId': ?widget.careEpisodeId,
                  }, idempotencyKey: key),
                  l.enrolSaved,
                );
              },
        l.enrolSave,
        key: const Key('enrolSave'),
      ),
      children: [
        AsyncBody<List<ProgramTemplate>>(
          value: templates,
          onRetry: () => ref.invalidate(_templatesProvider),
          data: (items) => RadioGroup<String>(
            groupValue: _template?.code,
            onChanged: (code) => _pick(items.firstWhere((t) => t.code == code)),
            child: Column(
              children: [
                for (final t in items)
                  RadioListTile<String>(
                    value: t.code,
                    title: Text(t.name),
                    subtitle: Text(t.approved ? t.description : '${t.description}\n${l.fixtureWarning}'),
                  ),
              ],
            ),
          ),
        ),
        if (_template != null) ...[
          gap12,
          SectionCard(
            title: l.enrolThresholds,
            icon: Icons.tune,
            child: Column(
              children: [
                for (var i = 0; i < _thresholds.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text('${vitalLabel(l, _thresholds[i].type)} ${_thresholds[i].op == 'gt' ? '>' : '<'}'),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: Key('threshold.$i'),
                            controller: _values[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PriorityChip(priority: _thresholds[i].level),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Exercise

final _exerciseLibraryProvider = FutureProvider.autoDispose<List<Exercise>>(
  (ref) => ref.watch(clinicianRepositoryProvider).exerciseLibrary(),
);

class _ExerciseDraft {
  _ExerciseDraft(this.exercise);
  final Exercise exercise;
  int sets = 2;
  int reps = 10;
  int perDay = 1;
}

/// `POST /exercise-plans` (contract §53) quick create.
class ExercisePlanScreen extends ConsumerStatefulWidget {
  const ExercisePlanScreen({super.key, required this.patientId, this.careEpisodeId});
  final String patientId;
  final String? careEpisodeId;

  @override
  ConsumerState<ExercisePlanScreen> createState() => _ExercisePlanScreenState();
}

class _ExercisePlanScreenState extends ConsumerState<ExercisePlanScreen> with _Saving {
  final Map<String, _ExerciseDraft> _selected = {};
  int _weeks = 4;

  Widget _stepper(String label, int value, ValueChanged<int> onChanged, {int min = 1, int max = 50}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      IconButton(
        tooltip: '$label −',
        onPressed: value > min ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      Text('$value'),
      IconButton(
        tooltip: '$label +',
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lib = ref.watch(_exerciseLibraryProvider);
    final now = ref.read(clockProvider)();
    return FormPage(
      title: l.exerciseTitle,
      bottom: saveButton(
        _selected.isEmpty
            ? null
            : () => save(
                (key) => ref.read(clinicianRepositoryProvider).createExercisePlan({
                  'patientId': widget.patientId,
                  'careEpisodeId': ?widget.careEpisodeId,
                  'items': [
                    for (final d in _selected.values)
                      {'exerciseId': d.exercise.id, 'sets': d.sets, 'reps': d.reps, 'perDay': d.perDay},
                  ],
                  'startDate': ClinicianRepository.isoDate(now),
                  'weeks': _weeks,
                }, idempotencyKey: key),
                l.planSaved,
              ),
        l.commonSave,
        key: const Key('exerciseSave'),
      ),
      children: [
        _stepper(l.exerciseWeeks, _weeks, (v) => setState(() => _weeks = v), max: 26),
        gap8,
        AsyncBody<List<Exercise>>(
          value: lib,
          onRetry: () => ref.invalidate(_exerciseLibraryProvider),
          data: (items) => Column(
            children: [
              for (final e in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _selected.containsKey(e.id),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected[e.id] = _ExerciseDraft(e);
                          } else {
                            _selected.remove(e.id);
                          }
                        }),
                        title: Text(e.title),
                        subtitle: Text([e.bodyArea, e.level].where((s) => s.isNotEmpty).join(' · ')),
                      ),
                      if (_selected[e.id] != null)
                        Wrap(
                          children: [
                            _stepper(
                              l.exerciseSets,
                              _selected[e.id]!.sets,
                              (v) => setState(() => _selected[e.id]!.sets = v),
                              max: 10,
                            ),
                            _stepper(
                              l.exerciseReps,
                              _selected[e.id]!.reps,
                              (v) => setState(() => _selected[e.id]!.reps = v),
                              max: 50,
                            ),
                            _stepper(
                              l.exercisePerDay,
                              _selected[e.id]!.perDay,
                              (v) => setState(() => _selected[e.id]!.perDay = v),
                              max: 5,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- Diet

final _dietTemplatesProvider = FutureProvider.autoDispose<List<DietTemplate>>(
  (ref) => ref.watch(clinicianRepositoryProvider).dietTemplates(),
);

/// `POST /diet-plans` (contract §54) quick create.
class DietPlanScreen extends ConsumerStatefulWidget {
  const DietPlanScreen({super.key, required this.patientId});
  final String patientId;

  @override
  ConsumerState<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends ConsumerState<DietPlanScreen> with _Saving {
  String? _templateCode;
  final _conditions = TextEditingController();
  final _calories = TextEditingController();
  final _avoid = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, TextEditingController> _meals = {for (final s in dietSlots) s: TextEditingController()};
  int _validWeeks = 4;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final templates = ref.watch(_dietTemplatesProvider);
    final now = ref.read(clockProvider)();
    final meals = [
      for (final s in dietSlots)
        if (splitList(_meals[s]!.text).isNotEmpty) {'slot': s, 'items': splitList(_meals[s]!.text)},
    ];
    return FormPage(
      title: l.dietTitle,
      bottom: saveButton(
        () {
          final m = [
            for (final s in dietSlots)
              if (splitList(_meals[s]!.text).isNotEmpty) {'slot': s, 'items': splitList(_meals[s]!.text)},
          ];
          if (m.isEmpty && _templateCode == null) {
            showSnack(context, l.dietNeedMeals, error: true);
            return;
          }
          save(
            (key) => ref.read(clinicianRepositoryProvider).createDietPlan({
              'patientId': widget.patientId,
              'templateCode': ?_templateCode,
              'conditions': splitList(_conditions.text),
              if (int.tryParse(_calories.text) != null) 'calorieTarget': int.parse(_calories.text),
              'meals': m,
              'avoid': splitList(_avoid.text),
              if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
              'validUntil': ClinicianRepository.isoDate(now.add(Duration(days: 7 * _validWeeks))),
            }, idempotencyKey: key),
            l.planSaved,
          );
        },
        l.commonSave,
        key: const Key('dietSave'),
      ),
      children: [
        AsyncBody<List<DietTemplate>>(
          value: templates,
          onRetry: () => ref.invalidate(_dietTemplatesProvider),
          data: (items) => DropdownButtonFormField<String?>(
            initialValue: _templateCode,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.dietTemplate),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.dietNoTemplate)),
              for (final t in items) DropdownMenuItem<String?>(value: t.code, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() {
              _templateCode = v;
              final t = items.where((x) => x.code == v).firstOrNull;
              if (t != null && _conditions.text.trim().isEmpty) _conditions.text = t.conditions.join(', ');
            }),
          ),
        ),
        gap12,
        TextField(
          controller: _conditions,
          decoration: InputDecoration(labelText: l.dietConditions),
        ),
        gap12,
        TextField(
          controller: _calories,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(labelText: l.dietCalories),
        ),
        gap12,
        SectionCard(
          title: l.dietMeals,
          icon: Icons.restaurant_outlined,
          child: Column(
            children: [
              Text(l.dietMealsHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              gap8,
              for (final s in dietSlots)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _meals[s],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: dietSlotLabel(l, s)),
                  ),
                ),
              Text(l.dietMealsCount(meals.length), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        gap12,
        TextField(
          controller: _avoid,
          decoration: InputDecoration(labelText: l.dietAvoid),
        ),
        gap12,
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: InputDecoration(labelText: l.dietNotes),
        ),
        gap12,
        Row(
          children: [
            Expanded(child: Text(l.dietValidWeeks(_validWeeks))),
            IconButton(
              tooltip: '−',
              onPressed: _validWeeks > 1 ? () => setState(() => _validWeeks--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: '+',
              onPressed: _validWeeks < 26 ? () => setState(() => _validWeeks++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}
