import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/clinician_repository.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

const _taskTypes = ['medication', 'test', 'follow_up', 'lifestyle', 'monitoring', 'general'];
const _owners = ['patient', 'caregiver', 'provider'];
const _followModes = ['video', 'in_clinic', 'home_visit'];

class _TaskDraft {
  String type = 'general';
  String owner = 'patient';
  final title = TextEditingController();
  final dueDays = TextEditingController();
}

class _MedDraft {
  final name = TextEditingController();
  final dose = TextEditingController();
  final frequency = TextEditingController();
  final times = TextEditingController(text: '08:00');
  final days = TextEditingController(text: '30');
}

/// `POST /care-plans` (contract §11): tasks, medications and follow-up.
class CarePlanScreen extends ConsumerStatefulWidget {
  const CarePlanScreen({super.key, required this.careEpisodeId});
  final String careEpisodeId;

  @override
  ConsumerState<CarePlanScreen> createState() => _CarePlanScreenState();
}

class _CarePlanScreenState extends ConsumerState<CarePlanScreen> {
  final _form = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _instructions = TextEditingController();
  final _tasks = <_TaskDraft>[];
  final _meds = <_MedDraft>[];
  bool _followUp = true;
  final _followDays = TextEditingController(text: '7');
  String _followMode = 'video';
  bool _busy = false;
  final _action = IdempotentAction();

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  List<String> _times(String s) => s.split(RegExp(r'[,\s]+')).where((t) => t.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final body = <String, dynamic>{
      'careEpisodeId': widget.careEpisodeId,
      'summary': _summary.text.trim(),
      'instructions': _instructions.text.trim(),
      'tasks': [
        for (final t in _tasks)
          {
            'type': t.type,
            'title': t.title.text.trim(),
            'owner': t.owner,
            if (int.tryParse(t.dueDays.text) != null)
              'dueAt': today.add(Duration(days: int.parse(t.dueDays.text), hours: 9)).toUtc().toIso8601String(),
          },
      ],
      'medications': [
        for (final m in _meds)
          {
            'name': m.name.text.trim(),
            'dose': m.dose.text.trim(),
            'frequency': m.frequency.text.trim(),
            'times': _times(m.times.text),
            'startDate': ClinicianRepository.isoDate(today),
            if (int.tryParse(m.days.text) != null)
              'endDate': ClinicianRepository.isoDate(today.add(Duration(days: int.parse(m.days.text) - 1))),
          },
      ],
      'followUp': _followUp ? {'afterDays': int.tryParse(_followDays.text) ?? 7, 'mode': _followMode} : null,
    };
    setState(() => _busy = true);
    try {
      await ref.read(clinicianRepositoryProvider).createCarePlan(body, idempotencyKey: _action.key);
      _action.complete();
      if (!mounted) return;
      showSnack(context, l.carePlanSaved);
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
    String? req(String? v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null;
    return Form(
      key: _form,
      child: FormPage(
        title: l.carePlanTitle,
        bottom: FilledButton(
          key: const Key('carePlanSave'),
          onPressed: _busy ? null : _save,
          child: _busy ? const ButtonSpinner() : Text(l.commonSave),
        ),
        children: [
          TextFormField(
            key: const Key('cpSummary'),
            controller: _summary,
            maxLines: 2,
            decoration: InputDecoration(labelText: l.carePlanSummary),
            validator: req,
          ),
          gap12,
          TextFormField(
            controller: _instructions,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.carePlanInstructions),
            validator: req,
          ),
          gap16,
          SectionCard(
            title: l.carePlanTasks,
            icon: Icons.checklist,
            trailing: TextButton.icon(
              onPressed: () => setState(() => _tasks.add(_TaskDraft())),
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
            child: Column(
              children: [
                if (_tasks.isEmpty) Text(l.noneAdded, style: const TextStyle(color: AppColors.textSecondary)),
                for (final t in _tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: t.title,
                                decoration: InputDecoration(labelText: l.taskTitle),
                                validator: req,
                              ),
                            ),
                            IconButton(
                              tooltip: l.commonRemove,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _tasks.remove(t)),
                            ),
                          ],
                        ),
                        gap8,
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: t.type,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: l.taskType),
                                items: [
                                  for (final x in _taskTypes)
                                    DropdownMenuItem(value: x, child: Text(taskTypeLabel(l, x))),
                                ],
                                onChanged: (v) => setState(() => t.type = v ?? 'general'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: t.owner,
                                isExpanded: true,
                                decoration: InputDecoration(labelText: l.taskOwner),
                                items: [
                                  for (final x in _owners) DropdownMenuItem(value: x, child: Text(ownerLabel(l, x))),
                                ],
                                onChanged: (v) => setState(() => t.owner = v ?? 'patient'),
                              ),
                            ),
                          ],
                        ),
                        gap8,
                        TextFormField(
                          controller: t.dueDays,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: l.taskDueInDays),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          gap12,
          SectionCard(
            title: l.carePlanMeds,
            icon: Icons.medication_outlined,
            trailing: TextButton.icon(
              onPressed: () => setState(() => _meds.add(_MedDraft())),
              icon: const Icon(Icons.add),
              label: Text(l.commonAdd),
            ),
            child: Column(
              children: [
                if (_meds.isEmpty) Text(l.noneAdded, style: const TextStyle(color: AppColors.textSecondary)),
                for (final m in _meds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: m.name,
                                decoration: InputDecoration(labelText: l.rxDrugName),
                                validator: req,
                              ),
                            ),
                            IconButton(
                              tooltip: l.commonRemove,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _meds.remove(m)),
                            ),
                          ],
                        ),
                        gap8,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: m.dose,
                                decoration: InputDecoration(labelText: l.rxDose),
                                validator: req,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: m.frequency,
                                decoration: InputDecoration(labelText: l.rxFrequency),
                                validator: req,
                              ),
                            ),
                          ],
                        ),
                        gap8,
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: m.times,
                                decoration: InputDecoration(labelText: l.rxTimes),
                                validator: (v) => _times(v ?? '').every(_hhmm.hasMatch) ? null : l.rxTimesInvalid,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: m.days,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(labelText: l.rxDuration),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          gap12,
          SectionCard(
            title: l.followUpTitle,
            icon: Icons.event_repeat,
            trailing: Switch(value: _followUp, onChanged: (v) => setState(() => _followUp = v)),
            child: _followUp
                ? Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _followDays,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: l.followUpAfterDays),
                          validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? l.fieldRequired : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _followMode,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l.followUpMode),
                          items: [
                            for (final x in _followModes) DropdownMenuItem(value: x, child: Text(modeLabel(l, x))),
                          ],
                          onChanged: (v) => setState(() => _followMode = v ?? 'video'),
                        ),
                      ),
                    ],
                  )
                : Text(l.followUpNone, style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// Helper used by quick forms: non-empty trimmed lines/commas -> list.
List<String> splitList(String s) => s.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
