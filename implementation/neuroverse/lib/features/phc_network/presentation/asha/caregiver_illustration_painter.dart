import 'package:flutter/material.dart';

/// Reusable vector illustration of Elder and Caregiver
/// Extracted directly from the existing Caregiver UI (caregiver_main_screen.dart line 9274)
/// to maintain 100% visual asset consistency across NeuroVerse.
class CaregiverIllustrationPainter extends CustomPainter {
  const CaregiverIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft mint background glow/circle
    final bgPaint = Paint()
      ..color = const Color(0xFFE0F2F1).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.58, h * 0.60), width: w * 0.76, height: h * 0.65),
      bgPaint,
    );

    // Floating teal/mint heart balloons
    _drawHeart(canvas, Offset(w * 0.78, h * 0.20), w * 0.11, const Color(0xFF80CBC4));
    _drawHeart(canvas, Offset(w * 0.94, h * 0.32), w * 0.13, const Color(0xFF4DB6AC));
    _drawHeart(canvas, Offset(w * 0.60, h * 0.12), w * 0.08, const Color(0xFF81C784));
    _drawHeart(canvas, Offset(w * 0.35, h * 0.22), w * 0.07, const Color(0xFF26A69A));

    // Elderly Patient (Left)
    // Body / Cardigan (soft sage green)
    final patientBody = Path()
      ..moveTo(w * 0.22, h * 0.98)
      ..quadraticBezierTo(w * 0.24, h * 0.72, w * 0.38, h * 0.68)
      ..quadraticBezierTo(w * 0.52, h * 0.72, w * 0.54, h * 0.98)
      ..close();
    canvas.drawPath(patientBody, Paint()..color = const Color(0xFF81C784));

    // Patient Head
    final patientHeadCenter = Offset(w * 0.38, h * 0.56);
    canvas.drawCircle(patientHeadCenter, w * 0.15, Paint()..color = const Color(0xFFFFCCBC));

    // Patient Silver/Grey Hair
    final patientHair = Path()
      ..addArc(Rect.fromCircle(center: patientHeadCenter, radius: w * 0.155), -3.14, 3.14)
      ..close();
    canvas.drawPath(patientHair, Paint()..color = const Color(0xFFCFD8DC));
    // Hair bun
    canvas.drawCircle(Offset(w * 0.28, h * 0.46), w * 0.07, Paint()..color = const Color(0xFFB0BEC5));

    // Patient Glasses (Round wireframe)
    final glassPaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(w * 0.35, h * 0.56), w * 0.045, glassPaint);
    canvas.drawCircle(Offset(w * 0.44, h * 0.56), w * 0.045, glassPaint);
    canvas.drawLine(Offset(w * 0.395, h * 0.56), Offset(w * 0.405, h * 0.56), glassPaint);

    // Patient smile
    final pSmile = Path()
      ..addArc(Rect.fromCircle(center: Offset(w * 0.395, h * 0.62), radius: w * 0.03), 0.2, 2.7);
    canvas.drawPath(pSmile, glassPaint);

    // Caregiver (Right)
    // Body / Top (Assam Emerald Teal)
    final cgBody = Path()
      ..moveTo(w * 0.48, h * 0.98)
      ..quadraticBezierTo(w * 0.52, h * 0.64, w * 0.68, h * 0.62)
      ..quadraticBezierTo(w * 0.84, h * 0.66, w * 0.88, h * 0.98)
      ..close();
    canvas.drawPath(cgBody, Paint()..color = const Color(0xFF00796B));

    // Caregiver Head
    final cgHeadCenter = Offset(w * 0.68, h * 0.48);
    canvas.drawCircle(cgHeadCenter, w * 0.15, Paint()..color = const Color(0xFFFFD180));

    // Caregiver Hair (Dark brown, styled)
    final cgHair = Path()
      ..addArc(Rect.fromCircle(center: cgHeadCenter, radius: w * 0.16), -3.2, 3.4)
      ..quadraticBezierTo(w * 0.84, h * 0.58, w * 0.82, h * 0.70)
      ..lineTo(w * 0.78, h * 0.65)
      ..close();
    canvas.drawPath(cgHair, Paint()..color = const Color(0xFF3E2723));

    // Caregiver Face details
    final cgEyePaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawCircle(Offset(w * 0.64, h * 0.48), 1.5, cgEyePaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.48), 1.5, cgEyePaint);
    final cgSmile = Path()
      ..addArc(Rect.fromCircle(center: Offset(w * 0.68, h * 0.53), radius: w * 0.035), 0.2, 2.7);
    canvas.drawPath(cgSmile, Paint()..color = const Color(0xFFD84315)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // Supportive embrace arm
    final armPath = Path()
      ..moveTo(w * 0.55, h * 0.76)
      ..quadraticBezierTo(w * 0.42, h * 0.82, w * 0.35, h * 0.80);
    canvas.drawPath(
      armPath,
      Paint()
        ..color = const Color(0xFF00695C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    final w = size;
    final h = size;
    path.moveTo(center.dx, center.dy + h * 0.35);
    path.cubicTo(center.dx - w * 0.55, center.dy - h * 0.25, center.dx - w * 0.55, center.dy - h * 0.70, center.dx, center.dy - h * 0.40);
    path.cubicTo(center.dx + w * 0.55, center.dy - h * 0.70, center.dx + w * 0.55, center.dy - h * 0.25, center.dx, center.dy + h * 0.35);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
