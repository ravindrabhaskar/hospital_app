import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../models/doctor.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../payments/booking_success_screen.dart';
import '../offers/checkout_offers.dart';
import '../payments/payment_sheet.dart';

class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({
    super.key,
    required this.id,
    this.rescheduleAppointmentId,
    this.careEpisodeId,
    this.initialTab,
  });
  final String id;
  final String? rescheduleAppointmentId;
  final String? careEpisodeId;
  final int? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(doctorDetailProvider(id));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView<DoctorDetail>(
        value: v,
        onRetry: () => ref.invalidate(doctorDetailProvider(id)),
        data: (detail) => DefaultTabController(
          length: 3,
          initialIndex: (initialTab ?? 1).clamp(0, 2),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: DoctorHeader(doctor: detail.doctor),
              ),
              TabBar(tabs: [
                Tab(text: l.overview),
                Tab(text: l.availability),
                Tab(text: l.reviews),
              ]),
              Expanded(
                child: TabBarView(
                  children: [
                    _Overview(detail: detail),
                    SlotBookingPanel(
                      doctor: detail.doctor,
                      rescheduleAppointmentId: rescheduleAppointmentId,
                      careEpisodeId: careEpisodeId,
                    ),
                    _Reviews(detail: detail),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorHeader extends StatelessWidget {
  const DoctorHeader({super.key, required this.doctor});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = doctor;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          DoctorPhoto(name: d.name, url: d.photoUrl, width: 76, height: 76, radius: 16),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name, style: Theme.of(context).textTheme.titleLarge),
                Text(d.specialtyName, style: TextStyle(color: context.textMuted)),
                Text('${d.qualifications} • ${l.yearsExperience(d.experienceYears)}',
                    style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                    Text(' ${d.rating.toStringAsFixed(1)} ',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Flexible(
                      child: Text(l.reviewsCount(d.ratingCount),
                          style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.detail});
  final DoctorDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = detail.doctor;
    return ListView(
      padding: const EdgeInsets.all(Space.screen),
      children: [
        if (detail.bio.isNotEmpty) ...[
          Text(l.about, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(detail.bio, style: const TextStyle(height: 1.45)),
          const SizedBox(height: Space.lg),
        ],
        CcCard(
          child: Column(
            children: [
              LabeledValue(label: l.registrationNumber, value: detail.registrationNumber),
              LabeledValue(label: l.languagesSpoken, value: d.languages.join(', ')),
              if (d.facility != null)
                LabeledValue(label: l.clinic, value: '${d.facility!.name}, ${d.facility!.area}'),
              LabeledValue(label: l.modeVideo, value: money(d.fees.video)),
              LabeledValue(label: l.modeAudio, value: money(d.fees.audio)),
              LabeledValue(label: l.modeChat, value: money(d.fees.chat)),
              if (d.fees.inClinic > 0) LabeledValue(label: l.modeInClinic, value: money(d.fees.inClinic)),
            ],
          ),
        ),
        if (d.rankingFactors.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text(l.whyThisDoctor, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in d.rankingFactors) StatusPill(label: f, color: AppColors.skyFg)],
          ),
        ],
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.detail});
  final DoctorDetail detail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (detail.reviews.isEmpty) {
      return EmptyStateView(icon: Icons.reviews_outlined, title: l.noReviews);
    }
    // DoctorDetail.reviews contains published reviews only (§33).
    return ListView.separated(
      padding: const EdgeInsets.all(Space.screen),
      itemCount: detail.reviews.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (_, i) {
        if (i == detail.reviews.length) {
          return Text(l.reviewsModerationNote,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textMuted));
        }
        final r = detail.reviews[i];
        return CcCard(
          semanticLabel: [
            l.ratingOutOfFive(r.rating.round()),
            r.authorLabel,
            if (r.text.trim().isNotEmpty) r.text,
          ].join('. '),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var s = 1; s <= 5; s++)
                      Icon(s <= r.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          [r.authorLabel, if (r.createdAt != null) fmtDate(context, r.createdAt!)].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                    ),
                    if (r.source == 'verified_patient')
                      StatusPill(label: l.verifiedPatient, icon: Icons.verified),
                  ],
                ),
                if (r.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.text),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Booking panel

class SlotBookingPanel extends ConsumerStatefulWidget {
  const SlotBookingPanel({
    super.key,
    required this.doctor,
    this.rescheduleAppointmentId,
    this.careEpisodeId,
  });
  final Doctor doctor;
  final String? rescheduleAppointmentId;
  final String? careEpisodeId;

  @override
  ConsumerState<SlotBookingPanel> createState() => _SlotBookingPanelState();
}

class _SlotBookingPanelState extends ConsumerState<SlotBookingPanel> {
  late DateTime _date;
  Slot? _slot;
  String _mode = 'video';
  bool _busy = false;
  final _reason = TextEditingController();
  final _action = IdempotentAction();
  final _offers = CheckoutOffersController();
  Appointment? _pendingAppointment;
  Payment? _pendingPayment;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _offers.addListener(_offersChanged);
  }

  void _offersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _offers.dispose();
    _reason.dispose();
    super.dispose();
  }

  List<DateTime> get _days => List.generate(7, (i) => _today.add(Duration(days: i)));
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  SlotQuery get _slotQuery => (doctorId: widget.doctor.id, date: _date);

  Future<void> _confirm(PatientSummary patient) async {
    final l = context.l10n;
    final slot = _slot;
    if (slot == null) return;
    setState(() => _busy = true);
    try {
      if (widget.rescheduleAppointmentId != null) {
        final appt = await ref
            .read(appointmentRepositoryProvider)
            .reschedule(widget.rescheduleAppointmentId!, slot.id);
        _invalidateAppointments();
        if (!mounted) return;
        showSnack(context, l.rescheduled);
        context.pushReplacement('/appointments/${appt.id}');
        return;
      }
      final res = await ref.read(appointmentRepositoryProvider).book(
            patientId: patient.id,
            doctorId: widget.doctor.id,
            slotId: slot.id,
            mode: _mode,
            reason: _reason.text.trim().isEmpty ? l.defaultConsultReason : _reason.text.trim(),
            careEpisodeId: widget.careEpisodeId,
            idempotencyKey: _action.key,
            couponCode: _offers.couponCode,
            useWallet: _offers.useWallet,
          );
      _action.complete();
      _invalidateAppointments();
      setState(() {
        _pendingAppointment = res.item;
        _pendingPayment = res.payment;
      });
      await _pay();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isSlotUnavailable) {
        _action.complete();
        setState(() => _slot = null);
        ref.invalidate(slotsProvider(_slotQuery));
        showSnack(context, l.slotUnavailable, error: true);
      } else if (e.isOffline) {
        // Keep the idempotency key: retrying re-sends the same booking.
        showSnack(context, l.errorOffline, error: true);
      } else {
        _action.complete();
        showSnack(context, errorMessage(context, e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateAppointments() {
    ref.invalidate(appointmentsProvider('upcoming'));
    ref.invalidate(activeEpisodesProvider);
    ref.invalidate(allEpisodesProvider);
    ref.invalidate(remindersTodayProvider);
  }

  Future<void> _pay() async {
    final l = context.l10n;
    final payment = _pendingPayment;
    final appt = _pendingAppointment;
    if (payment == null || appt == null) return;
    final result = await showPaymentSheet(
      context,
      payment: payment,
      title: l.consultationWith(widget.doctor.name),
    );
    if (!mounted) return;
    if (result != null && result.succeeded) {
      _invalidateAppointments();
      setState(() {
        _pendingAppointment = null;
        _pendingPayment = null;
      });
      context.pushReplacement(
        '/booking/success',
        extra: BookingSuccessArgs(
          title: l.appointmentConfirmed,
          lines: [
            widget.doctor.name,
            '${Labels.mode(l, appt.mode)} · ${fmtDateTime(context, appt.startAt)}',
            '${l.amountPaid}: ${money(result.amount)}',
          ],
          detailRoute: '/appointments/${appt.id}',
          detailLabel: l.viewAppointment,
        ),
      );
    } else {
      setState(() => _pendingPayment = result ?? payment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = widget.doctor;
    final slots = ref.watch(slotsProvider(_slotQuery));
    final patient = ref.watch(activePatientProvider).value;
    final canBook = patient?.can(FamilyPermission.book) ?? false;
    final modes = <(String, IconData, int)>[
      ('video', Icons.videocam_outlined, d.fees.video),
      ('audio', Icons.graphic_eq, d.fees.audio),
      ('chat', Icons.chat_outlined, d.fees.chat),
      if (d.fees.inClinic > 0 && d.facility != null) ('in_clinic', Icons.local_hospital_outlined, d.fees.inClinic),
    ];
    final isReschedule = widget.rescheduleAppointmentId != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.lg, Space.screen, Space.lg),
            children: [
              if (_pendingPayment != null) _PaymentPendingBanner(payment: _pendingPayment!, onRetry: _pay),
              DateChipRow(
                days: _days,
                selected: _date,
                onSelect: (d) => setState(() {
                  _date = d;
                  _slot = null;
                }),
              ),
              const SizedBox(height: Space.lg),
              AsyncView<List<Slot>>(
                value: slots,
                compact: true,
                onRetry: () => ref.invalidate(slotsProvider(_slotQuery)),
                isEmpty: (s) => s.isEmpty,
                empty: EmptyStateView(
                    compact: true, icon: Icons.event_busy, title: l.noSlots, message: l.noSlotsMessage),
                data: (list) => SlotGrid(
                  slots: list,
                  selected: _slot,
                  onSelect: (s) => setState(() => _slot = s),
                ),
              ),
              if (!isReschedule) ...[
                const SizedBox(height: Space.lg),
                Text(l.consultationType, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    for (final m in modes) ...[
                      Expanded(
                        child: _ModeOption(
                          icon: m.$2,
                          label: Labels.mode(l, m.$1),
                          fee: money(m.$3),
                          selected: _mode == m.$1,
                          onTap: () => setState(() => _mode = m.$1),
                        ),
                      ),
                      if (m != modes.last) const SizedBox(width: Space.sm),
                    ],
                  ],
                ),
                const SizedBox(height: Space.lg),
                TextField(
                  controller: _reason,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l.reasonForVisit,
                    hintText: l.reasonHint,
                    counterText: '',
                  ),
                ),
                if (_slot != null) ...[
                  const SizedBox(height: Space.md),
                  CheckoutOffersCard(controller: _offers, purpose: 'appointment', amount: d.fees.forMode(_mode)),
                ],
              ],
              if (!canBook && patient != null) ...[
                const SizedBox(height: Space.md),
                Text(l.noBookPermission, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
            child: PrimaryButton(
              key: const Key('confirm-appointment'),
              label: isReschedule
                  ? l.rescheduleToSlot
                  : (_slot == null
                      ? l.selectASlot
                      : l.confirmAppointmentFee(money(_offers.breakdown(d.fees.forMode(_mode)).payable))),
              loading: _busy,
              onPressed: (_slot != null && patient != null && canBook && _pendingPayment == null)
                  ? () => _confirm(patient)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentPendingBanner extends StatelessWidget {
  const _PaymentPendingBanner({required this.payment, required this.onRetry});
  final Payment payment;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: CcCard(
        color: context.peachSurface,
        borderColor: AppColors.peachFg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payment.failed ? l.paymentFailedTitle : l.paymentPendingTitle,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.paymentNotConfirmedBody),
            const SizedBox(height: Space.sm),
            PrimaryButton(label: l.retryPaymentAmount(money(payment.amount)), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class DateChipRow extends StatelessWidget {
  const DateChipRow({super.key, required this.days, required this.selected, required this.onSelect});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (_, i) {
          final d = days[i];
          final sel = d == selected;
          return Semantics(
            selected: sel,
            button: true,
            label: fmtDate(context, d),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(d),
              child: Container(
                width: 58,
                decoration: BoxDecoration(
                  color: sel ? context.brand : context.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: sel ? context.brand : AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fmtWeekday(context, d),
                        style: TextStyle(
                            fontSize: 12, color: sel ? Colors.white70 : context.textMuted)),
                    const SizedBox(height: 4),
                    Text('${d.day}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : context.textStrong)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.selected, required this.onSelect});
  final List<Slot> slots;
  final Slot? selected;
  final ValueChanged<Slot> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    final visible = slots.where((s) => s.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (visible.isEmpty) {
      return EmptyStateView(compact: true, icon: Icons.event_busy, title: l.noSlots, message: l.noSlotsMessage);
    }
    final morning = visible.where((s) => s.startAt.hour < 12).toList();
    final afternoon = visible.where((s) => s.startAt.hour >= 12).toList();
    Widget grid(List<Slot> list) => LayoutBuilder(builder: (context, c) {
          const gap = 10.0;
          final w = (c.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final s in list)
                SizedBox(
                  width: w,
                  child: SlotPill(
                    slot: s,
                    selected: selected?.id == s.id,
                    onTap: s.isAvailable ? () => onSelect(s) : null,
                  ),
                ),
            ],
          );
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (morning.isNotEmpty) ...[
          Text(l.morning, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          grid(morning),
          const SizedBox(height: Space.lg),
        ],
        if (afternoon.isNotEmpty) ...[
          Text(l.afternoon, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          grid(afternoon),
        ],
      ],
    );
  }
}

class SlotPill extends StatelessWidget {
  const SlotPill({super.key, required this.slot, required this.selected, this.onTap});
  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final label = fmtTime(context, slot.startAt);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: disabled ? '$label, ${context.l10n.unavailable}' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? context.brand : (disabled ? (context.isDark ? AppColors.darkBackground : AppColors.background) : context.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? context.brand : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : disabled
                          ? context.textMuted.withValues(alpha: 0.5)
                          : context.textStrong,
                  decoration: disabled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.fee,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String fee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '$label $fee',
      excludeSemantics: true,
      child: Material(
        color: selected ? context.mintSurface : context.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? context.brand : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Icon(icon, color: selected ? context.brand : context.textStrong),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                Text(fee, style: TextStyle(fontSize: 11.5, color: context.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
