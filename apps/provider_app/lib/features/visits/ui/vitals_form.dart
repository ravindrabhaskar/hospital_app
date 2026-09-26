import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/l10n_helpers.dart';
import '../domain/vitals_validation.dart';

String vitalLabel(AppLocalizations l, String type) => switch (type) {
      'bp_systolic' => l.vitalsBpSystolic,
      'bp_diastolic' => l.vitalsBpDiastolic,
      'pulse' => l.vitalsPulse,
      'spo2' => l.vitalsSpo2,
      'temperature' => l.vitalsTemperature,
      'blood_glucose' => l.vitalsBloodGlucose,
      'weight' => l.vitalsWeight,
      'respiratory_rate' => l.vitalsRespiratoryRate,
      _ => type,
    };

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String vitalErrorText(AppLocalizations l, VitalError e) => switch (e.kind) {
      VitalErrorKind.notANumber => l.vitalsErrorNumber,
      VitalErrorKind.outOfRange => l.vitalsErrorRange(_fmt(e.spec!.min), _fmt(e.spec!.max)),
      VitalErrorKind.bpPairRequired => l.vitalsErrorBpPair,
      VitalErrorKind.bpOrder => l.vitalsErrorBpOrder,
      VitalErrorKind.empty => l.vitalsErrorEmpty,
    };

/// Structured vitals capture. Records values only; no interpretation.
class VitalsForm extends StatefulWidget {
  const VitalsForm({super.key, required this.onSubmit, this.busy = false, this.clock = DateTime.now});

  /// Receives the `POST /home-visits/:id/vitals` body. Returns true on success
  /// (synced or queued) so the form can clear itself.
  final Future<bool> Function(Map<String, dynamic> body) onSubmit;
  final bool busy;
  final DateTime Function() clock;

  @override
  State<VitalsForm> createState() => _VitalsFormState();
}

class _VitalsFormState extends State<VitalsForm> {
  final Map<String, TextEditingController> _controllers = {
    for (final s in VitalSpecs.all) s.type: TextEditingController(),
  };
  Map<String, VitalError> _errors = {};
  VitalError? _formError;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final result = VitalsValidator.validate({for (final e in _controllers.entries) e.key: e.value.text});
    setState(() {
      _errors = result.fieldErrors;
      _formError = result.formError;
    });
    if (!result.isValid) return;
    final ok = await widget.onSubmit(VitalsValidator.toRequestBody(result.values, widget.clock()));
    if (ok && mounted) {
      for (final c in _controllers.values) {
        c.clear();
      }
    }
  }

  Widget _field(VitalSpec spec) {
    final l = context.l10n;
    final error = _errors[spec.type];
    return TextField(
      key: Key('vital.${spec.type}'),
      controller: _controllers[spec.type],
      keyboardType: TextInputType.numberWithOptions(decimal: spec.decimals > 0),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(6)],
      decoration: InputDecoration(
        labelText: vitalLabel(l, spec.type),
        suffixText: spec.unit,
        errorText: error == null ? null : vitalErrorText(l, error),
        errorMaxLines: 2,
      ),
      onChanged: (_) {
        if (_errors.containsKey(spec.type) || _formError != null) {
          setState(() {
            _errors = Map.of(_errors)..remove(spec.type);
            _formError = null;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final specs = VitalSpecs.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.vitalsNoInterpretation, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoCols = constraints.maxWidth >= 320 && MediaQuery.textScalerOf(context).scale(14) <= 20;
            if (!twoCols) {
              return Column(
                children: [
                  for (final s in specs) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(s)),
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < specs.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _field(specs[i])),
                        const SizedBox(width: 12),
                        Expanded(child: i + 1 < specs.length ? _field(specs[i + 1]) : const SizedBox()),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(vitalErrorText(l, _formError!),
                key: const Key('vitalsFormError'), style: const TextStyle(color: AppColors.danger)),
          ),
        FilledButton(
          key: const Key('vitalsSave'),
          onPressed: widget.busy ? null : _save,
          child: Text(l.vitalsSave),
        ),
      ],
    );
  }
}
