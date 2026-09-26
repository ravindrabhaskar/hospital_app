import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../../models/prescription.dart';
import '../../state/data_providers.dart';

String rxFormLabel(AppLocalizations l, String form) => switch (form) {
      'tablet' => l.rxFormTablet,
      'capsule' => l.rxFormCapsule,
      'syrup' => l.rxFormSyrup,
      'injection' => l.rxFormInjection,
      'ointment' => l.rxFormOintment,
      'drops' => l.rxFormDrops,
      'inhaler' => l.rxFormInhaler,
      _ => l.rxFormOther,
    };

/// A compact e-prescription row (doctor, date, medicine count).
class PrescriptionTile extends StatelessWidget {
  const PrescriptionTile({super.key, required this.prescription});
  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = prescription;
    final names = p.items.map((i) => i.drugName).take(3).join(', ');
    return ListRowTile(
      icon: Icons.receipt_long_outlined,
      accent: Accent.teal,
      title: l.rxFromDoctor(p.doctorName),
      subtitle: [fmtDate(context, p.createdAt), l.medicinesCount(p.items.length), if (names.isNotEmpty) names]
          .join(' • '),
      onTap: () => context.push('/prescriptions/${p.id}'),
    );
  }
}

/// E-prescriptions for the active patient, optionally only those of one
/// care episode. Renders nothing while empty when [hideWhenEmpty].
class PrescriptionsSection extends ConsumerWidget {
  const PrescriptionsSection({super.key, this.careEpisodeId, this.hideWhenEmpty = false, this.title});
  final String? careEpisodeId;
  final bool hideWhenEmpty;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(prescriptionsProvider);
    final header = title == null ? null : SectionHeader(title: title!);
    if (v.hasError && !v.hasValue) {
      if (hideWhenEmpty) return const SizedBox.shrink();
      return Column(children: [
        ?header,
        ErrorStateView(compact: true, error: v.error!, onRetry: () => ref.invalidate(prescriptionsProvider)),
      ]);
    }
    final all = v.value;
    if (all == null) return hideWhenEmpty ? const SizedBox.shrink() : const LoadingView(compact: true);
    final list = careEpisodeId == null ? all : all.where((p) => p.careEpisodeId == careEpisodeId).toList();
    if (list.isEmpty) {
      if (hideWhenEmpty) return const SizedBox.shrink();
      return Column(children: [
        ?header,
        EmptyStateView(
          compact: true,
          icon: Icons.receipt_long_outlined,
          title: l.noEPrescriptions,
          message: l.noEPrescriptionsBody,
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        for (final p in list) PrescriptionTile(prescription: p),
      ],
    );
  }
}
