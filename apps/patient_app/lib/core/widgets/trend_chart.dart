import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One point of a [TrendChart]: the daily average with an optional min–max band.
class ChartPoint {
  const ChartPoint(this.x, this.y, {double? min, double? max})
      : min = min ?? y,
        max = max ?? y;
  final DateTime x;
  final double y;
  final double min;
  final double max;
}

/// A small, dependency-free line chart (CustomPainter): the average line,
/// the daily min–max band and optional dashed reference lines (thresholds).
/// The whole chart is one semantics node described by [semanticLabel].
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.semanticLabel,
    this.references = const [],
    this.height = 160,
    this.color,
  });
  final List<ChartPoint> points;
  final String semanticLabel;

  /// Horizontal reference values (e.g. program thresholds).
  final List<double> references;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final line = color ?? (context.isDark ? AppColors.darkPrimary : AppColors.primaryLight);
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: TrendPainter(
              points: points,
              references: references,
              lineColor: line,
              gridColor: context.borderColor,
              labelColor: context.textMuted,
              refColor: AppColors.danger,
            ),
          ),
        ),
      ),
    );
  }
}

class TrendPainter extends CustomPainter {
  TrendPainter({
    required this.points,
    required this.references,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.refColor,
  });
  final List<ChartPoint> points;
  final List<double> references;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color refColor;

  static const _left = 34.0;
  static const _bottom = 18.0;

  /// The y-range covering all points and references, padded by 10%.
  static (double, double) yRange(List<ChartPoint> points, List<double> refs) {
    final values = [for (final p in points) ...[p.min, p.max], ...refs];
    if (values.isEmpty) return (0, 1);
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    if (hi - lo < 1) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.1;
    return (lo - pad, hi + pad);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(_left, 4, size.width - _left - 4, size.height - _bottom - 4);
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final (lo, hi) = yRange(points, references);
    double yOf(double v) => chart.bottom - (v - lo) / (hi - lo) * chart.height;

    // Horizontal grid with labels.
    for (var i = 0; i <= 3; i++) {
      final v = lo + (hi - lo) * i / 3;
      final y = yOf(v);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _text(canvas, v.round().toString(), Offset(0, y - 7), 10);
    }
    if (points.isEmpty) return;

    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    final t0 = sorted.first.x.millisecondsSinceEpoch.toDouble();
    final t1 = sorted.last.x.millisecondsSinceEpoch.toDouble();
    double xOf(DateTime t) =>
        t1 == t0 ? chart.center.dx : chart.left + (t.millisecondsSinceEpoch - t0) / (t1 - t0) * chart.width;

    // Min–max band.
    if (sorted.length > 1) {
      final band = Path()..moveTo(xOf(sorted.first.x), yOf(sorted.first.max));
      for (final p in sorted.skip(1)) {
        band.lineTo(xOf(p.x), yOf(p.max));
      }
      for (final p in sorted.reversed) {
        band.lineTo(xOf(p.x), yOf(p.min));
      }
      band.close();
      canvas.drawPath(band, Paint()..color = lineColor.withValues(alpha: 0.14));
    }

    // Reference lines (dashed).
    final refPaint = Paint()
      ..color = refColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    for (final r in references) {
      final y = yOf(r);
      for (var x = chart.left; x < chart.right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, chart.right), y), refPaint);
      }
    }

    // Average line + dots.
    final path = Path()..moveTo(xOf(sorted.first.x), yOf(sorted.first.y));
    for (final p in sorted.skip(1)) {
      path.lineTo(xOf(p.x), yOf(p.y));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    final dot = Paint()..color = lineColor;
    for (final p in sorted) {
      canvas.drawCircle(Offset(xOf(p.x), yOf(p.y)), 2.6, dot);
    }

    // First / last date labels.
    String d(DateTime t) => '${t.day}/${t.month}';
    _text(canvas, d(sorted.first.x), Offset(chart.left, chart.bottom + 3), 10);
    if (sorted.length > 1) {
      _text(canvas, d(sorted.last.x), Offset(chart.right - 26, chart.bottom + 3), 10);
    }
  }

  void _text(Canvas canvas, String s, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: labelColor, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 40);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) =>
      old.points != points || old.references != references || old.lineColor != lineColor;
}
