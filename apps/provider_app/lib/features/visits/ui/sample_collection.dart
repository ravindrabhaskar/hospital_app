import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../models/home_visit.dart';
import '../../../ui/l10n_helpers.dart';
import '../../../ui/widgets.dart';

/// Pre-completion checklist for `sample_collection` visits (§44). The visit
/// can only be completed once every item is confirmed.
class SampleChecklist {
  bool tubesLabelled = false;
  bool patientIdVerified = false;
  bool fastingConfirmed = false;
  int? sampleCount;
  bool samplesCollected = false;

  bool get isComplete =>
      tubesLabelled && patientIdVerified && fastingConfirmed && (sampleCount ?? 0) >= 1 && samplesCollected;

  /// Starting text for the visit summary (editable by the provider).
  String summary(AppLocalizations l) => l.sampleSummary(sampleCount ?? 0);
}

/// Ordered tests and fasting requirement, or the generic instruction when the
/// visit doesn't carry its tests.
class LabTestsCard extends StatelessWidget {
  const LabTestsCard({super.key, required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tests = visit.labTests;
    final fasting = visit.fastingRequired;
    return SectionCard(
      key: const Key('labTestsCard'),
      title: l.sampleTestsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tests.isEmpty)
            Text(l.sampleGeneric, key: const Key('sampleGeneric'))
          else
            for (final t in tests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 18, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.sampleType == null ? t.name : '${t.name} (${t.sampleType})')),
                    if (t.fastingRequired)
                      Text(l.sampleFastingShort, style: const TextStyle(color: Color(0xFF9A5A10), fontSize: 12)),
                  ],
                ),
              ),
          if (fasting == true) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('fastingBanner'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.no_food_outlined, color: Color(0xFF9A5A10)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visit.fastingHours == null ? l.sampleFastingRequired : l.sampleFastingHours(visit.fastingHours!),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (fasting == false) ...[
            const SizedBox(height: 8),
            Text(l.sampleNoFasting, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// The checklist inputs; rebuilds its parent through [onChanged].
class SampleChecklistView extends StatefulWidget {
  const SampleChecklistView({super.key, required this.checklist, required this.onChanged, this.fastingRequired});
  final SampleChecklist checklist;
  final VoidCallback onChanged;
  final bool? fastingRequired;

  @override
  State<SampleChecklistView> createState() => _SampleChecklistViewState();
}

class _SampleChecklistViewState extends State<SampleChecklistView> {
  late final _count = TextEditingController(text: widget.checklist.sampleCount?.toString() ?? '');

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = widget.checklist;
    Widget box(String key, String label, bool value, void Function(bool) set) => CheckboxListTile(
      key: Key(key),
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      onChanged: (v) {
        set(v ?? false);
        widget.onChanged();
      },
    );
    // A Material (not a coloured Container) so the checkbox tiles' ink shows.
    return Material(
      key: const Key('sampleChecklist'),
      color: AppColors.mint50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.sampleChecklistTitle, style: Theme.of(context).textTheme.titleSmall),
            box('sample.patientId', l.samplePatientId, c.patientIdVerified, (v) => c.patientIdVerified = v),
            box(
              'sample.fasting',
              widget.fastingRequired == false ? l.sampleFastingNotNeeded : l.sampleFastingConfirmed,
              c.fastingConfirmed,
              (v) => c.fastingConfirmed = v,
            ),
            box('sample.tubes', l.sampleTubesLabelled, c.tubesLabelled, (v) => c.tubesLabelled = v),
            const SizedBox(height: 4),
            // Its own semantics node, so screen readers announce and can
            // target "Number of samples" instead of merging it into the card.
            Semantics(
              container: true,
              textField: true,
              label: l.sampleCount,
              child: TextField(
                key: const Key('sample.count'),
                controller: _count,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                decoration: InputDecoration(labelText: l.sampleCount, isDense: true),
                onChanged: (v) {
                  c.sampleCount = int.tryParse(v);
                  widget.onChanged();
                },
              ),
            ),
            const SizedBox(height: 4),
            box('sample.collected', l.sampleCollectedConfirm, c.samplesCollected, (v) => c.samplesCollected = v),
            if (!c.isComplete)
              Text(
                l.sampleCompleteHint,
                key: const Key('sampleIncomplete'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
