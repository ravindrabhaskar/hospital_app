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
import 'care_widgets.dart';
import 'video_join.dart';

/// A booking cancelled because its payment failed can still be paid: the
/// payment retry holds the same slot again (B1).
bool hasFailedPaymentFor(String refId, List<Payment> payments) =>
    payments.any((p) => p.refId == refId && p.failed);

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _State();
}

class _State extends ConsumerState<AppointmentDetailScreen> {
  bool _busy = false;

  void _refreshAll() {
    ref.invalidate(appointmentProvider(widget.id));
    ref.invalidate(paymentsProvider);
    ref.invalidate(appointmentsProvider('upcoming'));
    ref.invalidate(appointmentsProvider('past'));
    ref.invalidate(remindersTodayProvider);
    ref.invalidate(activeEpisodesProvider);
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final reason = await askReason(context, title: l.cancelAppointment);
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(appointmentRepositoryProvider).cancel(widget.id, reason);
      _refreshAll();
      if (mounted) showSnack(context, l.appointmentCancelled);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.appointment)),
      body: AsyncView<Appointment>(
        value: ref.watch(appointmentProvider(widget.id)),
        onRetry: () => ref.invalidate(appointmentProvider(widget.id)),
        data: (a) {
          final upcoming = a.status == 'confirmed' || a.status == 'pending_payment';
          Widget? primary;
          final unpaidRetry = a.status == 'cancelled' &&
              (a.cancelReason == null || a.cancelReason == 'payment_failed') &&
              a.startAt.isAfter(DateTime.now()) &&
              hasFailedPaymentFor(a.id, ref.watch(paymentsProvider).value ?? const []);
          if (a.status == 'pending_payment' || unpaidRetry) {
            primary = PrimaryButton(
              label: l.completePayment(money(a.fee)),
              onPressed: () async {
                final ok = await payOutstanding(context, ref,
                    refId: a.id, title: l.consultationWith(a.doctorName));
                if (ok) _refreshAll();
              },
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Space.screen),
                  children: [
                    CcCard(
                      child: Row(
                        children: [
                          Avatar(name: a.doctorName, url: a.doctorPhotoUrl, size: 56),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.doctorName, style: Theme.of(context).textTheme.titleMedium),
                                Text(a.doctorSpecialty,
                                    style: TextStyle(color: context.textMuted)),
                              ],
                            ),
                          ),
                          StatusPill(
                              label: Labels.appointmentStatus(l, a.status),
                              color: Labels.appointmentColor(a.status)),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    CcCard(
                      child: Column(
                        children: [
                          LabeledValue(label: l.patient, value: a.patientName),
                          LabeledValue(label: l.dateTime, value: fmtDateTime(context, a.startAt)),
                          LabeledValue(label: l.consultationType, value: Labels.mode(l, a.mode)),
                          LabeledValue(label: l.reasonForVisit, value: a.reason),
                          LabeledValue(label: l.fee, value: money(a.fee)),
                        ],
                      ),
                    ),
                    if (isJoinableAppointment(a)) ...[
                      const SizedBox(height: Space.md),
                      VideoJoinCard(appointment: a),
                    ],
                    if (a.clinicianNotes != null && a.clinicianNotes!.isNotEmpty) ...[
                      SectionHeader(title: l.doctorNotes),
                      CcCard(child: Text(a.clinicianNotes!)),
                    ],
                    if (a.careEpisodeId != null) ...[
                      const SizedBox(height: Space.md),
                      ListRowTile(
                        icon: Icons.favorite_border,
                        title: l.viewCareEpisode,
                        onTap: () => context.push('/episodes/${a.careEpisodeId}'),
                      ),
                    ],
                    if (upcoming) ...[
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.push(
                                      '/doctors/${a.doctorId}?reschedule=${a.id}&tab=1'),
                              child: Text(l.reschedule),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger)),
                              onPressed: _busy ? null : _cancel,
                              child: Text(l.cancel),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (primary != null)
                SafeArea(
                  top: false,
                  child: Padding(padding: const EdgeInsets.all(Space.screen), child: primary),
                ),
            ],
          );
        },
      ),
    );
  }
}
