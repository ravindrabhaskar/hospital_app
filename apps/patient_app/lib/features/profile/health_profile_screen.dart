import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../abdm/abdm.dart' show AbdmActionsCard;
import 'abha_section.dart';

const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class HealthProfileScreen extends ConsumerWidget {
  const HealthProfileScreen({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    try {
      await op();
      ref.invalidate(patientProfileProvider);
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(patientRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.healthProfile)),
      body: AsyncView<PatientProfile>(
        value: ref.watch(patientProfileProvider),
        onRetry: () => ref.invalidate(patientProfileProvider),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(patientProfileProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              Text(l.healthProfileFor(p.name), style: TextStyle(color: context.textMuted)),
              const SizedBox(height: Space.md),
              CcCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : null,
                      decoration: InputDecoration(labelText: l.bloodGroup),
                      items: [for (final b in bloodGroups) DropdownMenuItem(value: b, child: Text(b))],
                      onChanged: (v) => _run(context, ref, () => repo.update(p.id, {'bloodGroup': v})),
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            label: l.heightCm,
                            initial: p.heightCm,
                            onSubmit: (v) => _run(context, ref, () => repo.update(p.id, {'heightCm': v})),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: _NumberField(
                            label: l.weightKg,
                            initial: p.weightKg,
                            onSubmit: (v) => _run(context, ref, () => repo.update(p.id, {'weightKg': v})),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SectionHeader(
                title: l.allergies,
                trailing: IconButton(
                  tooltip: l.addAllergy,
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onPressed: () async {
                    final r = await showDialog<(String, String?, String?)>(
                        context: context, builder: (_) => const _AllergyDialog());
                    if (r != null && context.mounted) {
                      await _run(context, ref,
                          () => repo.addAllergy(p.id, substance: r.$1, reaction: r.$2, severity: r.$3));
                    }
                  },
                ),
              ),
              if (p.allergies.isEmpty)
                Text(l.noAllergies, style: TextStyle(color: context.textMuted))
              else
                for (final a in p.allergies)
                  _ItemRow(
                    title: a.substance,
                    subtitle: [?a.reaction, ?a.severity, Labels.provenance(l, a.source)].join(' · '),
                    onDelete: () => _run(context, ref, () => repo.deleteAllergy(p.id, a.id)),
                  ),
              SectionHeader(
                title: l.conditions,
                trailing: IconButton(
                  tooltip: l.addCondition,
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  onPressed: () async {
                    final r = await showDialog<(String, String?)>(
                        context: context, builder: (_) => const _ConditionDialog());
                    if (r != null && context.mounted) {
                      await _run(context, ref, () => repo.addCondition(p.id, name: r.$1, since: r.$2));
                    }
                  },
                ),
              ),
              if (p.conditions.isEmpty)
                Text(l.noConditions, style: TextStyle(color: context.textMuted))
              else
                for (final c in p.conditions)
                  _ItemRow(
                    title: c.name,
                    subtitle: [if (c.since != null) l.since(c.since!), Labels.provenance(l, c.source)].join(' · '),
                    onDelete: () => _run(context, ref, () => repo.deleteCondition(p.id, c.id)),
                  ),
              SectionHeader(title: l.abhaTitle),
              AbhaSection(profile: p),
              AbdmActionsCard(profile: p),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.title, required this.subtitle, required this.onDelete});
  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        padding: const EdgeInsets.only(left: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.textMuted)),
                ],
              ),
            ),
            IconButton(
                tooltip: context.l10n.remove,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger)),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.label, required this.initial, required this.onSubmit});
  final String label;
  final double? initial;
  final ValueChanged<double> onSubmit;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _c = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.toStringAsFixed(widget.initial! % 1 == 0 ? 0 : 1));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_c.text.trim());
    if (v != null && v != widget.initial) widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) {
        if (!f) _submit();
      },
      child: TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.label),
      ),
    );
  }
}

class _AllergyDialog extends StatefulWidget {
  const _AllergyDialog();

  @override
  State<_AllergyDialog> createState() => _AllergyDialogState();
}

class _AllergyDialogState extends State<_AllergyDialog> {
  final _s = TextEditingController();
  final _r = TextEditingController();
  String? _sev;

  @override
  void dispose() {
    _s.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.addAllergy),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _s, autofocus: true, decoration: InputDecoration(labelText: l.substance)),
          const SizedBox(height: Space.md),
          TextField(controller: _r, decoration: InputDecoration(labelText: l.reactionOptional)),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: 6,
            children: [
              for (final (k, v) in [('mild', l.mild), ('moderate', l.moderate), ('severe', l.severe)])
                ChoiceChip(label: Text(v), selected: _sev == k, onSelected: (_) => setState(() => _sev = k)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (_s.text.trim().isEmpty) return;
            Navigator.pop(context, (_s.text.trim(), _r.text.trim().isEmpty ? null : _r.text.trim(), _sev));
          },
          child: Text(l.add),
        ),
      ],
    );
  }
}

class _ConditionDialog extends StatefulWidget {
  const _ConditionDialog();

  @override
  State<_ConditionDialog> createState() => _ConditionDialogState();
}

class _ConditionDialogState extends State<_ConditionDialog> {
  final _n = TextEditingController();
  final _since = TextEditingController();

  @override
  void dispose() {
    _n.dispose();
    _since.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.addCondition),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _n, autofocus: true, decoration: InputDecoration(labelText: l.conditionName)),
          const SizedBox(height: Space.md),
          TextField(
            controller: _since,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.sinceYearOptional, hintText: '2019'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (_n.text.trim().isEmpty) return;
            Navigator.pop(context, (_n.text.trim(), _since.text.trim().isEmpty ? null : _since.text.trim()));
          },
          child: Text(l.add),
        ),
      ],
    );
  }
}
