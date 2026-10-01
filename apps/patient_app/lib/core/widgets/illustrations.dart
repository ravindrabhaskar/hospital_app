import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The friendly AI assistant robot, drawn with a CustomPainter so no image
/// assets are required. Matches the reference: white head, dark visor with
/// cyan happy eyes, white body with a heart/ECG emblem.
class RobotAssistant extends StatelessWidget {
  const RobotAssistant({super.key, this.size = 120, this.semanticLabel});
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size * 1.12,
        child: CustomPaint(painter: _RobotPainter()),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  static const _navy = Color(0xFF0F1B2D);
  static const _cyan = Color(0xFF3FE0E8);
  static const _shade = Color(0xFFDCE6F0);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    // Soft shadow under robot
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.97), width: w * 0.55, height: h * 0.05),
      Paint()..color = const Color(0x22000000),
    );

    // Arms
    final armPaint = Paint()..color = Colors.white;
    final armShade = Paint()..color = _shade;
    final leftArm = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, h * 0.60, w * 0.16, h * 0.22), Radius.circular(w * 0.08));
    final rightArm = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.72, h * 0.60, w * 0.16, h * 0.22), Radius.circular(w * 0.08));
    canvas.save();
    canvas.translate(w * 0.2, h * 0.62);
    canvas.rotate(0.35);
    canvas.translate(-w * 0.2, -h * 0.62);
    canvas.drawRRect(leftArm, armShade);
    canvas.drawRRect(leftArm.deflate(1.5), armPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.13, h * 0.76, w * 0.14, h * 0.05),
            Radius.circular(w * 0.03)),
        Paint()..color = _navy);
    canvas.restore();
    canvas.save();
    canvas.translate(w * 0.8, h * 0.62);
    canvas.rotate(-0.35);
    canvas.translate(-w * 0.8, -h * 0.62);
    canvas.drawRRect(rightArm, armShade);
    canvas.drawRRect(rightArm.deflate(1.5), armPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.73, h * 0.76, w * 0.14, h * 0.05),
            Radius.circular(w * 0.03)),
        Paint()..color = _navy);
    canvas.restore();

    // Body
    final body = Rect.fromLTWH(w * 0.26, h * 0.50, w * 0.48, h * 0.44);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _shade],
        ).createShader(body),
    );

    // Heart emblem
    final c = Offset(w * 0.5, h * 0.68);
    canvas.drawCircle(c, w * 0.1, Paint()..color = _navy);
    _heart(canvas, c, w * 0.12, Paint()..color = Colors.white);
    final ecg = Path()
      ..moveTo(c.dx - w * 0.05, c.dy)
      ..lineTo(c.dx - w * 0.02, c.dy)
      ..lineTo(c.dx - w * 0.005, c.dy - w * 0.03)
      ..lineTo(c.dx + w * 0.012, c.dy + w * 0.025)
      ..lineTo(c.dx + w * 0.025, c.dy)
      ..lineTo(c.dx + w * 0.05, c.dy);
    canvas.drawPath(
        ecg,
        Paint()
          ..color = _navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014
          ..strokeCap = StrokeCap.round);

    // Ear pods
    final earPaint = Paint()..color = const Color(0xFFBFD3E6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.02, h * 0.18, w * 0.12, h * 0.2),
            Radius.circular(w * 0.06)),
        earPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.86, h * 0.18, w * 0.12, h * 0.2),
            Radius.circular(w * 0.06)),
        earPaint);

    // Head
    final head = Rect.fromLTWH(w * 0.08, h * 0.02, w * 0.84, h * 0.52);
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, Radius.circular(w * 0.3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFE6EEF6)],
        ).createShader(head),
    );

    // Visor
    final visor = Rect.fromLTWH(w * 0.18, h * 0.12, w * 0.64, h * 0.32);
    canvas.drawRRect(RRect.fromRectAndRadius(visor, Radius.circular(w * 0.18)),
        Paint()..color = _navy);
    // Visor highlight
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.14, w * 0.2, h * 0.04),
            Radius.circular(w * 0.02)),
        Paint()..color = Colors.white.withValues(alpha: 0.12));

    final eye = Paint()
      ..color = _cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    // Happy eyes (upside-down U)
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.37, h * 0.27), radius: w * 0.065),
        math.pi, math.pi, false, eye);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.63, h * 0.27), radius: w * 0.065),
        math.pi, math.pi, false, eye);
    // Smile
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.5, h * 0.3), radius: w * 0.07), 0.35,
        math.pi - 0.7, false, eye..strokeWidth = w * 0.03);
  }

  void _heart(Canvas canvas, Offset c, double size, Paint p) {
    final path = Path();
    final x = c.dx, y = c.dy - size * 0.1;
    path.moveTo(x, y + size * 0.35);
    path.cubicTo(x - size * 0.6, y - size * 0.05, x - size * 0.3, y - size * 0.45, x, y - size * 0.15);
    path.cubicTo(x + size * 0.3, y - size * 0.45, x + size * 0.6, y - size * 0.05, x, y + size * 0.35);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ECG / pulse line icon used on the raised "Ask AI" button.
class EcgIcon extends StatelessWidget {
  const EcgIcon({super.key, this.size = 28, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _EcgPainter(color)));
}

class _EcgPainter extends CustomPainter {
  _EcgPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.25, h * 0.55)
      ..lineTo(w * 0.35, h * 0.3)
      ..lineTo(w * 0.47, h * 0.85)
      ..lineTo(w * 0.6, h * 0.15)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w, h * 0.55);
    canvas.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.color != color;
}

/// Decorative illustration for the "Care for every stage of life" banner:
/// two stylised figures (elder and caregiver) with a heart, in soft tones.
class FamilyCareIllustration extends StatelessWidget {
  const FamilyCareIllustration({super.key});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(painter: _FamilyPainter(), size: Size.infinite));
}

class _FamilyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Background glow circles
    canvas.drawCircle(Offset(w * 0.55, h * 0.3), h * 0.55,
        Paint()..color = Colors.white.withValues(alpha: 0.08));
    canvas.drawCircle(Offset(w * 0.9, h * 0.9), h * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.06));

    void person(Offset headC, double r, Color skin, Color hair, Color shirt, {bool bun = false}) {
      // Shoulders
      final body = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(headC.dx, headC.dy + r * 2.4), width: r * 3.2, height: r * 2.6),
          Radius.circular(r * 1.4));
      canvas.drawRRect(body, Paint()..color = shirt);
      // Neck
      canvas.drawRect(Rect.fromCenter(center: Offset(headC.dx, headC.dy + r * 1.05), width: r * 0.7, height: r * 0.6),
          Paint()..color = skin);
      // Head
      canvas.drawCircle(headC, r, Paint()..color = skin);
      // Hair
      canvas.drawArc(Rect.fromCircle(center: headC.translate(0, -r * 0.1), radius: r * 1.02), math.pi,
          math.pi, true, Paint()..color = hair);
      if (bun) canvas.drawCircle(headC.translate(r * 0.8, -r * 0.4), r * 0.4, Paint()..color = hair);
      // Smile
      canvas.drawArc(Rect.fromCircle(center: headC.translate(0, r * 0.2), radius: r * 0.35), 0.4,
          math.pi - 0.8, false,
          Paint()
            ..color = const Color(0xFF6B3E2E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..strokeCap = StrokeCap.round);
    }

    final r = h * 0.16;
    person(Offset(w * 0.38, h * 0.36), r, const Color(0xFFE9B99A), const Color(0xFFE8E8E8),
        const Color(0xFFF3E6D6));
    person(Offset(w * 0.62, h * 0.48), r * 0.92, const Color(0xFFD9A07F), const Color(0xFF2B1B17),
        const Color(0xFFF7B7C2),
        bun: true);
    // Heart
    final hc = Offset(w * 0.9, h * 0.8);
    final hr = h * 0.1;
    final path = Path()
      ..moveTo(hc.dx, hc.dy + hr * 0.9)
      ..cubicTo(hc.dx - hr * 1.6, hc.dy - hr * 0.2, hc.dx - hr * 0.6, hc.dy - hr * 1.3, hc.dx, hc.dy - hr * 0.35)
      ..cubicTo(hc.dx + hr * 0.6, hc.dy - hr * 1.3, hc.dx + hr * 1.6, hc.dy - hr * 0.2, hc.dx, hc.dy + hr * 0.9);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft mint hills behind the home greeting.
class MintHillsBackground extends StatelessWidget {
  const MintHillsBackground({super.key});

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(
          child: CustomPaint(
              painter: _HillsPainter(dark: Theme.of(context).brightness == Brightness.dark),
              size: Size.infinite));
}

class _HillsPainter extends CustomPainter {
  _HillsPainter({this.dark = false});
  final bool dark;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    canvas.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [AppColors.darkBackground, Color(0xFF2A1420)]
                : const [Color(0xFFFFFDF5), AppColors.mint50],
          ).createShader(Offset.zero & s));
    final p1 = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.25, h * 0.6, w * 0.5, h * 0.75)
      ..quadraticBezierTo(w * 0.75, h * 0.9, w, h * 0.65)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, Paint()..color = (dark ? const Color(0xFF3A1F2C) : AppColors.mint100).withValues(alpha: 0.6));
    final p2 = Path()
      ..moveTo(0, h * 0.9)
      ..quadraticBezierTo(w * 0.35, h * 0.75, w * 0.6, h * 0.88)
      ..quadraticBezierTo(w * 0.85, h, w, h * 0.85)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2,
        Paint()..color = (dark ? const Color(0xFF4A2638) : const Color(0xFFF2D7E3)).withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) => oldDelegate.dark != dark;
}
