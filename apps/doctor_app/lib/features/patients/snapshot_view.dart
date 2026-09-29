import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/clinical.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

/// The clinical snapshot summary (contract §16): allergies in red, intake,
/// conditions, active medications, recent vitals, home-visit findings and
/// the advisory AI summary in its own lavender card with source chips.
class SnapshotSummary extends StatelessWidget {
  const SnapshotSummary({super.key, required this.snapshot, this.showAi = true});
  final ClinicalSnapshot snapshot;
  final bool showAi;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = snapshot.patient;
    final vitals = snapshot.latestVitals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AllergyBanner(
          allergies: [
            for (final a in p.allergies)
              [a.substance, if (a.reaction != null) a.reaction!, if (a.severity != null) a.severity!].join(' – '),
          ],
        ),
        gap12,
        if (snapshot.intake != null) ...[
          SectionCard(
            title: l.intakeTitle,
            icon: Icons.assignment_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.intake!.chiefComplaint != null)
                  LabeledValue(label: l.intakeComplaint, value: snapshot.intake!.chiefComplaint!),
                if (snapshot.intake!.duration != null)
                  LabeledValue(label: l.intakeDuration, value: snapshot.intake!.duration!),
                if (snapshot.intake!.severity != null)
                  LabeledValue(label: l.intakeSeverity, value: '${formatNumber(snapshot.intake!.severity!)}/10'),
                if (snapshot.intake!.symptoms.isNotEmpty)
                  LabeledValue(label: l.intakeSymptoms, value: snapshot.intake!.symptoms.join(', ')),
              ],
            ),
          ),
          gap12,
        ],
        SectionCard(
          title: l.conditionsTitle,
          icon: Icons.monitor_heart_outlined,
          child: p.conditions.isEmpty
              ? Text(l.noneRecorded, style: const TextStyle(color: AppColors.textSecondary))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in p.conditions)
                      Chip(label: Text(c.since == null ? c.name : '${c.name} (${c.since})')),
                  ],
                ),
        ),
        gap12,
        SectionCard(
          title: l.activeMedsTitle,
          icon: Icons.medication_outlined,
          child: snapshot.activeMedications.isEmpty
              ? Text(l.noneRecorded, style: const TextStyle(color: AppColors.textSecondary))
              : Column(
                  children: [
                    for (final m in snapshot.activeMedications)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.medication, color: AppColors.primaryLight),
                        title: Text('${m.name} ${m.dose}'.trim()),
                        subtitle: Text(
                          [
                            m.frequency,
                            if (m.times.isNotEmpty) m.times.join(', '),
                            if (m.prescribedByName != null) m.prescribedByName!,
                          ].where((s) => s.isNotEmpty).join(' · '),
                        ),
                      ),
                  ],
                ),
        ),
        gap12,
        SectionCard(
          title: l.recentVitalsTitle,
          icon: Icons.favorite_border,
          child: vitals.isEmpty
              ? Text(l.noneRecorded, style: const TextStyle(color: AppColors.textSecondary))
              : Wrap(spacing: 8, runSpacing: 8, children: [for (final v in vitals) _VitalTile(vital: v)]),
        ),
        if (snapshot.homeVisitFindings.isNotEmpty) ...[
          gap12,
          SectionCard(
            title: l.homeVisitFindingsTitle,
            icon: Icons.home_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in snapshot.homeVisitFindings.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${f.serviceName} · ${formatDate(context, f.at)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (f.providerName != null)
                          Text(f.providerName!, style: const TextStyle(color: AppColors.textSecondary)),
                        if (f.summary != null) Text(f.summary!),
                        if (f.notes != null && f.notes != f.summary) Text(f.notes!),
                        if (f.escalationReason != null)
                          Text(
                            '${l.escalatedLabel}: ${f.escalationReason}',
                            style: const TextStyle(color: AppColors.dangerDeep, fontWeight: FontWeight.w600),
                          ),
                        if (f.vitals.isNotEmpty)
                          Text(
                            f.vitals
                                .map((v) => '${vitalLabel(l, v.type)} ${formatNumber(v.value)} ${v.unit}')
                                .join(' · '),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (showAi && snapshot.aiSummary != null) ...[gap12, AiSummaryCard(summary: snapshot.aiSummary!)],
      ],
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({required this.vital});
  final Vital vital;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      label: '${vitalLabel(l, vital.type)} ${formatNumber(vital.value)} ${vital.unit}',
      excludeSemantics: true,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.mint50, borderRadius: BorderRadius.circular(AppSpacing.tileRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vitalLabel(l, vital.type), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(
              '${formatNumber(vital.value)} ${vital.unit}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              formatDateTime(context, vital.measuredAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Advisory AI summary with per-claim source chips and accept/reject feedback
/// (`POST /clinician/ai-feedback`).
class AiSummaryCard extends ConsumerStatefulWidget {
  const AiSummaryCard({super.key, required this.summary});
  final AiSummary summary;

  @override
  ConsumerState<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<AiSummaryCard> {
  String? _sent;
  bool _busy = false;

  Future<void> _feedback(String decision) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(clinicianRepositoryProvider)
          .aiFeedback(interactionId: widget.summary.interactionId, decision: decision);
      if (mounted) setState(() => _sent = decision);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context.l10n, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.summary;
    return AiAdvisoryCard(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.model != null || s.generatedAt != null)
            Text(
              [
                if (s.model != null) s.model!,
                if (s.generatedAt != null) formatDateTime(context, s.generatedAt),
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          if (s.interactionId.isNotEmpty) ...[
            gap8,
            _sent != null
                ? Text(
                    l.aiFeedbackThanks,
                    style: const TextStyle(color: AppColors.lavender, fontWeight: FontWeight.w600),
                  )
                : Row(
                    children: [
                      Text(l.aiFeedbackPrompt, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      IconButton(
                        tooltip: l.aiAccept,
                        onPressed: _busy ? null : () => _feedback('accept'),
                        icon: const Icon(Icons.thumb_up_alt_outlined, color: AppColors.lavender),
                      ),
                      IconButton(
                        tooltip: l.aiReject,
                        onPressed: _busy ? null : () => _feedback('reject'),
                        icon: const Icon(Icons.thumb_down_alt_outlined, color: AppColors.lavender),
                      ),
                    ],
                  ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.claims.isEmpty) Text(s.text),
          for (final c in s.claims)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ${c.text}'),
                  if (c.sources.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final src in c.sources)
                          TonePill(
                            key: const Key('aiSourceChip'),
                            label: '${sourceKindLabel(l, src.kind)}: ${src.label}',
                            bg: Colors.white,
                            fg: const Color(0xFF4B3A99),
                            icon: Icons.link,
                            semanticsPrefix: l.aiSource,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
