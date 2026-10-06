import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/json.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../onboarding/profile_setup_screen.dart' show DateField;
import 'care_screen.dart' show MedicationsBody;
import 'dose_display.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.medicineReminders)),
      body: const MedicationsBody(),
    );
  }
}

class AddMedicationScreen extends ConsumerStatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _instructions = TextEditingController();
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _frequency.dispose();
    _instructions.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
    if (t != null && !_times.contains(t)) {
      setState(() => _times
        ..add(t)
        ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute)));
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_times.isEmpty) {
      showSnack(context, l.addAtLeastOneTime, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final addedAt = DateTime.now();
      final med = await ref.read(carePlanRepositoryProvider).addMedication(
            patientId: patient.id,
            name: _name.text.trim(),
            dose: _dose.text.trim(),
            frequency: _frequency.text.trim().isEmpty ? l.timesPerDay(_times.length) : _frequency.text.trim(),
            times: _times.map(_hhmm).toList(),
            startDate: ymd(_start),
            endDate: _end == null ? null : ymd(_end!),
            instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
          );
      await ref.read(medicationAddedLogProvider.notifier).record(med.id, addedAt);
      ref.invalidate(medicationsProvider);
      ref.invalidate(remindersTodayProvider);
      if (mounted) {
        showSnack(context, l.medicationAdded);
        // Opened directly (deep link / reload): there is no page to go back to.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/medications');
        }
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.addMedication)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.medicineName),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _dose,
              decoration: InputDecoration(labelText: l.dose, hintText: l.doseHint),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.fieldRequired : null,
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _frequency,
              decoration: InputDecoration(labelText: l.frequency, hintText: l.frequencyHint),
            ),
            const SizedBox(height: Space.lg),
            Text(l.reminderTimes, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final t in _times)
                  InputChip(
                    label: Text(t.format(context)),
                    onDeleted: () => setState(() => _times.remove(t)),
                    deleteButtonTooltipMessage: l.remove,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l.addTime),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            DateField(
              label: l.startDate,
              value: _start,
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _start,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _start = d);
              },
            ),
            const SizedBox(height: Space.lg),
            DateField(
              label: l.endDateOptional,
              value: _end,
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _end ?? _start.add(const Duration(days: 7)),
                    firstDate: _start,
                    lastDate: _start.add(const Duration(days: 730)));
                if (d != null) setState(() => _end = d);
              },
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _instructions,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.instructionsOptional, hintText: l.instructionsHint),
            ),
            const SizedBox(height: Space.md),
            Text(l.medicationSelfEnteredNote,
                style: TextStyle(fontSize: 12, color: context.textMuted)),
            const SizedBox(height: Space.xxl),
            PrimaryButton(label: l.save, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
