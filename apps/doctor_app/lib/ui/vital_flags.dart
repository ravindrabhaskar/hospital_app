import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'l10n_helpers.dart';

/// Out-of-range flag for one vital reading.
enum VitalFlag { low, high }

/// Adult resting reference ranges used to highlight readings for review.
/// These are display cues only, not clinical decision rules: a reading
/// below [low] is flagged Low, at or above [high] is flagged High.
class VitalRange {
  const VitalRange({this.low, this.high});
  final num? low;
  final num? high;
}

/// The reference range for [type] in [unit], or null when there is none
/// (e.g. weight).
VitalRange? vitalRange(String type, {String unit = ''}) {
  final u = unit.toLowerCase();
  return switch (type) {
    'bp_systolic' => const VitalRange(low: 90, high: 140),
    'bp_diastolic' => const VitalRange(low: 60, high: 90),
    'pulse' => const VitalRange(low: 60, high: 101),
    'spo2' => const VitalRange(low: 95),
    'respiratory_rate' => const VitalRange(low: 12, high: 21),
    'temperature' when u.contains('f') => const VitalRange(low: 95, high: 100.4),
    'temperature' => const VitalRange(low: 35, high: 38),
    'blood_glucose' when u.contains('mmol') => const VitalRange(low: 3.9, high: 10),
    'blood_glucose' => const VitalRange(low: 70, high: 180),
    _ => null,
  };
}

/// Low / High / null (in range or no range). Temperatures without a unit are
/// read as Fahrenheit when above 50.
VitalFlag? vitalFlag(String type, num value, {String unit = ''}) {
  var u = unit;
  if (type == 'temperature' && !u.toLowerCase().contains(RegExp('[cf]'))) u = value > 50 ? '°F' : '°C';
  final r = vitalRange(type, unit: u);
  if (r == null) return null;
  if (r.low != null && value < r.low!) return VitalFlag.low;
  if (r.high != null && value >= r.high!) return VitalFlag.high;
  return null;
}

/// Red "↑ High" / "↓ Low" pill shown next to an out-of-range value.
class VitalFlagBadge extends StatelessWidget {
  const VitalFlagBadge({super.key, required this.flag});
  final VitalFlag flag;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final high = flag == VitalFlag.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(high ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: AppColors.dangerDeep),
          const SizedBox(width: 2),
          Text(
            high ? l.vitalHigh : l.vitalLow,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.dangerDeep),
          ),
        ],
      ),
    );
  }
}

String vitalFlagLabel(BuildContext context, VitalFlag flag) =>
    flag == VitalFlag.high ? context.l10n.vitalHigh : context.l10n.vitalLow;
