import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../doctors/doctor_detail_screen.dart' show DateChipRow;
import '../offers/checkout_offers.dart';
import '../payments/booking_success_screen.dart';
import '../payments/payment_sheet.dart';

/// Preferred arrival windows offered to the patient (local time).
const visitWindows = [(7, 9), (9, 11), (11, 13), (14, 16), (16, 18)];

class BookHomeVisitScreen extends ConsumerStatefulWidget {
  const BookHomeVisitScreen({super.key, this.serviceCode, this.careEpisodeId});
  final String? serviceCode;
  final String? careEpisodeId;

  @override
  ConsumerState<BookHomeVisitScreen> createState() => _BookHomeVisitScreenState();
}

class _BookHomeVisitScreenState extends ConsumerState<BookHomeVisitScreen> {
  late String? _service = widget.serviceCode;
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _landmark = TextEditingController();
  final _city = TextEditingController(text: 'Hyderabad');
  final _pincode = TextEditingController();
  final _reason = TextEditingController();
  Serviceability? _svc;
  String? _svcError;
  bool _checking = false;
  late DateTime _date;
  (int, int)? _window;
  bool _busy = false;
  final _action = IdempotentAction();
  final _offers = CheckoutOffersController();
  HomeVisit? _visit;
  Payment? _payment;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
    for (final c in [_line1, _city, _reason]) {
      c.addListener(() => setState(() {}));
    }
    _offers.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _offers.dispose();
    for (final c in [_line1, _line2, _landmark, _city, _pincode, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  List<DateTime> get _days {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  bool _windowAvailable((int, int) w) {
    final start = DateTime(_date.year, _date.month, _date.day, w.$1);
    return start.isAfter(DateTime.now().add(const Duration(minutes: 60)));
  }

  Future<void> _checkPincode() async {
    final pin = _pincode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _svcError = context.l10n.pincodeInvalid);
      return;
    }
    setState(() {
      _checking = true;
      _svcError = null;
      _svc = null;
    });
    try {
      final r = await ref.read(homeVisitRepositoryProvider).serviceability(pin);
      if (mounted) setState(() => _svc = r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _svcError = e.isNotServiceable ? context.l10n.notServiceable : errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  bool get _ready =>
      _service != null &&
      _line1.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      (_svc?.serviceable ?? false) &&
      _window != null &&
      _windowAvailable(_window!) &&
      _reason.text.trim().isNotEmpty;

  Future<void> _book(PatientSummary patient, List<HomeVisitService> services) async {
    final l = context.l10n;
    final w = _window!;
    setState(() => _busy = true);
    try {
      final res = await ref.read(homeVisitRepositoryProvider).book(
            patientId: patient.id,
            serviceCode: _service!,
            address: Address(
              line1: _line1.text.trim(),
              line2: _line2.text.trim(),
              landmark: _landmark.text.trim(),
              city: _city.text.trim(),
              pincode: _pincode.text.trim(),
            ),
            preferredStart: DateTime(_date.year, _date.month, _date.day, w.$1),
            preferredEnd: DateTime(_date.year, _date.month, _date.day, w.$2),
            reason: _reason.text.trim(),
            careEpisodeId: widget.careEpisodeId,
            idempotencyKey: _action.key,
            couponCode: _offers.couponCode,
            useWallet: _offers.useWallet,
          );
      _action.complete();
      ref.invalidate(homeVisitsProvider('active'));
      ref.invalidate(activeEpisodesProvider);
      setState(() {
        _visit = res.item;
        _payment = res.payment;
      });
      await _pay();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!e.isOffline) _action.complete();
      if (e.isNotServiceable) setState(() => _svc = null);
      showSnack(context, e.isNotServiceable ? l.notServiceable : errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final l = context.l10n;
    final v = _visit, p = _payment;
    if (v == null || p == null) return;
    final result = await showPaymentSheet(context, payment: p, title: v.serviceName);
    if (!mounted) return;
    if (result != null && result.succeeded) {
      ref.invalidate(homeVisitsProvider('active'));
      ref.invalidate(remindersTodayProvider);
      context.pushReplacement(
        '/booking/success',
        extra: BookingSuccessArgs(
          title: l.homeVisitBooked,
          lines: [
            v.serviceName,
            '${fmtDate(context, v.preferredStart)} · ${fmtTime(context, v.preferredStart)} – ${fmtTime(context, v.preferredEnd)}',
            if (v.discountApplied > 0) l.planDiscountApplied(money(v.discountApplied)),
            '${l.amountPaid}: ${money(result.amount)}',
          ],
          highlight: v.visitCode,
          highlightLabel: l.visitCode,
          detailRoute: '/home-visits/${v.id}',
          detailLabel: l.trackVisit,
        ),
      );
    } else {
      setState(() => _payment = result ?? p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final services = ref.watch(homeVisitServicesProvider);
    final patient = ref.watch(activePatientProvider).value;
    final canBook = patient?.can(FamilyPermission.book) ?? false;
    final selected = services.value?.where((s) => s.code == _service).firstOrNull;
    final hasPlan = ref.watch(mySubscriptionProvider).value?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l.bookHomeCheckup)),
      body: AsyncView<List<HomeVisitService>>(
        value: services,
        onRetry: () => ref.invalidate(homeVisitServicesProvider),
        data: (list) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  if (_payment != null && _visit != null)
                    CcCard(
                      color: context.peachSurface,
                      borderColor: AppColors.peachFg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_payment!.failed ? l.paymentFailedTitle : l.paymentPendingTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(l.paymentNotConfirmedBody),
                          if (_visit!.discountApplied > 0) ...[
                            const SizedBox(height: 4),
                            DiscountLine(amount: _visit!.discountApplied),
                          ],
                          const SizedBox(height: Space.sm),
                          PrimaryButton(label: l.retryPaymentAmount(money(_payment!.amount)), onPressed: _pay),
                          TextButton(
                            onPressed: () => context.pushReplacement('/home-visits/${_visit!.id}'),
                            child: Text(l.viewRequest),
                          ),
                        ],
                      ),
                    ),
                  Text(l.selectService, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  RadioGroup<String>(
                    groupValue: _service,
                    onChanged: (v) => setState(() => _service = v),
                    child: Column(
                      children: [
                        for (final s in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: CcCard(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              borderColor: _service == s.code ? context.brand : null,
                              child: RadioListTile<String>(
                                value: s.code,
                                title: Text(s.name),
                                subtitle: Text('${money(s.price)} · ${l.durationMins(s.durationMins)}'),
                                secondary: Icon(Labels.homeServiceIcon(s.code), color: AppColors.primaryLight),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SectionHeader(title: l.address),
                  TextField(controller: _line1, decoration: InputDecoration(labelText: l.addressLine1)),
                  const SizedBox(height: Space.md),
                  TextField(controller: _line2, decoration: InputDecoration(labelText: l.addressLine2)),
                  const SizedBox(height: Space.md),
                  TextField(controller: _landmark, decoration: InputDecoration(labelText: l.landmark)),
                  const SizedBox(height: Space.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: TextField(controller: _city, decoration: InputDecoration(labelText: l.city))),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: TextField(
                          controller: _pincode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (v) {
                            setState(() => _svc = null);
                            if (v.length == 6) _checkPincode();
                          },
                          decoration: InputDecoration(labelText: l.pincode, counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  if (_checking)
                    const LinearProgressIndicator()
                  else if (_svcError != null)
                    ServiceabilityNote(ok: false, text: _svcError!)
                  else if (_svc != null)
                    ServiceabilityNote(
                      ok: _svc!.serviceable,
                      text: _svc!.serviceable
                          ? (_svc!.message.isNotEmpty ? _svc!.message : l.serviceable(_svc!.zoneName ?? ''))
                          : (_svc!.message.isNotEmpty ? _svc!.message : l.notServiceable),
                    ),
                  SectionHeader(title: l.preferredTime),
                  DateChipRow(
                    days: _days,
                    selected: _date,
                    onSelect: (d) => setState(() {
                      _date = d;
                      _window = null;
                    }),
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final w in visitWindows)
                        ChoiceChip(
                          label: Text(
                              '${fmtTime(context, DateTime(2000, 1, 1, w.$1))} – ${fmtTime(context, DateTime(2000, 1, 1, w.$2))}'),
                          selected: _window == w,
                          onSelected: _windowAvailable(w) ? (_) => setState(() => _window = w) : null,
                        ),
                    ],
                  ),
                  if (hasPlan)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.md),
                      child: CcCard(
                        key: const Key('plan-discount-note'),
                        color: context.mintSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium_outlined, color: context.brand),
                            const SizedBox(width: 8),
                            Expanded(child: Text(l.planDiscountWillApply)),
                          ],
                        ),
                      ),
                    ),
                  SectionHeader(title: l.reasonForVisit),
                  TextField(
                    controller: _reason,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: InputDecoration(hintText: l.homeVisitReasonHint),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: Space.sm),
                    CheckoutOffersCard(controller: _offers, purpose: 'home_visit', amount: selected.price),
                  ],
                  if (!canBook && patient != null)
                    Text(l.noBookPermission, style: const TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: PrimaryButton(
                  label: selected == null
                      ? l.bookHomeCheckup
                      : l.bookAndPay(money(_offers.breakdown(selected.price).payable)),
                  loading: _busy,
                  onPressed: (_ready && canBook && patient != null && _payment == null)
                      ? () => _book(patient, list)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceabilityNote extends StatelessWidget {
  const ServiceabilityNote({super.key, required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.primaryLight : AppColors.danger;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.location_off_outlined, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

/// "Family Care Plan discount −₹X" line on the booking summary (§37).
class DiscountLine extends StatelessWidget {
  const DiscountLine({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('home-visit-discount'),
        children: [
          const Icon(Icons.savings_outlined, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(context.l10n.planDiscountApplied(money(amount)),
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
          ),
        ],
      );
}
