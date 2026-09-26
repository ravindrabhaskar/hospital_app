import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../payments/payment_sheet.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = appointment;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        onTap: () => context.push('/appointments/${a.id}'),
        child: Row(
          children: [
            Avatar(name: a.doctorName, url: a.doctorPhotoUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.doctorName, style: Theme.of(context).textTheme.titleSmall),
                  Text(a.doctorSpecialty,
                      style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Labels.modeIcon(a.mode), size: 15, color: AppColors.primaryLight),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(fmtDateTime(context, a.startAt),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            StatusPill(
                label: Labels.appointmentStatus(l, a.status), color: Labels.appointmentColor(a.status)),
          ],
        ),
      ),
    );
  }
}

class HomeVisitCard extends StatelessWidget {
  const HomeVisitCard({super.key, required this.visit});
  final HomeVisit visit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = visit;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        onTap: () => context.push('/home-visits/${v.id}'),
        child: Row(
          children: [
            IconTile(icon: Labels.homeServiceIcon(v.serviceCode), accent: Accent.rose, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.serviceName, style: Theme.of(context).textTheme.titleSmall),
                  Text(fmtDateTime(context, v.preferredStart),
                      style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                  if (v.visitCode != null && !v.isTerminal)
                    Text(l.visitCodeInline(v.visitCode!),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ],
              ),
            ),
            StatusPill(
              label: Labels.visitStatus(l, v.status),
              color: v.status == 'cancelled' || v.status == 'escalated'
                  ? AppColors.danger
                  : v.status == 'completed'
                      ? context.textMuted
                      : AppColors.primaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

class TaskTile extends ConsumerStatefulWidget {
  const TaskTile({super.key, required this.task});
  final CareTask task;

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  bool _busy = false;

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await ref.read(carePlanRepositoryProvider).completeTask(widget.task.id);
      ref.invalidate(careTasksProvider);
      ref.invalidate(carePlansProvider);
      ref.invalidate(carePlanProvider(widget.task.carePlanId));
      ref.invalidate(remindersTodayProvider);
      if (mounted) showSnack(context, context.l10n.taskCompleted);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = widget.task;
    final done = t.status == 'done';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.primaryLight : context.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null)),
                  if (t.description != null)
                    Text(t.description!,
                        style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                  Text(
                    [
                      Labels.taskStatus(l, t.status),
                      if (t.dueAt != null) l.dueOn(fmtDateTime(context, t.dueAt!)),
                      if (t.completedByName != null) l.doneBy(t.completedByName!),
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        color: t.status == 'overdue' ? AppColors.danger : context.textMuted),
                  ),
                ],
              ),
            ),
            if (t.isOpen)
              _busy
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _complete, child: Text(l.markDone)),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends ConsumerStatefulWidget {
  const MedicationCard({super.key, required this.medication});
  final Medication medication;

  @override
  ConsumerState<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends ConsumerState<MedicationCard> {
  String? _busyDose;

  Future<void> _log(DoseToday d, String status) async {
    setState(() => _busyDose = d.scheduledAt);
    try {
      await ref.read(carePlanRepositoryProvider).logDose(widget.medication.id, d.scheduledAt, status);
      ref.invalidate(medicationsProvider);
      ref.invalidate(remindersTodayProvider);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busyDose = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = widget.medication;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.medication_outlined, accent: Accent.peach, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: Theme.of(context).textTheme.titleSmall),
                      Text('${m.dose} · ${m.frequency}',
                          style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                      if (m.prescribedByName != null)
                        Text(l.prescribedBy(m.prescribedByName!),
                            style: TextStyle(color: context.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                StatusPill(
                    label: Labels.provenance(l, m.source), color: Labels.provenanceColor(m.source)),
              ],
            ),
            if (m.instructions != null && m.instructions!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(m.instructions!, style: const TextStyle(fontSize: 12.5)),
            ],
            if (m.today.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              const Divider(),
              for (final d in m.today)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: context.textMuted),
                      const SizedBox(width: 6),
                      Text(d.time, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: Labels.doseStatus(l, d.status),
                        color: switch (d.status) {
                          'taken' => AppColors.primaryLight,
                          'missed' => AppColors.danger,
                          'skipped' => context.textMuted,
                          _ => AppColors.peachFg,
                        },
                      ),
                      const Spacer(),
                      if (d.status == 'pending' || d.status == 'missed')
                        if (_busyDose == d.scheduledAt)
                          const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        else ...[
                          TextButton(onPressed: () => _log(d, 'skipped'), child: Text(l.skip)),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                            onPressed: () => _log(d, 'taken'),
                            child: Text(l.markTaken),
                          ),
                        ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Finds the outstanding payment for a booked item and opens the payment sheet.
Future<bool> payOutstanding(BuildContext context, WidgetRef ref,
    {required String refId, required String title}) async {
  final l = context.l10n;
  try {
    final patient = await ref.read(activePatientProvider.future);
    final payments = await ref.read(paymentRepositoryProvider).list(patient.id);
    final p = payments
        .where((p) => p.refId == refId && (p.status == 'pending' || p.status == 'failed'))
        .firstOrNull;
    if (p == null) {
      if (context.mounted) showSnack(context, l.noPendingPayment);
      return false;
    }
    if (!context.mounted) return false;
    final res = await showPaymentSheet(context, payment: p, title: title);
    return res?.succeeded ?? false;
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(context, e), error: true);
    return false;
  }
}

Future<String?> askReason(BuildContext context, {required String title}) async {
  final l = context.l10n;
  final ctrl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: l.reason),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim().isEmpty ? l.noReasonGiven : ctrl.text.trim()),
          child: Text(l.confirm),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}
