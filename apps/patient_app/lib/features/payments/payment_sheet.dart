import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';
import 'checkout_launcher.dart';

/// How a payment is collected on this device.
enum PaymentMode {
  /// Dev/mock gateway: `POST /payments/:id/confirm-mock`.
  mock,

  /// Razorpay Standard Checkout (Android/iOS), verified server-side.
  razorpay,

  /// Razorpay on web: the Flutter plugin has no web support, so the user is
  /// asked to finish in the mobile app.
  webUnsupported,
}

/// Picks the payment flow. The payment's own gateway wins (it is what the
/// server created the order with); the public config is the fallback.
PaymentMode choosePaymentMode({
  required String paymentGateway,
  required String configGateway,
  required String platform,
}) {
  final gateway = paymentGateway.isNotEmpty ? paymentGateway : configGateway;
  if (gateway != 'razorpay') return PaymentMode.mock;
  return platform == 'web' ? PaymentMode.webUnsupported : PaymentMode.razorpay;
}

/// Opens the payment sheet. Returns the latest [Payment] (or null if the user
/// dismissed it before any attempt). The caller must only treat the service
/// as confirmed when `payment.succeeded` is true (FRD §19).
Future<Payment?> showPaymentSheet(
  BuildContext context, {
  required Payment payment,
  required String title,
}) {
  // A payment fully covered by a coupon / wallet succeeds immediately (§60).
  if (payment.succeeded) return Future.value(payment);
  return showModalBottomSheet<Payment>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => PaymentSheet(payment: payment, title: title),
  );
}

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.payment, required this.title});
  final Payment payment;
  final String title;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  late Payment _payment = widget.payment;
  final _action = IdempotentAction();
  bool _busy = false;
  String? _error;

  /// Razorpay: the last checkout was closed/declined (offer a retry).
  bool _checkoutFailed = false;

  /// Razorpay: checkout succeeded but the server has not settled it yet.
  bool _confirming = false;

  PaymentMode get _mode => choosePaymentMode(
        paymentGateway: _payment.gateway,
        configGateway: ref.read(publicConfigProvider).paymentGateway,
        platform: ref.read(appPlatformProvider),
      );

  Future<void> _attemptMock(bool success) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref
          .read(paymentRepositoryProvider)
          .confirmMock(_payment.id, success: success, idempotencyKey: _action.key);
      _action.complete();
      if (!mounted) return;
      setState(() => _payment = p);
      if (p.succeeded) Navigator.of(context).pop(p);
    } on ApiException catch (e) {
      // Offline: keep the key so a retry is de-duplicated server-side.
      if (!e.isOffline) _action.complete();
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payRazorpay() async {
    final repo = ref.read(paymentRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var p = _payment;
      // A failed/cancelled attempt (or a payment without an order) needs a
      // fresh checkout from the server.
      if (p.checkout == null || p.failed || _checkoutFailed) {
        p = await repo.retry(p.id);
        if (!mounted) return;
        setState(() => _payment = p);
      }
      final checkout = p.checkout;
      if (checkout == null) {
        setState(() => _error = context.l10n.paymentUnavailable);
        return;
      }
      final outcome = await ref.read(checkoutLauncherProvider).open(checkout);
      if (!mounted) return;
      switch (outcome) {
        case CheckoutSuccess():
          final verified = await repo.verify(p.id,
              razorpayPaymentId: outcome.paymentId,
              razorpayOrderId: outcome.orderId,
              razorpaySignature: outcome.signature);
          if (!mounted) return;
          setState(() {
            _payment = verified;
            _checkoutFailed = false;
            _confirming = !verified.succeeded && !verified.failed;
          });
          if (verified.succeeded) Navigator.of(context).pop(verified);
        case CheckoutFailure():
          setState(() {
            _checkoutFailed = true;
            _error = outcome.cancelled ? context.l10n.paymentCancelled : null;
          });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await ref.read(paymentRepositoryProvider).get(_payment.id);
      if (!mounted) return;
      setState(() {
        _payment = p;
        _confirming = !p.succeeded && !p.failed;
      });
      if (p.succeeded) Navigator.of(context).pop(p);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = _mode;
    final failed = _payment.failed || _checkoutFailed;
    final amount = money(_payment.amount);

    final List<Widget> actions;
    Widget note;
    switch (mode) {
      case PaymentMode.mock:
        note = _Note(icon: Icons.science_outlined, text: l.mockGatewayNote);
        actions = [
          PrimaryButton(
            key: const Key('pay-mock'),
            label: failed ? l.retryPaymentAmount(amount) : l.payAmount(amount),
            loading: _busy,
            icon: Icons.lock_outline,
            onPressed: () => _attemptMock(true),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => _attemptMock(false),
                  child: Text(l.simulateFailure),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(_payment),
                  child: Text(l.payLater),
                ),
              ),
            ],
          ),
        ];
      case PaymentMode.razorpay:
        note = _Note(icon: Icons.verified_user_outlined, text: l.razorpaySecureNote);
        actions = [
          if (_confirming)
            PrimaryButton(
              key: const Key('check-status'),
              label: l.checkPaymentStatus,
              loading: _busy,
              icon: Icons.refresh,
              onPressed: _checkStatus,
            )
          else
            PrimaryButton(
              key: const Key('pay-razorpay'),
              label: failed ? l.retryPaymentAmount(amount) : l.payAmount(amount),
              loading: _busy,
              icon: Icons.lock_outline,
              onPressed: _payRazorpay,
            ),
          const SizedBox(height: Space.sm),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(_payment),
            child: Text(l.payLater),
          ),
        ];
      case PaymentMode.webUnsupported:
        note = Container(
          key: const Key('payment-web-unsupported'),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
              color: context.mintSurface, borderRadius: BorderRadius.circular(Radii.tile)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android, color: context.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.payInMobileAppTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(l.payInMobileAppBody),
                  ],
                ),
              ),
            ],
          ),
        );
        actions = [
          PrimaryButton(
            label: l.close,
            onPressed: () => Navigator.of(context).pop(_payment),
          ),
        ];
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.payment, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            CcCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  if (_payment.discount > 0)
                    _AmountLine(
                        key: const Key('payment-discount'),
                        label: l.couponDiscount,
                        value: '−${money(_payment.discount)}'),
                  if (_payment.walletUsed > 0)
                    _AmountLine(
                        key: const Key('payment-wallet'),
                        label: l.walletUsedLabel,
                        value: '−${money(_payment.walletUsed)}'),
                  Row(
                    children: [
                      Expanded(child: Text(l.totalAmount)),
                      Text(amount, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            note,
            if (_confirming) ...[
              const SizedBox(height: Space.md),
              _Note(icon: Icons.hourglass_top, text: l.paymentConfirming),
            ],
            if (failed && mode != PaymentMode.webUnsupported) ...[
              const SizedBox(height: Space.md),
              Container(
                key: const Key('payment-failed'),
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                    color: context.roseSurface, borderRadius: BorderRadius.circular(Radii.tile)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.paymentFailedBody)),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: Space.lg),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: context.textMuted))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
          ],
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.peachFg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ),
        ],
      );
}
