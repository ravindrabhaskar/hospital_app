import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../l10n/app_localizations.dart';
import '../../models/monitoring.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

// Vaccination & preventive screening (API_CONTRACT §52).

String preventiveStatusLabel(AppLocalizations l, String s) => switch (s) {
      'overdue' => l.pvOverdue,
      'due' => l.pvDue,
      'upcoming' => l.pvUpcoming,
      'done' => l.pvDone,
      _ => l.pvNotApplicable,
    };

Color preventiveStatusColor(String s) => switch (s) {
      'overdue' => AppColors.danger,
      'due' => AppColors.peachFg,
      'done' => AppColors.primaryLight,
      _ => AppColors.skyFg,
    };

class PreventiveCareScreen extends ConsumerStatefulWidget {
  const PreventiveCareScreen({super.key});

  @override
  ConsumerState<PreventiveCareScreen> createState() => _PreventiveCareScreenState();
}

class _PreventiveCareScreenState extends ConsumerState<PreventiveCareScreen> {
  String? _patientId;

  Future<void> _markDone(String patientId, PreventiveItem item) async {
    final l = context.l10n;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      helpText: l.whenWasItDone(item.name),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      initialDate: now,
    );
    if (d == null) return;
    try {
      await ref.read(preventiveRepositoryProvider).markDone(patientId, item.code, d);
      ref.invalidate(preventiveScheduleProvider(patientId));
      if (mounted) showSnack(context, l.markedDone);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patients = ref.watch(patientsProvider).value ?? const <PatientSummary>[];
    final active = ref.watch(activePatientProvider).value;
    final pid = _patientId ?? active?.id;
    return Scaffold(
      appBar: AppBar(title: Text(l.preventiveCare)),
      body: pid == null
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: () => ref.refresh(preventiveScheduleProvider(pid).future),
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  if (patients.length > 1)
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in patients) ...[
                            ChoiceChip(
                              key: Key('pv-member-${p.id}'),
                              avatar: Avatar(name: p.name, url: p.avatarUrl, size: 24),
                              label: Text(p.name),
                              selected: p.id == pid,
                              onSelected: (_) => setState(() => _patientId = p.id),
                            ),
                            const SizedBox(width: Space.sm),
                          ],
                        ],
                      ),
                    ),
                  AsyncView<PreventiveSchedule>(
                    value: ref.watch(preventiveScheduleProvider(pid)),
                    onRetry: () => ref.invalidate(preventiveScheduleProvider(pid)),
                    isEmpty: (s) => s.items.isEmpty,
                    empty: EmptyStateView(icon: Icons.vaccines_outlined, title: l.noPreventiveItems),
                    data: (s) {
                      final canManage = patients.where((p) => p.id == pid).firstOrNull?.can(FamilyPermission.manageCare) ??
                          active?.can(FamilyPermission.manageCare) ??
                          false;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final status in ['overdue', 'due', 'upcoming', 'done'])
                            if (s.withStatus(status).isNotEmpty) ...[
                              SectionHeader(title: '${preventiveStatusLabel(l, status)} (${s.withStatus(status).length})'),
                              for (final item in s.withStatus(status))
                                PreventiveTile(
                                  item: item,
                                  onMarkDone: canManage && status != 'done' ? () => _markDone(pid, item) : null,
                                ),
                            ],
                          const SizedBox(height: Space.md),
                          NoticeBox(
                            icon: Icons.info_outline,
                            color: AppColors.skyFg,
                            text: s.scheduleStatus == 'approved' ? l.preventiveNote : l.preventiveNoteFixture,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class PreventiveTile extends StatelessWidget {
  const PreventiveTile({super.key, required this.item, this.onMarkDone});
  final PreventiveItem item;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = item;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('pv-${i.code}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconTile(
                  icon: i.category == 'vaccine' ? Icons.vaccines_outlined : Icons.health_and_safety_outlined,
                  accent: i.category == 'vaccine' ? Accent.lavender : Accent.teal,
                  size: 40),
              const SizedBox(width: Space.md),
              Expanded(child: Text(i.name, style: Theme.of(context).textTheme.titleSmall)),
              StatusPill(label: preventiveStatusLabel(l, i.status), color: preventiveStatusColor(i.status)),
            ]),
            if (i.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(i.description, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if (i.dueDate != null) l.dueOn(fmtYmd(context, i.dueDate)),
                if (i.lastDoneAt != null) l.lastDoneOn(fmtDate(context, i.lastDoneAt!)),
                if (i.repeatEveryMonths != null) l.repeatsEveryMonths(i.repeatEveryMonths!),
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5),
            ),
            if (onMarkDone != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('pv-done-${i.code}'),
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l.markAsDone),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
