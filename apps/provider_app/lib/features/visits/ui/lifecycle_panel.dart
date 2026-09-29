import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/home_visit.dart';
import '../../../ui/l10n_helpers.dart';
import '../domain/visit_lifecycle.dart';
import 'sample_collection.dart';

/// Called by the panel to run a lifecycle action.
typedef VisitActionCallback = Future<void> Function(VisitActionType type, Map<String, dynamic> body);

String stepLabel(AppLocalizations l, VisitStep step) => switch (step) {
      VisitStep.accept => l.stepAccept,
      VisitStep.travel => l.stepTravel,
      VisitStep.arrive => l.stepArrive,
      VisitStep.verify => l.stepVerify,
      VisitStep.care => l.stepCare,
      VisitStep.complete => l.stepComplete,
    };

/// Horizontal progress indicator for the visit steps.
class VisitStepper extends StatelessWidget {
  const VisitStepper({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = VisitLifecycle.currentStepIndex(status);
    final total = VisitStep.values.length;
    return Semantics(
      label: l.stepperLabel((current + 1).clamp(1, total), total),
      excludeSemantics: true,
      child: Row(
        children: [
          for (final step in VisitStep.values) ...[
            Expanded(child: _StepDot(step: step, state: _state(step.index, current))),
          ],
        ],
      ),
    );
  }

  static _StepState _state(int index, int current) {
    if (index < current) return _StepState.done;
    if (index == current) return _StepState.current;
    return _StepState.todo;
  }
}

enum _StepState { done, current, todo }

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step, required this.state});
  final VisitStep step;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.primaryLight,
      _StepState.current => AppColors.primary,
      _StepState.todo => AppColors.border,
    };
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: state == _StepState.todo ? AppColors.surface : color,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: state == _StepState.done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : state == _StepState.current
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          stepLabel(context.l10n, step),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: state == _StepState.current ? FontWeight.w700 : FontWeight.w500,
            color: state == _StepState.todo ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The contextual "what to do next" panel that drives the state machine.
class NextActionPanel extends StatefulWidget {
  const NextActionPanel({
    super.key,
    required this.visit,
    required this.onAction,
    required this.onNavigate,
    this.busy = false,
    this.online = true,
  });

  final HomeVisit visit;
  final VisitActionCallback onAction;
  final VoidCallback onNavigate;
  final bool busy;
  final bool online;

  @override
  State<NextActionPanel> createState() => _NextActionPanelState();
}

class _NextActionPanelState extends State<NextActionPanel> {
  final _eta = TextEditingController(text: '20');
  final _code = TextEditingController();
  final _etaForm = GlobalKey<FormState>();
  final _verifyForm = GlobalKey<FormState>();
  bool _consent = false;
  bool _consentError = false;
  final _samples = SampleChecklist();

  @override
  void dispose() {
    _eta.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason != null && reason.isNotEmpty) {
      await widget.onAction(VisitActionType.reject, {'reason': reason});
    }
  }

  Future<void> _complete() async {
    final initial = widget.visit.isSampleCollection ? _samples.summary(context.l10n) : null;
    final summary = await showDialog<String>(context: context, builder: (_) => _CompleteDialog(initial: initial));
    if (summary != null && summary.isNotEmpty) {
      await widget.onAction(VisitActionType.complete, {'summary': summary});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final next = VisitLifecycle.nextActionFor(widget.visit.status);
    final busy = widget.busy;
    final text = Theme.of(context).textTheme;

    Widget info(String message, {IconData icon = Icons.info_outline}) => Row(
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(message, key: const Key('nextInfo'), style: text.bodyMedium)),
          ],
        );

    final navigate = OutlinedButton.icon(
      key: const Key('action.navigate'),
      onPressed: widget.onNavigate,
      icon: const Icon(Icons.navigation_outlined),
      label: Text(l.visitNavigate),
    );

    switch (next) {
      case NextAction.acceptOrReject:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: const Key('action.accept'),
              onPressed: busy ? null : () => widget.onAction(VisitActionType.accept, const {}),
              child: Text(l.actionAccept),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('action.reject'),
              onPressed: busy ? null : _reject,
              child: Text(l.actionReject),
            ),
          ],
        );
      case NextAction.startTravel:
        return Form(
          key: _etaForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('etaField'),
                controller: _eta,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: InputDecoration(labelText: l.actionEtaLabel),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 1 || n > 240 ? l.actionEtaInvalid : null;
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('action.startTravel'),
                onPressed: busy
                    ? null
                    : () {
                        if (!_etaForm.currentState!.validate()) return;
                        widget.onAction(VisitActionType.enRoute, {'etaMinutes': int.parse(_eta.text)});
                      },
                icon: const Icon(Icons.directions_car_outlined),
                label: Text(l.actionStartTravel),
              ),
              const SizedBox(height: 8),
              navigate,
            ],
          ),
        );
      case NextAction.markArrived:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.visit.etaMinutes != null) ...[
              Text(l.visitEta(widget.visit.etaMinutes!), style: text.titleMedium),
              const SizedBox(height: 8),
            ],
            navigate,
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('action.arrived'),
              onPressed: busy ? null : () => widget.onAction(VisitActionType.arrived, const {}),
              icon: const Icon(Icons.home_outlined),
              label: Text(l.actionArrived),
            ),
          ],
        );
      case NextAction.verifyPatient:
        return Form(
          key: _verifyForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.actionVerifyTitle, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(l.actionVerifyBody, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('visitCodeField'),
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w700),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(labelText: l.actionVisitCode),
                validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '') ? null : l.actionVisitCodeInvalid,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('consentCheckbox'),
                value: _consent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l.actionConsent),
                subtitle: _consentError
                    ? Text(l.actionConsentRequired, style: const TextStyle(color: AppColors.danger))
                    : null,
                onChanged: (v) => setState(() {
                  _consent = v ?? false;
                  if (_consent) _consentError = false;
                }),
              ),
              if (!widget.online) ...[
                Text(l.actionVerifyOfflineNote, style: const TextStyle(color: Color(0xFF9A5A10))),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const Key('action.verify'),
                onPressed: busy
                    ? null
                    : () {
                        final okCode = _verifyForm.currentState!.validate();
                        setState(() => _consentError = !_consent);
                        if (!okCode || !_consent) return;
                        widget.onAction(
                          VisitActionType.verifyIdentity,
                          {'visitCode': _code.text, 'consentConfirmed': true},
                        );
                      },
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(l.actionVerify),
              ),
            ],
          ),
        );
      case NextAction.recordCare:
      case NextAction.completeEscalated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info(next == NextAction.recordCare ? l.nextCareIntro : l.nextEscalatedIntro,
                icon: next == NextAction.recordCare ? Icons.fact_check_outlined : Icons.warning_amber_rounded),
            if (widget.visit.isSampleCollection) ...[
              const SizedBox(height: 12),
              SampleChecklistView(
                checklist: _samples,
                fastingRequired: widget.visit.fastingRequired,
                onChanged: () => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('action.complete'),
              // Sample collection: every checklist item must be confirmed first.
              onPressed: busy || (widget.visit.isSampleCollection && !_samples.isComplete) ? null : _complete,
              icon: const Icon(Icons.task_alt),
              label: Text(l.actionComplete),
            ),
          ],
        );
      case NextAction.done:
        return info(l.nextNoAction, icon: Icons.task_alt);
      case NextAction.cancelled:
        return info(l.nextCancelled, icon: Icons.cancel_outlined);
      case NextAction.reassigned:
        return info(l.nextReassigned, icon: Icons.swap_horiz);
      case NextAction.awaitingAssignment:
        return info(l.nextAwaitingAssignment, icon: Icons.hourglass_empty);
    }
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.actionRejectTitle),
      content: Form(
        key: _form,
        child: TextFormField(
          key: const Key('rejectReasonField'),
          controller: _c,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(labelText: l.actionRejectReason),
          validator: (v) => (v ?? '').trim().isEmpty ? l.actionRejectReasonRequired : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        TextButton(
          key: const Key('rejectConfirm'),
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _c.text.trim());
          },
          child: Text(l.actionReject),
        ),
      ],
    );
  }
}

class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog({this.initial});
  final String? initial;

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  late final _c = TextEditingController(text: widget.initial ?? '');
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.actionCompleteTitle),
      content: Form(
        key: _form,
        child: TextFormField(
          key: const Key('summaryField'),
          controller: _c,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(labelText: l.actionSummaryLabel, hintText: l.actionSummaryHint),
          validator: (v) => (v ?? '').trim().length < 5 ? l.actionSummaryRequired : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        TextButton(
          key: const Key('completeConfirm'),
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _c.text.trim());
          },
          child: Text(l.actionComplete),
        ),
      ],
    );
  }
}
