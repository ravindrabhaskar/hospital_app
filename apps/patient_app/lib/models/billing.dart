import 'json.dart';

// ---------- Invoices (§32) ----------

class InvoiceLine {
  InvoiceLine({
    required this.description,
    required this.sacCode,
    required this.amount,
    required this.taxRate,
    required this.taxAmount,
  });
  final String description;
  final String? sacCode;
  final num amount;
  final num taxRate;
  final num taxAmount;

  factory InvoiceLine.fromJson(Json j) => InvoiceLine(
        description: str(j, 'description'),
        sacCode: strOrNull(j, 'sacCode'),
        amount: dbl(j, 'amount'),
        taxRate: dbl(j, 'taxRate'),
        taxAmount: dbl(j, 'taxAmount'),
      );
}

class Invoice {
  Invoice({
    required this.number,
    required this.paymentId,
    required this.issuedAt,
    required this.billedToName,
    required this.billedToPhone,
    required this.sellerLegalName,
    required this.sellerGstin,
    required this.sellerAddress,
    required this.lines,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.refundedAmount,
    required this.currency,
  });
  final String number;
  final String paymentId;
  final DateTime issuedAt;
  final String billedToName;
  final String billedToPhone;
  final String sellerLegalName;
  final String? sellerGstin;
  final String sellerAddress;
  final List<InvoiceLine> lines;
  final num subtotal;
  final num tax;
  final num total;
  final num refundedAmount;
  final String currency;

  factory Invoice.fromJson(Json j) {
    final billed = asJson(j['billedTo']);
    final seller = asJson(j['seller']);
    return Invoice(
      number: str(j, 'number'),
      paymentId: str(j, 'paymentId'),
      issuedAt: dateOf(j, 'issuedAt'),
      billedToName: str(billed, 'name'),
      billedToPhone: str(billed, 'phone'),
      sellerLegalName: str(seller, 'legalName'),
      sellerGstin: strOrNull(seller, 'gstin'),
      sellerAddress: str(seller, 'address'),
      lines: listOf(j['lines'], InvoiceLine.fromJson),
      subtotal: dbl(j, 'subtotal'),
      tax: dbl(j, 'tax'),
      total: dbl(j, 'total'),
      refundedAmount: dbl(j, 'refundedAmount'),
      currency: str(j, 'currency', 'INR'),
    );
  }
}

/// Payment statuses for which `GET /payments/:id/invoice` exists.
const invoiceableStatuses = {'succeeded', 'refunded', 'partially_refunded'};

// ---------- Family Care Plan (§37) ----------

class Plan {
  Plan({
    required this.code,
    required this.name,
    required this.description,
    required this.priceMonthly,
    required this.priceYearly,
    required this.benefits,
    required this.maxMembers,
    required this.coordinatorIncluded,
    required this.homeVisitDiscountPct,
    required this.active,
  });
  final String code;
  final String name;
  final String description;
  final int priceMonthly;
  final int priceYearly;
  final List<String> benefits;
  final int maxMembers;
  final bool coordinatorIncluded;
  final num homeVisitDiscountPct;
  final bool active;

  factory Plan.fromJson(Json j) => Plan(
        code: str(j, 'code'),
        name: str(j, 'name'),
        description: str(j, 'description'),
        priceMonthly: intOf(j, 'priceMonthly'),
        priceYearly: intOf(j, 'priceYearly'),
        benefits: strList(j, 'benefits'),
        maxMembers: intOf(j, 'maxMembers'),
        coordinatorIncluded: boolOf(j, 'coordinatorIncluded'),
        homeVisitDiscountPct: dbl(j, 'homeVisitDiscountPct'),
        active: boolOf(j, 'active', true),
      );
}

enum Billing { monthly, yearly }

/// Pricing shown on a plan card for the selected billing period.
class PlanPricing {
  const PlanPricing({required this.price, required this.savings, required this.savingsPct});

  /// Amount charged for the period (rupees).
  final int price;

  /// Rupees saved per year versus paying monthly (0 for monthly billing).
  final int savings;

  /// Whole-percent saving versus 12 monthly payments (0 for monthly).
  final int savingsPct;

  static PlanPricing of(Plan p, Billing b) {
    if (b == Billing.monthly) return PlanPricing(price: p.priceMonthly, savings: 0, savingsPct: 0);
    final twelve = p.priceMonthly * 12;
    final saved = twelve - p.priceYearly;
    return PlanPricing(
      price: p.priceYearly,
      savings: saved > 0 ? saved : 0,
      savingsPct: saved > 0 && twelve > 0 ? (saved * 100 / twelve).round() : 0,
    );
  }
}

class Subscription {
  Subscription({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.status,
    required this.billing,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.benefits,
    required this.createdAt,
  });
  final String id;
  final String planCode;
  final String planName;
  final String status;
  final String billing;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final List<String> benefits;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  factory Subscription.fromJson(Json j) => Subscription(
        id: str(j, 'id'),
        planCode: str(j, 'planCode'),
        planName: str(j, 'planName'),
        status: str(j, 'status'),
        billing: str(j, 'billing', 'monthly'),
        currentPeriodStart: dateOrNull(j, 'currentPeriodStart'),
        currentPeriodEnd: dateOrNull(j, 'currentPeriodEnd'),
        cancelAtPeriodEnd: boolOf(j, 'cancelAtPeriodEnd'),
        benefits: strList(j, 'benefits'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}
