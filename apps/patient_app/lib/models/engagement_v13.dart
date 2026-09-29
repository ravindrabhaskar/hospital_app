import 'json.dart';

// Models for API_CONTRACT v1.3 account-level features: WhatsApp (§43),
// dementia safety (§56), offers/wallet/invites (§60) and support (§61).

// ---------------------------------------------------------------- §43 WhatsApp

class WhatsappStatus {
  const WhatsappStatus({required this.optedIn, required this.phone, required this.optedInAt});
  final bool optedIn;
  final String phone;
  final DateTime? optedInAt;

  factory WhatsappStatus.fromJson(Json j) =>
      WhatsappStatus(optedIn: boolOf(j, 'optedIn'), phone: str(j, 'phone'), optedInAt: dateOrNull(j, 'optedInAt'));
}

// ---------------------------------------------------------------- §56 Safe zone

const safeZoneMinRadius = 100;
const safeZoneMaxRadius = 5000;

/// Null when the radius is acceptable, else a reason code.
String? validateSafeZoneRadius(num? meters) {
  if (meters == null) return 'missing';
  if (meters < safeZoneMinRadius) return 'too_small';
  if (meters > safeZoneMaxRadius) return 'too_large';
  return null;
}

class SafeZone {
  const SafeZone({
    required this.enabled,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    this.label,
    this.activeFrom,
    this.activeTo,
  });
  final bool enabled;
  final double? centerLat;
  final double? centerLng;
  final int radiusMeters;
  final String? label;

  /// "HH:MM" or null (always active).
  final String? activeFrom;
  final String? activeTo;

  bool get hasCenter => centerLat != null && centerLng != null;

  static const empty = SafeZone(enabled: false, centerLat: null, centerLng: null, radiusMeters: 500);

  factory SafeZone.fromJson(Json j) => SafeZone(
        enabled: boolOf(j, 'enabled'),
        centerLat: dblOrNull(j, 'centerLat'),
        centerLng: dblOrNull(j, 'centerLng'),
        radiusMeters: intOf(j, 'radiusMeters', 500),
        label: strOrNull(j, 'label'),
        activeFrom: strOrNull(j, 'activeFrom'),
        activeTo: strOrNull(j, 'activeTo'),
      );

  Json toJson() => {
        'enabled': enabled,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'radiusMeters': radiusMeters,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
        'activeFrom': ?activeFrom,
        'activeTo': ?activeTo,
      };
}

class LatestLocation {
  const LatestLocation({required this.lat, required this.lng, required this.at, required this.inside, required this.source});
  final double lat;
  final double lng;
  final DateTime? at;
  final bool inside;
  final String source;

  factory LatestLocation.fromJson(Json j) => LatestLocation(
        lat: dbl(j, 'lat'),
        lng: dbl(j, 'lng'),
        at: dateOrNull(j, 'at'),
        inside: boolOf(j, 'inside', true),
        source: str(j, 'source', 'phone'),
      );
}

class SosDevice {
  const SosDevice({required this.id, required this.deviceId, required this.model, required this.pairedAt});
  final String id;
  final String deviceId;
  final String model;
  final DateTime? pairedAt;

  factory SosDevice.fromJson(Json j) => SosDevice(
        id: str(j, 'id'),
        deviceId: str(j, 'deviceId'),
        model: str(j, 'model'),
        pairedAt: dateOrNull(j, 'pairedAt'),
      );

  Json toJson() => {'id': id, 'deviceId': deviceId, 'model': model, 'pairedAt': pairedAt?.toUtc().toIso8601String()};
}

// ---------------------------------------------------------------- §60 Offers, wallet & invites

class CouponValidation {
  const CouponValidation({required this.valid, required this.discount, required this.finalAmount, required this.message});
  final bool valid;
  final int discount;
  final int finalAmount;
  final String message;

  factory CouponValidation.fromJson(Json j) => CouponValidation(
        valid: boolOf(j, 'valid'),
        discount: intOf(j, 'discount'),
        finalAmount: intOf(j, 'finalAmount'),
        message: str(j, 'message'),
      );
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.refType,
    required this.refId,
    required this.at,
  });
  final String id;

  /// credit | debit
  final String type;
  final int amount;
  final String reason;
  final String? refType;
  final String? refId;
  final DateTime? at;

  bool get isCredit => type == 'credit';

  factory WalletTxn.fromJson(Json j) => WalletTxn(
        id: str(j, 'id'),
        type: str(j, 'type', 'credit'),
        amount: intOf(j, 'amount'),
        reason: str(j, 'reason'),
        refType: strOrNull(j, 'refType'),
        refId: strOrNull(j, 'refId'),
        at: dateOrNull(j, 'at'),
      );
}

class Wallet {
  const Wallet({required this.balance, required this.transactions});
  final int balance;
  final List<WalletTxn> transactions;

  factory Wallet.fromJson(Json j) =>
      Wallet(balance: intOf(j, 'balance'), transactions: listOf(j['transactions'], WalletTxn.fromJson));
}

class InviteInfo {
  const InviteInfo({required this.code, required this.shareText, required this.invitedCount, required this.rewardsEarned});
  final String code;
  final String shareText;
  final int invitedCount;
  final int rewardsEarned;

  factory InviteInfo.fromJson(Json j) => InviteInfo(
        code: str(j, 'code'),
        shareText: str(j, 'shareText'),
        invitedCount: intOf(j, 'invitedCount'),
        rewardsEarned: intOf(j, 'rewardsEarned'),
      );
}

/// Discount / wallet / payable lines shown on every checkout (§60). The server
/// computes the real split; this mirrors it so the user sees it before paying.
class CheckoutBreakdown {
  const CheckoutBreakdown({
    required this.subtotal,
    required this.discount,
    required this.walletUsed,
    required this.payable,
  });
  final int subtotal;
  final int discount;
  final int walletUsed;
  final int payable;

  bool get fullyCovered => subtotal > 0 && payable == 0;

  /// [couponDiscount] is capped at the subtotal; the wallet then covers as
  /// much of the remainder as the balance allows (only when [useWallet]).
  static CheckoutBreakdown compute({
    required int subtotal,
    int couponDiscount = 0,
    int walletBalance = 0,
    bool useWallet = false,
  }) {
    final sub = subtotal < 0 ? 0 : subtotal;
    final disc = couponDiscount.clamp(0, sub);
    final afterCoupon = sub - disc;
    final wallet = useWallet ? walletBalance.clamp(0, afterCoupon) : 0;
    return CheckoutBreakdown(subtotal: sub, discount: disc, walletUsed: wallet, payable: afterCoupon - wallet);
  }
}

// ---------------------------------------------------------------- §61 Support desk

const ticketCategories = ['booking', 'payment', 'refund', 'app_issue', 'clinical_concern', 'other'];

class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.ticketId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.internal,
    required this.at,
  });
  final String id;
  final String ticketId;
  final String authorName;

  /// customer | agent | system
  final String authorRole;
  final String text;
  final bool internal;
  final DateTime? at;

  bool get isMine => authorRole == 'customer';

  factory TicketMessage.fromJson(Json j) => TicketMessage(
        id: str(j, 'id'),
        ticketId: str(j, 'ticketId'),
        authorName: str(j, 'authorName'),
        authorRole: str(j, 'authorRole', 'agent'),
        text: str(j, 'text'),
        internal: boolOf(j, 'internal'),
        at: dateOrNull(j, 'at'),
      );
}

class Ticket {
  const Ticket({
    required this.id,
    required this.number,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.assignedToName,
    required this.refType,
    required this.refId,
    required this.messages,
    required this.ratingScore,
    required this.ratingComment,
    required this.slaDueAt,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String number;
  final String subject;
  final String category;

  /// open | pending_customer | resolved | closed
  final String status;
  final String priority;
  final String? assignedToName;
  final String? refType;
  final String? refId;
  final List<TicketMessage> messages;
  final int? ratingScore;
  final String? ratingComment;
  final DateTime? slaDueAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isResolved => status == 'resolved' || status == 'closed';
  bool get canRate => isResolved && ratingScore == null;

  /// Internal notes are never shown to customers (defensive client filter).
  List<TicketMessage> get visibleMessages => messages.where((m) => !m.internal).toList();

  factory Ticket.fromJson(Json j) {
    final r = j['rating'] is Map ? asJson(j['rating']) : null;
    return Ticket(
      id: str(j, 'id'),
      number: str(j, 'number'),
      subject: str(j, 'subject'),
      category: str(j, 'category', 'other'),
      status: str(j, 'status', 'open'),
      priority: str(j, 'priority', 'normal'),
      assignedToName: strOrNull(j, 'assignedToName'),
      refType: strOrNull(j, 'refType'),
      refId: strOrNull(j, 'refId'),
      messages: listOf(j['messages'], TicketMessage.fromJson),
      ratingScore: r == null ? null : intOrNull(r, 'score'),
      ratingComment: r == null ? null : strOrNull(r, 'comment'),
      slaDueAt: dateOrNull(j, 'slaDueAt'),
      createdAt: dateOrNull(j, 'createdAt'),
      updatedAt: dateOrNull(j, 'updatedAt'),
    );
  }
}
