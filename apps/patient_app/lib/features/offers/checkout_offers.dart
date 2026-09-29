import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement_v13.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';

/// Coupon + "Use wallet balance" state of one checkout (§60). The screen
/// owns it and reads [couponCode] / [useWallet] when it calls the booking
/// endpoint; the server computes the final split on the returned `Payment`.
class CheckoutOffersController extends ChangeNotifier {
  String? _couponCode;
  int _discount = 0;
  String? _message;
  bool _messageIsError = false;
  bool _useWallet = false;
  int _walletBalance = 0;
  bool _applying = false;

  /// The validated coupon, or null.
  String? get couponCode => _couponCode;
  int get couponDiscount => _discount;
  String? get message => _message;
  bool get messageIsError => _messageIsError;
  bool get useWallet => _useWallet && _walletBalance > 0;
  int get walletBalance => _walletBalance;
  bool get applying => _applying;

  CheckoutBreakdown breakdown(int subtotal) => CheckoutBreakdown.compute(
        subtotal: subtotal,
        couponDiscount: _discount,
        walletBalance: _walletBalance,
        useWallet: useWallet,
      );

  set walletBalance(int v) {
    if (v == _walletBalance) return;
    _walletBalance = v;
    notifyListeners();
  }

  set useWallet(bool v) {
    _useWallet = v;
    notifyListeners();
  }

  void _setApplying(bool v) {
    _applying = v;
    notifyListeners();
  }

  /// Records a server validation result for [code].
  void applyResult(String code, CouponValidation r) {
    if (r.valid) {
      _couponCode = code.trim().toUpperCase();
      _discount = r.discount;
      _messageIsError = false;
    } else {
      _couponCode = null;
      _discount = 0;
      _messageIsError = true;
    }
    _message = r.message.isEmpty ? null : r.message;
    notifyListeners();
  }

  void applyError(String message) {
    _couponCode = null;
    _discount = 0;
    _message = message;
    _messageIsError = true;
    notifyListeners();
  }

  void removeCoupon() {
    _couponCode = null;
    _discount = 0;
    _message = null;
    _messageIsError = false;
    notifyListeners();
  }
}

/// Coupon field, wallet toggle and the discount / wallet / payable lines,
/// shown on every checkout (appointments, home visits, lab, pharmacy,
/// subscriptions and second opinions).
class CheckoutOffersCard extends ConsumerStatefulWidget {
  const CheckoutOffersCard({
    super.key,
    required this.controller,
    required this.purpose,
    required this.amount,
    this.showBreakdown = true,
  });
  final CheckoutOffersController controller;

  /// `Payment.purpose` the coupon must apply to.
  final String purpose;

  /// Subtotal before coupon and wallet (rupees).
  final int amount;
  final bool showBreakdown;

  @override
  ConsumerState<CheckoutOffersCard> createState() => _CheckoutOffersCardState();
}

class _CheckoutOffersCardState extends ConsumerState<CheckoutOffersCard> {
  final _code = TextEditingController();

  CheckoutOffersController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _code.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant CheckoutOffersCard old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    // The amount changed (e.g. another service): re-check the coupon.
    if (old.amount != widget.amount && _c.couponCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(_c.couponCode!));
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _code.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _apply(String code) async {
    final t = code.trim();
    if (t.isEmpty || widget.amount <= 0) return;
    FocusScope.of(context).unfocus();
    _c._setApplying(true);
    try {
      final r = await ref
          .read(offersRepositoryProvider)
          .validateCoupon(t, purpose: widget.purpose, amount: widget.amount);
      _c.applyResult(t, r);
      if (r.valid) _code.clear();
    } on ApiException catch (e) {
      if (mounted) _c.applyError(errorMessage(context, e));
    } finally {
      _c._setApplying(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!ref.watch(featureFlagsProvider).walletOffers) {
      return widget.showBreakdown
          ? CcCard(child: CheckoutBreakdownLines(breakdown: CheckoutBreakdown.compute(subtotal: widget.amount)))
          : const SizedBox.shrink();
    }
    final wallet = ref.watch(walletProvider).value;
    if (wallet != null && wallet.balance != _c.walletBalance) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.walletBalance = wallet.balance);
    }
    final b = _c.breakdown(widget.amount);
    return CcCard(
      key: const Key('checkout-offers'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: AppColors.primaryLight),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(l.offersAndWallet, style: Theme.of(context).textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: Space.md),
          if (_c.couponCode != null)
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: StatusPill(
                      key: const Key('coupon-applied'),
                      label: l.couponApplied(_c.couponCode!),
                      icon: Icons.check_circle,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('coupon-remove'),
                  onPressed: _c.removeCoupon,
                  child: Text(l.remove),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('coupon-field'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _apply,
                    decoration: InputDecoration(labelText: l.couponCode, isDense: true),
                  ),
                ),
                const SizedBox(width: Space.sm),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    key: const Key('coupon-apply'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(72, 48)),
                    onPressed: _c.applying || _code.text.trim().isEmpty ? null : () => _apply(_code.text),
                    child: _c.applying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.apply),
                  ),
                ),
              ],
            ),
          if (_c.message != null) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(_c.message!,
                  key: const Key('coupon-message'),
                  style: TextStyle(
                      fontSize: 12.5, color: _c.messageIsError ? AppColors.danger : AppColors.primaryLight)),
            ),
          ],
          if (wallet != null && wallet.balance > 0)
            SwitchListTile(
              key: const Key('use-wallet'),
              contentPadding: EdgeInsets.zero,
              value: _c.useWallet,
              onChanged: (v) => _c.useWallet = v,
              title: Text(l.useWalletBalance),
              subtitle: Text(l.walletAvailable(money(wallet.balance))),
            ),
          if (widget.showBreakdown) ...[
            const Divider(height: Space.xl),
            CheckoutBreakdownLines(breakdown: b),
          ],
        ],
      ),
    );
  }
}

/// Subtotal, coupon discount, wallet and payable lines.
class CheckoutBreakdownLines extends StatelessWidget {
  const CheckoutBreakdownLines({super.key, required this.breakdown});
  final CheckoutBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = breakdown;
    Widget line(Key key, String label, String value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            key: key,
            children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color))),
              Text(value,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 18 : 14, color: color)),
            ],
          ),
        );
    return Semantics(
      container: true,
      label: l.checkoutSummarySemantic(money(b.subtotal), money(b.discount), money(b.walletUsed), money(b.payable)),
      child: ExcludeSemantics(
        child: Column(
          children: [
            line(const Key('line-subtotal'), l.subtotal, money(b.subtotal)),
            if (b.discount > 0)
              line(const Key('line-discount'), l.couponDiscount, '−${money(b.discount)}', color: AppColors.primaryLight),
            if (b.walletUsed > 0)
              line(const Key('line-wallet'), l.walletUsedLabel, '−${money(b.walletUsed)}', color: AppColors.primaryLight),
            line(const Key('line-payable'), l.payableAmount, money(b.payable), bold: true),
            if (b.fullyCovered)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.fullyCoveredNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
              ),
          ],
        ),
      ),
    );
  }
}
