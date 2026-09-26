import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../models/care.dart';

/// Result of one Razorpay Standard Checkout attempt.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

class CheckoutSuccess extends CheckoutOutcome {
  const CheckoutSuccess({required this.paymentId, required this.orderId, required this.signature});
  final String paymentId;
  final String orderId;
  final String signature;
}

class CheckoutFailure extends CheckoutOutcome {
  const CheckoutFailure({required this.cancelled, this.message});

  /// The user closed the checkout (as opposed to a declined payment).
  final bool cancelled;
  final String? message;
}

/// Opens the gateway's checkout UI. Abstracted so widget tests can fake it.
abstract class CheckoutLauncher {
  Future<CheckoutOutcome> open(RazorpayCheckout checkout);
}

/// `razorpay_flutter` (Android/iOS only; the plugin has no web support).
class RazorpayCheckoutLauncher implements CheckoutLauncher {
  @override
  Future<CheckoutOutcome> open(RazorpayCheckout checkout) {
    final completer = Completer<CheckoutOutcome>();
    final razorpay = Razorpay();
    void done(CheckoutOutcome o) {
      if (!completer.isCompleted) completer.complete(o);
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      done(CheckoutSuccess(
        paymentId: r.paymentId ?? '',
        orderId: r.orderId ?? checkout.orderId,
        signature: r.signature ?? '',
      ));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      done(CheckoutFailure(cancelled: r.code == Razorpay.PAYMENT_CANCELLED, message: r.message));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // External wallets complete out of band; the webhook settles the payment.
      done(const CheckoutFailure(cancelled: true));
    });
    try {
      razorpay.open(checkout.toOptions());
    } catch (e) {
      done(CheckoutFailure(cancelled: false, message: '$e'));
    }
    return completer.future;
  }
}

final checkoutLauncherProvider = Provider<CheckoutLauncher>((ref) => RazorpayCheckoutLauncher());
