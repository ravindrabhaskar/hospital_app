import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../models/misc.dart';
import '../../models/patient.dart';
import '../../models/records.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../offers/checkout_offers.dart';
import '../payments/booking_success_screen.dart';
import '../payments/payment_sheet.dart';
import 'cart.dart';
import 'pharmacy_screen.dart' show ProductTile;

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _line1 = TextEditingController();
  final _city = TextEditingController(text: 'Hyderabad');
  final _pincode = TextEditingController();
  String? _rxId;
  bool _busy = false;
  final _action = IdempotentAction();
  final _offers = CheckoutOffersController();
  PharmacyOrder? _order;
  Payment? _payment;

  @override
  void initState() {
    super.initState();
    for (final c in [_line1, _city, _pincode]) {
      c.addListener(() => setState(() {}));
    }
    _offers.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _offers.dispose();
    _line1.dispose();
    _city.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _place(PatientSummary patient, Map<String, CartLine> cart) async {
    final l = context.l10n;
    final eRx = ref.read(cartRxProvider);
    setState(() => _busy = true);
    try {
      final res = await ref.read(pharmacyRepositoryProvider).order(
            patientId: patient.id,
            items: {for (final e in cart.entries) e.key: e.value.qty},
            // An e-prescription (§31) satisfies the Rx requirement on its own.
            prescriptionId: eRx?.prescriptionId,
            prescriptionRecordId: eRx == null && cart.needsPrescription ? _rxId : null,
            address: Address(line1: _line1.text.trim(), city: _city.text.trim(), pincode: _pincode.text.trim()),
            idempotencyKey: _action.key,
            couponCode: _offers.couponCode,
            useWallet: _offers.useWallet,
          );
      _action.complete();
      setState(() {
        _order = res.item;
        _payment = res.payment;
      });
      await _pay();
    } on ApiException catch (e) {
      if (!e.isOffline) _action.complete();
      if (mounted) {
        showSnack(context, e.isValidation && cart.needsPrescription ? l.rxMissing : errorMessage(context, e),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final l = context.l10n;
    final o = _order, p = _payment;
    if (o == null || p == null) return;
    final res = await showPaymentSheet(context, payment: p, title: l.medicineOrder);
    if (!mounted) return;
    if (res != null && res.succeeded) {
      ref.read(cartProvider.notifier).clear();
      ref.read(cartRxProvider.notifier).set(null);
      context.pushReplacement('/booking/success',
          extra: BookingSuccessArgs(
            title: l.orderPlaced,
            lines: [
              l.itemsCount(o.items.fold(0, (a, i) => a + i.qty)),
              if (o.partnerName.isNotEmpty) l.fulfilledBy(o.partnerName),
              '${l.amountPaid}: ${money(res.amount)}',
            ],
          ));
    } else {
      setState(() => _payment = res ?? p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cart = ref.watch(cartProvider);
    final patient = ref.watch(activePatientProvider).value;
    final canBook = patient?.can(FamilyPermission.book) ?? false;
    final needsRx = cart.needsPrescription;
    final eRx = ref.watch(cartRxProvider);
    final addressOk = _line1.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty &&
        RegExp(r'^\d{6}$').hasMatch(_pincode.text.trim());
    final ready = cart.isNotEmpty && addressOk && (!needsRx || _rxId != null || eRx != null) && canBook && _payment == null;

    return Scaffold(
      appBar: AppBar(title: Text(l.cart)),
      body: cart.isEmpty && _payment == null
          ? EmptyStateView(
              icon: Icons.shopping_cart_outlined,
              title: l.cartEmpty,
              actionLabel: l.browseMedicines,
              onAction: () => context.pop(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Space.screen),
                    children: [
                      if (_payment != null)
                        CcCard(
                          color: context.peachSurface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_payment!.failed ? l.paymentFailedTitle : l.paymentPendingTitle,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(l.paymentNotConfirmedBody),
                              const SizedBox(height: Space.sm),
                              PrimaryButton(
                                  label: l.retryPaymentAmount(money(_payment!.amount)), onPressed: _pay),
                            ],
                          ),
                        ),
                      for (final line in cart.values) ProductTile(product: line.product, qty: line.qty),
                      if (eRx != null) ...[
                        SectionHeader(title: l.prescription),
                        CcCard(
                          key: const Key('cart-erx'),
                          color: context.mintSurface,
                          child: Row(
                            children: [
                              Icon(Icons.verified_outlined, color: context.brand),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(l.usingEPrescription(
                                    eRx.doctorName, fmtDate(context, eRx.issuedAt))),
                              ),
                              TextButton(
                                onPressed: () => ref.read(cartRxProvider.notifier).set(null),
                                child: Text(l.change),
                              ),
                            ],
                          ),
                        ),
                      ] else if (needsRx) ...[
                        SectionHeader(title: l.prescription),
                        _RxPicker(selected: _rxId, onSelect: (id) => setState(() => _rxId = id)),
                      ],
                      SectionHeader(title: l.deliveryAddress),
                      TextField(controller: _line1, decoration: InputDecoration(labelText: l.addressLine1)),
                      const SizedBox(height: Space.md),
                      Row(
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
                              decoration: InputDecoration(labelText: l.pincode, counterText: ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.lg),
                      CheckoutOffersCard(controller: _offers, purpose: 'pharmacy_order', amount: cart.total),
                      if (!canBook && patient != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.sm),
                          child: Text(l.noBookPermission, style: const TextStyle(color: AppColors.danger)),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                    child: PrimaryButton(
                      label: l.placeOrderAndPay(money(_offers.breakdown(cart.total).payable)),
                      loading: _busy,
                      onPressed: ready && patient != null ? () => _place(patient, cart) : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RxPicker extends ConsumerWidget {
  const _RxPicker({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(recordsProvider(RecordType.prescription));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.rxRequiredBody, style: TextStyle(color: context.textMuted, fontSize: 12.5)),
        const SizedBox(height: Space.sm),
        AsyncView<List<MedicalRecord>>(
          value: v.whenData((p) => p.items),
          compact: true,
          onRetry: () => ref.invalidate(recordsProvider(RecordType.prescription)),
          data: (list) => RadioGroup<String>(
            groupValue: selected,
            onChanged: onSelect,
            child: Column(
              children: [
                for (final r in list)
                  RadioListTile<String>(
                    value: r.id,
                    title: Text(r.title),
                    subtitle: Text(fmtYmd(context, r.recordDate)),
                  ),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await context.push('/records/upload?type=prescription');
            ref.invalidate(recordsProvider(RecordType.prescription));
          },
          icon: const Icon(Icons.upload_file),
          label: Text(l.uploadPrescription),
        ),
      ],
    );
  }
}
