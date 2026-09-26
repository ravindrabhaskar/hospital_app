import 'json.dart';

/// `Earnings` (contract §32). Money is integer rupees.
class Earnings {
  const Earnings({
    required this.from,
    required this.to,
    required this.completedServices,
    required this.grossAmount,
    required this.platformFee,
    required this.refunds,
    required this.payable,
    required this.lines,
  });

  final String from;
  final String to;
  final int completedServices;
  final num grossAmount;
  final num platformFee;
  final num refunds;
  final num payable;
  final List<EarningsLine> lines;

  factory Earnings.fromJson(Json json) => Earnings(
        from: strOr(json['from']),
        to: strOr(json['to']),
        completedServices: intOrNull(json['completedServices']) ?? 0,
        grossAmount: numOrNull(json['grossAmount']) ?? 0,
        platformFee: numOrNull(json['platformFee']) ?? 0,
        refunds: numOrNull(json['refunds']) ?? 0,
        payable: numOrNull(json['payable']) ?? 0,
        lines: jsonList(json['lines']).map(EarningsLine.fromJson).toList(),
      );
}

class EarningsLine {
  const EarningsLine({
    required this.date,
    required this.description,
    required this.refType,
    required this.refId,
    required this.amount,
    required this.platformFee,
    required this.payable,
  });

  final String date;
  final String description;

  /// appointment | home_visit
  final String refType;
  final String refId;
  final num amount;
  final num platformFee;
  final num payable;

  factory EarningsLine.fromJson(Json json) => EarningsLine(
        date: strOr(json['date']),
        description: strOr(json['description']),
        refType: strOr(json['refType']),
        refId: strOr(json['refId']),
        amount: numOrNull(json['amount']) ?? 0,
        platformFee: numOrNull(json['platformFee']) ?? 0,
        payable: numOrNull(json['payable']) ?? 0,
      );
}
