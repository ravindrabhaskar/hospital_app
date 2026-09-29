import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart';
import '../../l10n/app_localizations.dart';
import '../../models/care.dart';
import '../../models/patient.dart';
import '../../models/services.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';
import '../home_checkup/address_slot_section.dart';
import '../offers/checkout_offers.dart';
import '../payments/booking_success_screen.dart';
import '../payments/payment_sheet.dart';

// Lab tests at home (API_CONTRACT §44).

String labStatusLabel(AppLocalizations l, String s) => switch (s) {
      'pending_payment' => l.labPendingPayment,
      'scheduled' => l.labScheduled,
      'sample_collected' => l.labSampleCollected,
      'processing' => l.labProcessing,
      'report_ready' => l.labReportReady,
      'cancelled' => l.labCancelled,
      _ => humanize(s),
    };

Color labStatusColor(String s) => switch (s) {
      'report_ready' => AppColors.primaryLight,
      'cancelled' => AppColors.danger,
      'pending_payment' => AppColors.peachFg,
      _ => AppColors.skyFg,
    };

String sampleLabel(AppLocalizations l, String s) => switch (s) {
      'blood' => l.sampleBlood,
      'urine' => l.sampleUrine,
      'swab' => l.sampleSwab,
      _ => l.sampleOther,
    };

/// Strike-through MRP next to the price when discounted.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price, required this.mrp});
  final int price;
  final int mrp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(money(price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        if (mrp > price)
          Text(money(mrp),
              style: TextStyle(
                  fontSize: 12, color: context.textMuted, decoration: TextDecoration.lineThrough)),
      ],
    );
  }
}

class LabScreen extends ConsumerStatefulWidget {
  const LabScreen({super.key});

  @override
  ConsumerState<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends ConsumerState<LabScreen> {
  final _search = TextEditingController();
  String? _q;
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cart = ref.watch(labCartProvider);
    final query = (q: _q, category: _category);
    final catalog = ref.watch(labCatalogProvider).value;
    final categories = <String>{for (final t in catalog?.values ?? const <LabTest>[]) if (t.category.isNotEmpty) t.category}
        .toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.labTests),
        actions: [
          IconButton(
            tooltip: l.myLabOrders,
            onPressed: () => context.push('/lab/orders'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: PrimaryButton(
                  key: const Key('lab-view-cart'),
                  icon: Icons.shopping_bag_outlined,
                  label: l.labCartBar(cart.count, money(cart.total)),
                  onPressed: () => context.push('/lab/checkout'),
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(labTestsProvider(query));
          ref.invalidate(labPackagesProvider);
          ref.invalidate(labCatalogProvider);
          await ref.read(labPackagesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.labIntro, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.md),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _q = v.trim().isEmpty ? null : v.trim()),
              decoration: InputDecoration(
                hintText: l.searchLabTests,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q == null
                    ? null
                    : IconButton(
                        tooltip: l.clearFilters,
                        onPressed: () => setState(() {
                          _search.clear();
                          _q = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                        label: Text(l.all),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null)),
                    for (final c in categories) ...[
                      const SizedBox(width: Space.sm),
                      ChoiceChip(
                          label: Text(humanize(c)),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c)),
                    ],
                  ],
                ),
              ),
            ],
            if (_q == null && _category == null) ...[
              SectionHeader(title: l.healthPackages),
              AsyncView<List<LabPackage>>(
                value: ref.watch(labPackagesProvider),
                compact: true,
                onRetry: () => ref.invalidate(labPackagesProvider),
                isEmpty: (p) => p.isEmpty,
                empty: Text(l.noPackages, style: TextStyle(color: context.textMuted)),
                data: (list) => Column(children: [for (final p in list) LabPackageTile(package: p)]),
              ),
            ],
            SectionHeader(title: _q == null ? l.allTests : l.resultsFor(_q!)),
            AsyncView<List<LabTest>>(
              value: ref.watch(labTestsProvider(query)),
              compact: true,
              onRetry: () => ref.invalidate(labTestsProvider(query)),
              isEmpty: (t) => t.isEmpty,
              empty: EmptyStateView(compact: true, icon: Icons.biotech_outlined, title: l.noLabTests),
              data: (list) => Column(children: [for (final t in list) LabTestTile(test: t)]),
            ),
            const SizedBox(height: Space.md),
            Text(l.labPricingNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
      ),
    );
  }
}

class LabPackageTile extends ConsumerWidget {
  const LabPackageTile({super.key, required this.package});
  final LabPackage package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = package;
    final inCart = ref.watch(labCartProvider).hasPackage(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('lab-package-${p.id}'),
        borderColor: inCart ? AppColors.primary : null,
        child: Row(
          children: [
            const IconTile(icon: Icons.inventory_2_outlined, accent: Accent.lavender, size: 44),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(l.testsIncluded(p.testIds.length), style: TextStyle(fontSize: 12, color: context.textMuted)),
                  if (p.description.isNotEmpty)
                    Text(p.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: context.textMuted)),
                ],
              ),
            ),
            PriceTag(price: p.price, mrp: p.mrp),
            const SizedBox(width: Space.sm),
            _CartToggle(
              inCart: inCart,
              name: p.name,
              onTap: () => ref.read(labCartProvider.notifier).togglePackage(p),
            ),
          ],
        ),
      ),
    );
  }
}

class LabTestTile extends ConsumerWidget {
  const LabTestTile({super.key, required this.test});
  final LabTest test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = test;
    final cart = ref.watch(labCartProvider);
    final inCart = cart.hasTest(t.id);
    final covered = cart.coveredByPackage(t.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('lab-test-${t.id}'),
        borderColor: inCart ? AppColors.primary : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusPill(label: sampleLabel(l, t.sampleType), color: AppColors.skyFg),
                      if (t.fastingRequired)
                        StatusPill(
                          label: t.fastingHours == null ? l.fastingRequired : l.fastingHoursShort(t.fastingHours!),
                          color: AppColors.peachFg,
                          icon: Icons.no_food_outlined,
                        ),
                      if (t.turnaroundHours > 0)
                        StatusPill(label: l.reportInHours(t.turnaroundHours), color: AppColors.lavenderFg),
                      if (covered) StatusPill(label: l.includedInPackage, icon: Icons.check),
                    ],
                  ),
                ],
              ),
            ),
            PriceTag(price: t.price, mrp: t.mrp),
            const SizedBox(width: Space.sm),
            _CartToggle(
              inCart: inCart,
              name: t.name,
              onTap: () => ref.read(labCartProvider.notifier).toggleTest(t),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartToggle extends StatelessWidget {
  const _CartToggle({required this.inCart, required this.name, required this.onTap});
  final bool inCart;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return IconButton.filledTonal(
      tooltip: inCart ? l.removeFromCart(name) : l.addToCart(name),
      onPressed: onTap,
      icon: Icon(inCart ? Icons.check : Icons.add),
    );
  }
}

/// Fasting notice shown in the cart when any test (or a test inside a
/// selected package) needs fasting.
class FastingNotice extends StatelessWidget {
  const FastingNotice({super.key, required this.hours});
  final int hours;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      child: NoticeBox(
        key: const Key('fasting-notice'),
        icon: Icons.no_food_outlined,
        title: l.fastingNoticeTitle,
        text: l.fastingNoticeBody(hours),
      ),
    );
  }
}

class LabCheckoutScreen extends ConsumerStatefulWidget {
  const LabCheckoutScreen({super.key});

  @override
  ConsumerState<LabCheckoutScreen> createState() => _LabCheckoutScreenState();
}

class _LabCheckoutScreenState extends ConsumerState<LabCheckoutScreen> {
  final _slot = AddressSlotController();
  final _offers = CheckoutOffersController();
  final _action = IdempotentAction();
  bool _busy = false;
  LabOrder? _order;
  Payment? _payment;

  @override
  void initState() {
    super.initState();
    _slot.addListener(_changed);
    _offers.addListener(_changed);
  }

  @override
  void dispose() {
    _slot.dispose();
    _offers.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _book(PatientSummary patient, LabCart cart) async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(labRepositoryProvider).order(
            patientId: patient.id,
            testIds: cart.testIds,
            packageIds: cart.packageIds,
            address: _slot.address,
            preferredStart: _slot.start,
            preferredEnd: _slot.end,
            couponCode: _offers.couponCode,
            useWallet: _offers.useWallet,
            idempotencyKey: _action.key,
          );
      _action.complete();
      setState(() {
        _order = res.item;
        _payment = res.payment;
      });
      await _pay();
    } on ApiException catch (e) {
      if (!e.isOffline) _action.complete();
      if (mounted) showSnack(context, e.isNotServiceable ? context.l10n.notServiceable : errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final l = context.l10n;
    final o = _order, p = _payment;
    if (o == null || p == null) return;
    final res = await showPaymentSheet(context, payment: p, title: l.labOrderTitle);
    if (!mounted) return;
    ref.invalidate(labOrdersProvider);
    if (res != null && res.succeeded) {
      ref.read(labCartProvider.notifier).clear();
      context.pushReplacement('/booking/success',
          extra: BookingSuccessArgs(
            title: l.labBooked,
            lines: [
              l.testsIncluded(o.tests.length),
              if (o.preferredStart != null && o.preferredEnd != null)
                '${fmtDate(context, o.preferredStart!)} · ${fmtTime(context, o.preferredStart!)} – ${fmtTime(context, o.preferredEnd!)}',
              '${l.amountPaid}: ${money(res.amount)}',
            ],
            detailRoute: '/lab/orders/${o.id}',
            detailLabel: l.trackOrder,
          ));
    } else {
      setState(() => _payment = res ?? p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cart = ref.watch(labCartProvider);
    final catalog = ref.watch(labCatalogProvider).value ?? const <String, LabTest>{};
    final patient = ref.watch(activePatientProvider).value;
    final canBook = patient?.can(FamilyPermission.book) ?? false;
    final fasting = cart.fastingHours(catalog);
    final breakdown = _offers.breakdown(cart.total);
    final ready = !cart.isEmpty && _slot.ready && canBook && _payment == null;
    return Scaffold(
      appBar: AppBar(title: Text(l.labCart)),
      body: cart.isEmpty && _payment == null
          ? EmptyStateView(
              icon: Icons.biotech_outlined,
              title: l.labCartEmpty,
              actionLabel: l.browseTests,
              onAction: () => context.pop(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Space.screen),
                    children: [
                      if (_payment != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: NoticeBox(
                            icon: Icons.error_outline,
                            title: _payment!.failed ? l.paymentFailedTitle : l.paymentPendingTitle,
                            text: l.paymentNotConfirmedBody,
                            action: Wrap(spacing: 8, children: [
                              FilledButton(onPressed: _pay, child: Text(l.retryPaymentAmount(money(_payment!.amount)))),
                              TextButton(
                                  onPressed: () => context.pushReplacement('/lab/orders/${_order!.id}'),
                                  child: Text(l.viewRequest)),
                            ]),
                          ),
                        ),
                      for (final p in cart.packages.values)
                        _CartLine(
                          title: p.name,
                          subtitle: l.testsIncluded(p.testIds.length),
                          price: p.price,
                          onRemove: () => ref.read(labCartProvider.notifier).togglePackage(p),
                        ),
                      for (final t in cart.tests.values)
                        _CartLine(
                          title: t.name,
                          subtitle: cart.coveredByPackage(t.id) ? l.includedInPackage : sampleLabel(l, t.sampleType),
                          price: cart.coveredByPackage(t.id) ? 0 : t.price,
                          onRemove: () => ref.read(labCartProvider.notifier).toggleTest(t),
                        ),
                      if (fasting != null) ...[const SizedBox(height: Space.sm), FastingNotice(hours: fasting)],
                      AddressSlotSection(
                        controller: _slot,
                        addressTitle: l.sampleCollectionAddress,
                        timeTitle: l.sampleCollectionTime,
                      ),
                      const SizedBox(height: Space.lg),
                      if (cart.mrpTotal > cart.total)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: Text(l.youSaveVsMrp(money(cart.mrpTotal - cart.total)),
                              style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                        ),
                      CheckoutOffersCard(controller: _offers, purpose: 'lab_order', amount: cart.total),
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
                      key: const Key('lab-book'),
                      label: l.bookAndPay(money(breakdown.payable)),
                      loading: _busy,
                      onPressed: ready && patient != null ? () => _book(patient, cart) : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.title, required this.subtitle, required this.price, required this.onRemove});
  final String title;
  final String subtitle;
  final int price;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        padding: const EdgeInsets.only(left: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: context.textMuted)),
                ],
              ),
            ),
            Text(money(price), style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: context.l10n.removeFromCart(title),
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

class LabOrdersScreen extends ConsumerWidget {
  const LabOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myLabOrders)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(labOrdersProvider.future),
        child: AsyncView<List<LabOrder>>(
          value: ref.watch(labOrdersProvider),
          onRetry: () => ref.invalidate(labOrdersProvider),
          isEmpty: (o) => o.isEmpty,
          empty: ListView(children: [
            EmptyStateView(
              icon: Icons.biotech_outlined,
              title: l.noLabOrders,
              actionLabel: l.browseTests,
              onAction: () => context.pushReplacement('/lab'),
            ),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              for (final o in list)
                ListRowTile(
                  icon: Icons.biotech_outlined,
                  accent: Accent.lavender,
                  title: o.tests.map((t) => t.name).join(', '),
                  subtitle: [
                    labStatusLabel(l, o.status),
                    if (o.preferredStart != null) fmtDateTime(context, o.preferredStart!),
                  ].join(' · '),
                  onTap: () => context.push('/lab/orders/${o.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabOrderScreen extends ConsumerStatefulWidget {
  const LabOrderScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<LabOrderScreen> createState() => _LabOrderScreenState();
}

class _LabOrderScreenState extends ConsumerState<LabOrderScreen> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    final l = context.l10n;
    final reason = await showDialog<String>(context: context, builder: (_) => const CancelReasonDialog());
    if (reason == null) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(labRepositoryProvider).cancel(widget.id, reason);
      ref.invalidate(labOrderProvider(widget.id));
      ref.invalidate(labOrdersProvider);
      if (mounted) showSnack(context, l.labOrderCancelled);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.labOrderTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(labOrderProvider(widget.id).future),
        child: AsyncView<LabOrder>(
          value: ref.watch(labOrderProvider(widget.id)),
          onRetry: () => ref.invalidate(labOrderProvider(widget.id)),
          data: (o) => ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              CcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(o.patientName, style: Theme.of(context).textTheme.titleSmall)),
                        StatusPill(label: labStatusLabel(l, o.status), color: labStatusColor(o.status)),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    for (final t in o.tests)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          const Icon(Icons.science_outlined, size: 16, color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          Expanded(child: Text(t.name)),
                        ]),
                      ),
                    const Divider(height: Space.xl),
                    if (o.preferredStart != null)
                      LabeledValue(label: l.sampleCollectionTime, value: fmtDateTime(context, o.preferredStart!)),
                    if (o.partnerName.isNotEmpty) LabeledValue(label: l.labPartner, value: o.partnerName),
                    if (o.discount > 0) LabeledValue(label: l.couponDiscount, value: '−${money(o.discount)}'),
                    LabeledValue(label: l.totalAmount, value: money(o.total)),
                  ],
                ),
              ),
              if (o.reportReady) ...[
                const SizedBox(height: Space.md),
                PrimaryButton(
                  key: const Key('lab-view-report'),
                  icon: Icons.picture_as_pdf_outlined,
                  label: l.viewReport,
                  onPressed: () => openPdf(context,
                      title: l.labReport,
                      fileName: 'lab-report-${o.id}.pdf',
                      load: () => ref.read(recordsRepositoryProvider).file(o.reportRecordId!)),
                ),
              ],
              if (o.collectionVisitId != null) ...[
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: () => context.push('/home-visits/${o.collectionVisitId}'),
                  icon: const Icon(Icons.home_outlined),
                  label: Text(l.trackSampleCollection),
                ),
              ],
              SectionHeader(title: l.orderStatus),
              StatusTimeline(
                steps: buildTimelineSteps(
                  flow: LabOrder.flow,
                  current: o.status,
                  reached: {for (final t in o.timeline) t.status: t.at},
                  label: (s) => labStatusLabel(l, s),
                ),
              ),
              if (o.canCancel) ...[
                const SizedBox(height: Space.lg),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  onPressed: _cancelling ? null : _cancel,
                  child: Text(l.cancelOrder),
                ),
              ],
              const SizedBox(height: Space.md),
              Text(l.labReportNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a cancellation reason; returns it (or null when dismissed).
class CancelReasonDialog extends StatefulWidget {
  const CancelReasonDialog({super.key});

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.cancelReasonTitle),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l.reason),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.notNow)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, _c.text.trim().isEmpty ? l.noReasonGiven : _c.text.trim()),
          child: Text(l.confirm),
        ),
      ],
    );
  }
}
