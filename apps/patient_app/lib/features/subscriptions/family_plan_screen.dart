import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/billing.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../offers/checkout_offers.dart';
import '../payments/payment_sheet.dart';

/// Profile → Family Care Plan (§37).
class FamilyPlanScreen extends ConsumerStatefulWidget {
  const FamilyPlanScreen({super.key});

  @override
  ConsumerState<FamilyPlanScreen> createState() => _FamilyPlanScreenState();
}

class _FamilyPlanScreenState extends ConsumerState<FamilyPlanScreen> {
  Billing _billing = Billing.monthly;
  String? _busyCode;
  bool _cancelling = false;
  final _action = IdempotentAction();

  Future<void> _subscribe(Plan plan) async {
    final l = context.l10n;
    // Checkout sheet: coupon + wallet before creating the subscription (§60).
    final offers = await showModalBottomSheet<CheckoutOffersController>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => PlanCheckoutSheet(plan: plan, billing: _billing),
    );
    if (offers == null || !mounted) return;
    setState(() => _busyCode = plan.code);
    try {
      final res = await ref.read(subscriptionRepositoryProvider).subscribe(plan.code, _billing,
          idempotencyKey: _action.key, couponCode: offers.couponCode, useWallet: offers.useWallet);
      _action.complete();
      if (!mounted) return;
      final paid = await showPaymentSheet(context, payment: res.payment, title: l.planPaymentTitle(plan.name));
      ref.invalidate(mySubscriptionProvider);
      if (!mounted) return;
      if (paid != null && paid.succeeded) {
        showSnack(context, l.planActivated(plan.name));
      } else {
        showSnack(context, l.paymentNotConfirmedBody);
      }
    } on ApiException catch (e) {
      if (!e.isOffline) _action.complete();
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busyCode = null);
    }
  }

  Future<void> _cancel(Subscription s) async {
    final l = context.l10n;
    final end = s.currentPeriodEnd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.cancelPlanTitle),
        content: Text(end == null ? l.cancelPlanBodyNoDate : l.cancelPlanBody(fmtDate(context, end))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.keepPlan)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.cancelAtPeriodEnd),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(subscriptionRepositoryProvider).cancel();
      ref.invalidate(mySubscriptionProvider);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sub = ref.watch(mySubscriptionProvider);
    final plans = ref.watch(subscriptionPlansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.familyCarePlan)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subscriptionPlansProvider);
          ref.invalidate(mySubscriptionProvider);
          await ref.read(mySubscriptionProvider.future);
        },
        child: AsyncView<Subscription?>(
          value: sub,
          onRetry: () => ref.invalidate(mySubscriptionProvider),
          data: (s) {
            if (s != null && s.isActive) {
              return ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  ActiveSubscriptionCard(
                    subscription: s,
                    cancelling: _cancelling,
                    onCancel: s.cancelAtPeriodEnd ? null : () => _cancel(s),
                  ),
                ],
              );
            }
            return AsyncView<List<Plan>>(
              value: plans,
              onRetry: () => ref.invalidate(subscriptionPlansProvider),
              isEmpty: (list) => list.where((p) => p.active).isEmpty,
              empty: ListView(children: [
                EmptyStateView(icon: Icons.workspace_premium_outlined, title: l.noPlansAvailable),
              ]),
              data: (list) {
                final active = list.where((p) => p.active).toList();
                final bestPct = active.fold<int>(
                    0, (a, p) => PlanPricing.of(p, Billing.yearly).savingsPct > a ? PlanPricing.of(p, Billing.yearly).savingsPct : a);
                return ListView(
                  padding: const EdgeInsets.all(Space.screen),
                  children: [
                    Text(l.familyPlanIntro, style: TextStyle(color: context.textMuted)),
                    const SizedBox(height: Space.md),
                    const CompanyCodeCard(),
                    if (s != null && s.isPending) ...[
                      const SizedBox(height: Space.md),
                      CcCard(
                        color: context.peachSurface,
                        child: Text(l.planPendingPayment(s.planName)),
                      ),
                    ],
                    const SizedBox(height: Space.lg),
                    Center(
                      child: SegmentedButton<Billing>(
                        key: const Key('billing-toggle'),
                        segments: [
                          ButtonSegment(value: Billing.monthly, label: Text(l.billingMonthly)),
                          ButtonSegment(
                            value: Billing.yearly,
                            label: Text(bestPct > 0 ? l.billingYearlySave(bestPct) : l.billingYearly),
                          ),
                        ],
                        selected: {_billing},
                        onSelectionChanged: (v) => setState(() => _billing = v.first),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    for (final p in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: PlanCard(
                          plan: p,
                          billing: _billing,
                          busy: _busyCode == p.code,
                          onSubscribe: _busyCode == null ? () => _subscribe(p) : null,
                        ),
                      ),
                    Text(l.planPrepaidNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.billing, required this.onSubscribe, this.busy = false});
  final Plan plan;
  final Billing billing;
  final VoidCallback? onSubscribe;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pricing = PlanPricing.of(plan, billing);
    final perks = <String>[
      ...plan.benefits,
      if (plan.maxMembers > 0) l.planMembers(plan.maxMembers),
      if (plan.homeVisitDiscountPct > 0) l.planHomeVisitDiscount(plan.homeVisitDiscountPct.round()),
      if (plan.coordinatorIncluded) l.planCoordinatorIncluded,
    ];
    return CcCard(
      key: Key('plan-${plan.code}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.workspace_premium_outlined, accent: Accent.peach, size: 44),
              const SizedBox(width: Space.md),
              Expanded(child: Text(plan.name, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(plan.description, style: TextStyle(color: context.textMuted)),
          ],
          const SizedBox(height: Space.md),
          Semantics(
            liveRegion: true,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: money(pricing.price),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                TextSpan(
                    text: billing == Billing.monthly ? l.perMonth : l.perYear,
                    style: TextStyle(color: context.textMuted)),
              ]),
              key: Key('plan-price-${plan.code}'),
            ),
          ),
          if (pricing.savings > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: StatusPill(
                key: Key('plan-savings-${plan.code}'),
                label: l.planYearlySavings(money(pricing.savings), pricing.savingsPct),
                icon: Icons.savings_outlined,
              ),
            ),
          const SizedBox(height: Space.md),
          for (final b in perks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(child: Text(b)),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: l.subscribeFor(money(pricing.price)),
            loading: busy,
            onPressed: onSubscribe,
          ),
        ],
      ),
    );
  }
}

class ActiveSubscriptionCard extends StatelessWidget {
  const ActiveSubscriptionCard({super.key, required this.subscription, required this.onCancel, this.cancelling = false});
  final Subscription subscription;
  final VoidCallback? onCancel;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = subscription;
    final end = s.currentPeriodEnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CcCard(
          color: context.mintSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: context.brand, size: 32),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(s.planName, style: Theme.of(context).textTheme.titleLarge)),
                  StatusPill(label: l.planActive, icon: Icons.check),
                ],
              ),
              if (s.isSponsored) ...[
                const SizedBox(height: Space.sm),
                StatusPill(
                  key: const Key('plan-sponsored'),
                  label: l.sponsoredBy(s.sponsorName!),
                  color: AppColors.skyFg,
                  icon: Icons.business_outlined,
                ),
              ],
              const SizedBox(height: Space.sm),
              Text(s.billing == 'yearly' ? l.billingYearly : l.billingMonthly,
                  style: TextStyle(color: context.textMuted)),
              if (end != null)
                Text(s.cancelAtPeriodEnd ? l.planEndsOn(fmtDate(context, end)) : l.planRenewsOn(fmtDate(context, end)),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (s.benefits.isNotEmpty) ...[
          SectionHeader(title: l.planBenefits),
          CcCard(
            child: Column(
              children: [
                for (final b in s.benefits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, size: 18, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.lg),
        if (s.cancelAtPeriodEnd)
          Text(l.planCancelScheduled, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted))
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: cancelling ? null : onCancel,
            child: Text(l.cancelAtPeriodEnd),
          ),
      ],
    );
  }
}

/// Confirms a plan purchase with coupon / wallet; pops the controller.
class PlanCheckoutSheet extends StatefulWidget {
  const PlanCheckoutSheet({super.key, required this.plan, required this.billing});
  final Plan plan;
  final Billing billing;

  @override
  State<PlanCheckoutSheet> createState() => _PlanCheckoutSheetState();
}

class _PlanCheckoutSheetState extends State<PlanCheckoutSheet> {
  final _offers = CheckoutOffersController();

  @override
  void initState() {
    super.initState();
    _offers.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final price = PlanPricing.of(widget.plan, widget.billing).price;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.planPaymentTitle(widget.plan.name), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.md),
              CheckoutOffersCard(controller: _offers, purpose: 'subscription', amount: price),
              const SizedBox(height: Space.lg),
              PrimaryButton(
                key: const Key('plan-checkout-continue'),
                label: l.payAmount(money(_offers.breakdown(price).payable)),
                onPressed: () => Navigator.pop(context, _offers),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Have a company code?" (§57): redeems a sponsored plan.
class CompanyCodeCard extends ConsumerStatefulWidget {
  const CompanyCodeCard({super.key});

  @override
  ConsumerState<CompanyCodeCard> createState() => _CompanyCodeCardState();
}

class _CompanyCodeCardState extends ConsumerState<CompanyCodeCard> {
  final _c = TextEditingController();
  bool _open = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l = context.l10n;
    final code = _c.text.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (code.length < 6) {
      setState(() => _error = l.companyCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await ref.read(subscriptionRepositoryProvider).redeem(code);
      ref.invalidate(mySubscriptionProvider);
      if (mounted) showSnack(context, l.companyPlanActivated(s.sponsorName ?? s.planName));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CcCard(
      key: const Key('company-code'),
      color: context.skySurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(children: [
                const Icon(Icons.business_outlined, color: AppColors.skyFg),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(l.haveCompanyCode, style: const TextStyle(fontWeight: FontWeight.w600))),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ]),
            ),
          ),
          if (_open) ...[
            Text(l.companyCodeHelp, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
            const SizedBox(height: Space.sm),
            TextField(
              key: const Key('company-code-field'),
              controller: _c,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.companyCode, errorText: _error),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(key: const Key('company-code-redeem'), label: l.redeem, loading: _busy, onPressed: _redeem),
          ],
        ],
      ),
    );
  }
}
