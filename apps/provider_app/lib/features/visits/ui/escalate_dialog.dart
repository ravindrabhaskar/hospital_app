import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../ui/l10n_helpers.dart';

class EscalationRequest {
  const EscalationRequest(this.reason, this.severity);
  final String reason;

  /// urgent | emergency
  final String severity;

  Map<String, dynamic> toBody() => {'reason': reason, 'severity': severity};
}

/// Two-step flow: describe + pick severity, then an explicit confirmation.
Future<EscalationRequest?> showEscalationFlow(BuildContext context) async {
  final request = await showDialog<EscalationRequest>(context: context, builder: (_) => const _EscalateDialog());
  if (request == null || !context.mounted) return null;
  final l = context.l10n;
  final severityLabel = request.severity == 'emergency' ? l.escalateEmergency : l.escalateUrgent;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 36),
      title: Text(l.escalateConfirmTitle),
      content: Text(l.escalateConfirmBody(severityLabel)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.commonCancel)),
        FilledButton(
          key: const Key('escalateConfirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.escalateSend),
        ),
      ],
    ),
  );
  return confirmed == true ? request : null;
}

Future<void> call108() async {
  try {
    await launchUrl(Uri(scheme: 'tel', path: '108'));
  } catch (_) {}
}

class _EscalateDialog extends StatefulWidget {
  const _EscalateDialog();

  @override
  State<_EscalateDialog> createState() => _EscalateDialogState();
}

class _EscalateDialogState extends State<_EscalateDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _severity = 'urgent';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.escalateTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('escalateReason'),
                controller: _reason,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(labelText: l.escalateReason),
                validator: (v) => (v ?? '').trim().isEmpty ? l.escalateReasonRequired : null,
              ),
              const SizedBox(height: 8),
              Text(l.escalateSeverity, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'urgent', label: Text(l.escalateUrgent)),
                  ButtonSegment(
                    value: 'emergency',
                    label: Text(l.escalateEmergency, key: const Key('severityEmergency')),
                  ),
                ],
                selected: {_severity},
                onSelectionChanged: (s) => setState(() => _severity = s.first),
              ),
              if (_severity == 'emergency') ...[
                const SizedBox(height: 12),
                Text(l.escalateEmergencyHint, style: const TextStyle(color: AppColors.dangerDeep)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerDeep,
                    side: const BorderSide(color: AppColors.dangerDeep),
                  ),
                  onPressed: call108,
                  icon: const Icon(Icons.call),
                  label: Text(l.escalateCall108),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        TextButton(
          key: const Key('escalateNext'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, EscalationRequest(_reason.text.trim(), _severity));
            }
          },
          child: Text(l.escalateButton),
        ),
      ],
    );
  }
}
