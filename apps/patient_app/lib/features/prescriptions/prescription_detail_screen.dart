import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../models/prescription.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import 'prescription_widgets.dart';

class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pharmacyOn = ref.watch(featureFlagsProvider).pharmacyOrders;
    return Scaffold(
      appBar: AppBar(title: Text(l.ePrescription)),
      body: AsyncView<Prescription>(
        value: ref.watch(prescriptionProvider(id)),
        onRetry: () => ref.invalidate(prescriptionProvider(id)),
        data: (p) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(prescriptionProvider(id).future),
                child: ListView(
                  padding: const EdgeInsets.all(Space.screen),
                  children: [RxCard(prescription: p)],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (pharmacyOn && p.items.isNotEmpty) ...[
                      PrimaryButton(
                        key: const Key('rx-order'),
                        label: l.orderTheseMedicines,
                        icon: Icons.shopping_bag_outlined,
                        onPressed: () => context.push('/prescriptions/${p.id}/pharmacy-match'),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    OutlinedButton.icon(
                      key: const Key('rx-pdf'),
                      onPressed: () => openPdf(
                        context,
                        title: l.ePrescription,
                        fileName: 'prescription-${fmtFileDate(p.createdAt)}.pdf',
                        load: () => ref.read(prescriptionRepositoryProvider).pdf(p.id),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(l.viewPdf),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `2026-09-26` for file names.
String fmtFileDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A prescription rendered like a paper Rx pad: doctor header, patient line,
/// ℞ items with dose / frequency / timing / duration, advice and follow-up.
class RxCard extends StatelessWidget {
  const RxCard({super.key, required this.prescription});
  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = prescription;
    final muted = TextStyle(color: context.textMuted, fontSize: 12.5);
    final patient = [
      p.patientName,
      if (p.patientAge != null) l.ageYears(p.patientAge!),
      if (p.patientGender.isNotEmpty) Labels.gender(l, p.patientGender),
    ].join(' • ');
    return CcCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Letterhead.
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: context.mintSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(p.doctorName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.brand)),
                      ),
                      if (p.doctorQualifications.isNotEmpty) Text(p.doctorQualifications, style: muted),
                      if (p.doctorRegistration.isNotEmpty)
                        Text(l.registrationNo(p.doctorRegistration), style: muted),
                    ],
                  ),
                ),
                Text(fmtDate(context, p.createdAt), style: muted),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: context.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(patient, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          if (p.clinicalNote != null && p.clinicalNote!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
              child: Text(p.clinicalNote!, style: muted),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.xs),
            child: ExcludeSemantics(
              child: Text('℞',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.brand, height: 1)),
            ),
          ),
          for (var i = 0; i < p.items.length; i++) ...[
            if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
            RxItemRow(index: i + 1, item: p.items[i]),
          ],
          if (p.advice != null && p.advice!.trim().isNotEmpty) ...[
            const Divider(),
            _Block(icon: Icons.tips_and_updates_outlined, title: l.doctorsAdvice, body: p.advice!),
          ],
          if (p.followUpInDays != null && p.followUpInDays! > 0)
            _Block(
              icon: Icons.event_repeat_outlined,
              title: l.followUp,
              body: l.followUpInDays(p.followUpInDays!),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                Icon(Icons.verified_outlined, size: 16, color: context.textMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(l.digitallyGenerated, style: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RxItemRow extends StatelessWidget {
  const RxItemRow({super.key, required this.index, required this.item});
  final int index;
  final RxItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final facts = <(IconData, String, String)>[
      (Icons.medication_outlined, l.rxDose, item.dose),
      (Icons.repeat, l.rxFrequency, item.frequency),
      if (item.timing != null && item.timing!.trim().isNotEmpty) (Icons.restaurant_outlined, l.rxTiming, item.timing!),
      (Icons.date_range_outlined, l.rxDuration, l.durationDays(item.durationDays)),
      if (item.times.isNotEmpty) (Icons.alarm, l.rxReminderTimes, item.times.join(', ')),
    ];
    return Semantics(
      container: true,
      label: [
        '$index. ${item.displayName}',
        rxFormLabel(l, item.form),
        for (final f in facts) '${f.$2}: ${f.$3}',
        if (item.instructions != null && item.instructions!.isNotEmpty) item.instructions!,
      ].join('. '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('$index. ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(item.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  ),
                  StatusPill(label: rxFormLabel(l, item.form), color: AppColors.skyFg),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: Space.md,
                runSpacing: 4,
                children: [
                  for (final f in facts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.$1, size: 15, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        Text('${f.$2}: ', style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                        Text(f.$3, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
              if (item.instructions != null && item.instructions!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.instructions!, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryLight),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      );
}
