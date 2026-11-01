import 'package:flutter/material.dart';

/// Decorative painter rendering Assam tea leaves, healthcare crosses, and subtle ECG pulse lines.
/// Used across Doctor Home, Profile, Schedule Drive, and Clinical Report dialogs.
class DoctorHealthcareDecorPainter extends CustomPainter {
  final bool isDark;
  final Color? leafColor;
  final Color? crossColor;
  final Color? pulseColor;

  DoctorHealthcareDecorPainter({
    required this.isDark,
    this.leafColor,
    this.crossColor,
    this.pulseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final effectiveLeafColor = leafColor ??
        (isDark ? const Color(0xFF2E7D32).withValues(alpha: 0.18) : const Color(0xFF4CAF50).withValues(alpha: 0.16));
    final effectiveCrossColor = crossColor ??
        (isDark ? const Color(0xFF80CBC4).withValues(alpha: 0.16) : const Color(0xFF00796B).withValues(alpha: 0.14));
    final effectivePulseColor = pulseColor ??
        (isDark ? const Color(0xFF4DB6AC).withValues(alpha: 0.22) : const Color(0xFF004D40).withValues(alpha: 0.18));

    // 1. Organic Assam Tea Leaves (Top right corner)
    final leafPaint = Paint()
      ..color = effectiveLeafColor
      ..style = PaintingStyle.fill;

    // Leaf 1
    final leaf1 = Path()
      ..moveTo(w * 0.85, h * 0.08)
      ..quadraticBezierTo(w * 0.96, h * 0.03, w * 0.98, h * 0.18)
      ..quadraticBezierTo(w * 0.88, h * 0.19, w * 0.85, h * 0.08)
      ..close();
    canvas.drawPath(leaf1, leafPaint);

    // Leaf 2
    final leaf2 = Path()
      ..moveTo(w * 0.91, h * 0.15)
      ..quadraticBezierTo(w * 0.99, h * 0.18, w * 0.97, h * 0.28)
      ..quadraticBezierTo(w * 0.89, h * 0.25, w * 0.91, h * 0.15)
      ..close();
    canvas.drawPath(leaf2, leafPaint);

    // Leaf 3 (Bottom left corner)
    final leaf3 = Path()
      ..moveTo(w * 0.08, h * 0.78)
      ..quadraticBezierTo(w * 0.02, h * 0.86, w * 0.05, h * 0.96)
      ..quadraticBezierTo(w * 0.14, h * 0.90, w * 0.08, h * 0.78)
      ..close();
    canvas.drawPath(leaf3, leafPaint);

    // 2. Medical Crosses (+)
    _drawMedicalCross(canvas, Offset(w * 0.38, h * 0.22), 12, effectiveCrossColor);
    _drawMedicalCross(canvas, Offset(w * 0.74, h * 0.78), 10, effectiveCrossColor);

    // 3. Subtle ECG Pulse Wave
    final pulsePaint = Paint()
      ..color = effectivePulseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final pulsePath = Path()
      ..moveTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.60, h * 0.90)
      ..lineTo(w * 0.63, h * 0.84)
      ..lineTo(w * 0.66, h * 0.95)
      ..lineTo(w * 0.69, h * 0.81)
      ..lineTo(w * 0.72, h * 0.92)
      ..lineTo(w * 0.75, h * 0.90)
      ..lineTo(w * 0.84, h * 0.90);
    canvas.drawPath(pulsePath, pulsePaint);
  }

  void _drawMedicalCross(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final thick = size / 3;

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size, height: thick),
        Radius.circular(thick / 2),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: thick, height: size),
        Radius.circular(thick / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DoctorHealthcareDecorPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.leafColor != leafColor ||
      oldDelegate.crossColor != crossColor ||
      oldDelegate.pulseColor != pulseColor;
}
