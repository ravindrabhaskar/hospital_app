import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/clinical.dart';
import '../../models/json.dart';
import '../../models/prescription.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import '../common/file_viewer.dart';

/// e-Prescription writer (contract §31) with the live interaction/allergy
/// check (§47). Major warnings block sending until acknowledged with a reason.
class PrescriptionWriter extends ConsumerStatefulWidget {
  const PrescriptionWriter({super.key, required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<PrescriptionWriter> createState() => _PrescriptionWriterState();
}

class _PrescriptionWriterState extends ConsumerState<PrescriptionWriter> {
  final List<RxItem> _items = [];
  List<RxWarning> _warnings = const [];
  String? _packLabel;
  bool _checking = false;
  Object? _checkError;
  bool _ack = false;
  final _reason = TextEditingController();
  final _note = TextEditingController();
  final _advice = TextEditingController();
  final _followUp = TextEditingController();
  bool _sending = false;
  Timer? _debounce;
  int _checkSeq = 0;
  final _action = IdempotentAction();

  RxGate get _gate =>
      RxGate(items: _items, warnings: _warnings, acknowledged: _ack, overrideReason: _reason.text, checking: _checking);

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reason.dispose();
    _note.dispose();
    _advice.dispose();
    _followUp.dispose();
    super.dispose();
  }

  void _scheduleCheck() {
    _debounce?.cancel();
    if (_items.isEmpty) {
      setState(() {
        _warnings = const [];
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    _debounce = Timer(AppConfig.rxCheckDebounce, _runCheck);
  }

  Future<void> _runCheck() async {
    final seq = ++_checkSeq;
    try {
      final res = await ref.read(clinicianRepositoryProvider).checkPrescription(widget.appointment.patientId, _items);
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _warnings = res.warnings;
        _packLabel = res.packVersion == null ? null : '${res.packVersion} (${res.packStatus ?? '-'})';
        _checkError = null;
        _checking = false;
        if (!_gate.hasMajor) _ack = false;
      });
    } catch (e) {
      if (!mounted || seq != _checkSeq) return;
      setState(() {
        _checkError = e;
        _checking = false;
      });
    }
  }

  Future<void> _editItem([int? index]) async {
    final item = await showModalBottomSheet<RxItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RxItemEditor(initial: index == null ? null : _items[index]),
    );
    if (item == null) return;
    setState(() {
      if (index == null) {
        _items.add(item);
      } else {
        _items[index] = item;
      }
    });
    _scheduleCheck();
  }

  Future<void> _submit() async {
    if (!_gate.canSubmit) return;
    final l = context.l10n;
    setState(() => _sending = true);
    final body = <String, dynamic>{
      'appointmentId': widget.appointment.id,
      if (_note.text.trim().isNotEmpty) 'clinicalNote': _note.text.trim(),
      'items': _items.map((i) => i.toJson()).toList(),
      if (_advice.text.trim().isNotEmpty) 'advice': _advice.text.trim(),
      if (int.tryParse(_followUp.text.trim()) != null) 'followUpInDays': int.parse(_followUp.text.trim()),
      ..._gate.overrideFields,
    };
    try {
      final rx = await ref.read(clinicianRepositoryProvider).createPrescription(body, idempotencyKey: _action.key);
      _action.complete();
      if (!mounted) return;
      showSnack(context, l.rxCreated);
      final repo = ref.read(clinicianRepositoryProvider);
      await openFile(context, title: l.rxPdfTitle(rx.patientName), load: () => repo.prescriptionPdf(rx.id));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _action.complete();
      if (!mounted) return;
      final serverWarnings = jsonList(e.details['warnings']).map(RxWarning.fromJson).toList();
      if (e.isValidation && serverWarnings.isNotEmpty) {
        // The server found major warnings: show them and require the override.
        setState(() {
          _warnings = serverWarnings;
          _ack = false;
        });
        showSnack(context, l.rxMajorBlocked, error: true);
      } else {
        showSnack(context, errorMessage(l, e), error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final gate = _gate;
    return FormPage(
      title: l.rxTitle,
      bottom: FilledButton(
        key: const Key('rxSubmit'),
        onPressed: gate.canSubmit && !_sending ? _submit : null,
        child: _sending ? const ButtonSpinner() : Text(l.rxSign),
      ),
      children: [
        Text(l.rxFor(widget.appointment.patientName), style: Theme.of(context).textTheme.titleMedium),
        gap12,
        SectionCard(
          title: l.rxItems,
          icon: Icons.medication_outlined,
          trailing: TextButton.icon(
            key: const Key('rxAddItem'),
            onPressed: _items.length >= 20 ? null : () => _editItem(),
            icon: const Icon(Icons.add),
            label: Text(l.commonAdd),
          ),
          child: _items.isEmpty
              ? Text(l.rxNoItems, style: const TextStyle(color: AppColors.textSecondary))
              : Column(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      ListTile(
                        key: Key('rxItem.$i'),
                        contentPadding: EdgeInsets.zero,
                        title: Text('${_items[i].drugName} ${_items[i].strength ?? ''}'.trim()),
                        subtitle: Text(
                          [
                            rxFormLabel(l, _items[i].form),
                            _items[i].dose,
                            _items[i].frequency,
                            l.daysCount(_items[i].durationDays),
                            if (_items[i].times.isNotEmpty) _items[i].times.join(', '),
                          ].join(' · '),
                        ),
                        onTap: () => _editItem(i),
                        trailing: IconButton(
                          tooltip: l.commonRemove,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => _items.removeAt(i));
                            _scheduleCheck();
                          },
                        ),
                      ),
                  ],
                ),
        ),
        gap12,
        RxWarningsPanel(
          warnings: _warnings,
          checking: _checking,
          error: _checkError,
          packLabel: _packLabel,
          onRetry: _scheduleCheck,
          hasItems: _items.isNotEmpty,
        ),
        if (gate.hasMajor) ...[
          gap12,
          Material(
            key: const Key('rxOverride'),
            color: AppColors.dangerBg,
            borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    key: const Key('rxAck'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ack,
                    onChanged: (v) => setState(() => _ack = v ?? false),
                    title: Text(
                      l.rxAcknowledge,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.dangerDeep),
                    ),
                  ),
                  TextField(
                    key: const Key('rxReason'),
                    controller: _reason,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: l.rxOverrideReason,
                      helperText: l.rxOverrideReasonHint(RxGate.minReasonLength),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        gap12,
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: InputDecoration(labelText: l.rxClinicalNote),
        ),
        gap12,
        TextField(
          controller: _advice,
          maxLines: 3,
          decoration: InputDecoration(labelText: l.rxAdvice),
        ),
        gap12,
        TextField(
          controller: _followUp,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
          decoration: InputDecoration(labelText: l.rxFollowUpDays),
        ),
      ],
    );
  }
}

/// Severity-badged list of interaction/allergy warnings.
class RxWarningsPanel extends StatelessWidget {
  const RxWarningsPanel({
    super.key,
    required this.warnings,
    required this.checking,
    required this.hasItems,
    this.error,
    this.packLabel,
    this.onRetry,
  });

  final List<RxWarning> warnings;
  final bool checking;
  final bool hasItems;
  final Object? error;
  final String? packLabel;
  final VoidCallback? onRetry;

  static (Color, Color) colors(String severity) => switch (severity) {
    'major' => (AppColors.dangerBg, AppColors.dangerDeep),
    'moderate' => (AppColors.warningBg, warningFg),
    _ => (AppColors.skyBg, AppColors.sky),
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget content;
    if (!hasItems) {
      content = Text(l.rxCheckIdle, style: const TextStyle(color: AppColors.textSecondary));
    } else if (checking) {
      content = Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(l.rxChecking),
        ],
      );
    } else if (error != null) {
      content = Row(
        children: [
          Expanded(
            child: Text(errorMessage(l, error!), style: const TextStyle(color: AppColors.dangerDeep)),
          ),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      );
    } else if (warnings.isEmpty) {
      content = Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Expanded(child: Text(l.rxNoWarnings, key: const Key('rxNoWarnings'))),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WarningTile(warning: w),
            ),
        ],
      );
    }
    return SectionCard(
      title: l.rxChecksTitle,
      icon: Icons.health_and_safety_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          if (packLabel != null) ...[
            gap8,
            Text(l.rxPack(packLabel!), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.warning});
  final RxWarning warning;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg) = RxWarningsPanel.colors(warning.severity);
    return Container(
      key: Key('rxWarning.${warning.severity}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: fg.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TonePill(label: severityLabel(l, warning.severity), bg: bg, fg: fg, semanticsPrefix: l.severityLabel),
              TonePill(label: warningTypeLabel(l, warning.type), bg: AppColors.mint50, fg: AppColors.textPrimary),
            ],
          ),
          const SizedBox(height: 6),
          Text(warning.message),
          if (warning.drugs.isNotEmpty)
            Text(warning.drugs.join(' + '), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (warning.source != null)
            Text(warning.source!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Bottom-sheet form for one RxItem.
class RxItemEditor extends StatefulWidget {
  const RxItemEditor({super.key, this.initial});
  final RxItem? initial;

  @override
  State<RxItemEditor> createState() => _RxItemEditorState();
}

class _RxItemEditorState extends State<RxItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _drug = TextEditingController(text: widget.initial?.drugName);
  late final _strength = TextEditingController(text: widget.initial?.strength);
  late final _dose = TextEditingController(text: widget.initial?.dose ?? '1');
  late final _freq = TextEditingController(text: widget.initial?.frequency);
  late final _timing = TextEditingController(text: widget.initial?.timing);
  late final _days = TextEditingController(text: '${widget.initial?.durationDays ?? 5}');
  late final _times = TextEditingController(text: widget.initial?.times.join(', '));
  late final _instr = TextEditingController(text: widget.initial?.instructions);
  late String _formValue = widget.initial?.form ?? 'tablet';

  static final _hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  @override
  void dispose() {
    for (final c in [_drug, _strength, _dose, _freq, _timing, _days, _times, _instr]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _timesList =>
      _times.text.split(RegExp(r'[,\s]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      RxItem(
        drugName: _drug.text.trim(),
        strength: _strength.text.trim().isEmpty ? null : _strength.text.trim(),
        form: _formValue,
        dose: _dose.text.trim(),
        frequency: _freq.text.trim(),
        timing: _timing.text.trim().isEmpty ? null : _timing.text.trim(),
        durationDays: int.parse(_days.text.trim()),
        times: _timesList,
        instructions: _instr.text.trim().isEmpty ? null : _instr.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String? req(String? v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            Text(l.rxItemTitle, style: Theme.of(context).textTheme.titleLarge),
            gap12,
            TextFormField(
              key: const Key('rxDrug'),
              controller: _drug,
              decoration: InputDecoration(labelText: l.rxDrugName),
              validator: req,
            ),
            gap8,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('rxStrength'),
                    controller: _strength,
                    decoration: InputDecoration(labelText: l.rxStrength),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _formValue,
                    decoration: InputDecoration(labelText: l.rxForm),
                    items: [for (final f in rxForms) DropdownMenuItem(value: f, child: Text(rxFormLabel(l, f)))],
                    onChanged: (v) => setState(() => _formValue = v ?? 'tablet'),
                  ),
                ),
              ],
            ),
            gap8,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('rxDose'),
                    controller: _dose,
                    decoration: InputDecoration(labelText: l.rxDose),
                    validator: req,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: const Key('rxFrequency'),
                    controller: _freq,
                    decoration: InputDecoration(labelText: l.rxFrequency, hintText: '1-0-1'),
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
                    key: const Key('rxDays'),
                    controller: _days,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    decoration: InputDecoration(labelText: l.rxDuration),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 1 || n > 365 ? l.rxDurationInvalid : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _timing,
                    decoration: InputDecoration(labelText: l.rxTiming, hintText: l.rxTimingHint),
                  ),
                ),
              ],
            ),
            gap8,
            TextFormField(
              key: const Key('rxTimes'),
              controller: _times,
              decoration: InputDecoration(labelText: l.rxTimes, hintText: '08:00, 20:00'),
              validator: (_) => _timesList.every(_hhmm.hasMatch) ? null : l.rxTimesInvalid,
            ),
            gap8,
            TextFormField(
              controller: _instr,
              decoration: InputDecoration(labelText: l.rxInstructions),
            ),
            gap16,
            FilledButton(key: const Key('rxItemSave'), onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      ),
    );
  }
}
