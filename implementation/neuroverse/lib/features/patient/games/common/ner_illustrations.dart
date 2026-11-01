import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 12 Culturally authentic North Eastern Region (NER) of India themes
enum NerItem {
  rhino,
  hornbill,
  redPanda,
  orchid,
  bamboo,
  teaLeaf,
  mountain,
  waterfall,
  craftJaapi,
  riverBoat,
  lotus,
  morningSun,
  traditionalBasket,
}

/// Metadata and styling properties for each NER theme item
extension NerItemDetails on NerItem {
  String get label {
    switch (this) {
      case NerItem.rhino:
        return 'Rhino';
      case NerItem.hornbill:
        return 'Hornbill';
      case NerItem.redPanda:
        return 'Red Panda';
      case NerItem.orchid:
        return 'Orchid';
      case NerItem.bamboo:
        return 'Bamboo';
      case NerItem.teaLeaf:
        return 'Tea';
      case NerItem.mountain:
        return 'Mountain';
      case NerItem.waterfall:
        return 'Waterfall';
      case NerItem.craftJaapi:
        return 'Jaapi';
      case NerItem.riverBoat:
        return 'Boat';
      case NerItem.lotus:
        return 'Lotus';
      case NerItem.morningSun:
        return 'Dawn Sun';
      case NerItem.traditionalBasket:
        return 'Basket';
    }
  }

  Color get primaryColor {
    switch (this) {
      case NerItem.rhino:
        return const Color(0xFF455A64); // Slate grey
      case NerItem.hornbill:
        return const Color(0xFFE65100); // Amber orange
      case NerItem.redPanda:
        return const Color(0xFFD84315); // Rust cinnamon
      case NerItem.orchid:
        return const Color(0xFF8E24AA); // Vivid violet orchid
      case NerItem.bamboo:
        return const Color(0xFF2E7D32); // Lush bamboo green
      case NerItem.teaLeaf:
        return const Color(0xFF00796B); // Assam emerald teal
      case NerItem.mountain:
        return const Color(0xFF283593); // Indigo peak
      case NerItem.waterfall:
        return const Color(0xFF00838F); // Cerulean cyan
      case NerItem.craftJaapi:
        return const Color(0xFFC2185B); // Festive crimson
      case NerItem.riverBoat:
        return const Color(0xFF5D4037); // Teak wood brown
      case NerItem.lotus:
        return const Color(0xFFD81B60); // Lotus rose pink
      case NerItem.morningSun:
        return const Color(0xFFF57F17); // Dawn gold
      case NerItem.traditionalBasket:
        return const Color(0xFFB03A2E); // Terracotta tribal red
    }
  }

  Color lightBackgroundColor(bool isDark) {
    if (isDark) {
      switch (this) {
        case NerItem.rhino:
          return const Color(0xFF1C2428);
        case NerItem.hornbill:
          return const Color(0xFF2A1F0D);
        case NerItem.redPanda:
          return const Color(0xFF2A1713);
        case NerItem.orchid:
          return const Color(0xFF251329);
        case NerItem.bamboo:
          return const Color(0xFF132616);
        case NerItem.teaLeaf:
          return const Color(0xFF0C2623);
        case NerItem.mountain:
          return const Color(0xFF141933);
        case NerItem.waterfall:
          return const Color(0xFF0C2427);
        case NerItem.craftJaapi:
          return const Color(0xFF29101B);
        case NerItem.riverBoat:
          return const Color(0xFF241B18);
        case NerItem.lotus:
          return const Color(0xFF2A101A);
        case NerItem.morningSun:
          return const Color(0xFF2A240A);
        case NerItem.traditionalBasket:
          return const Color(0xFF1E1E2E);
      }
    } else {
      switch (this) {
        case NerItem.rhino:
          return const Color(0xFFECEFF1);
        case NerItem.hornbill:
          return const Color(0xFFFFF8E1);
        case NerItem.redPanda:
          return const Color(0xFFFBE9E7);
        case NerItem.orchid:
          return const Color(0xFFF3E5F5);
        case NerItem.bamboo:
          return const Color(0xFFE8F5E9);
        case NerItem.teaLeaf:
          return const Color(0xFFE0F2F1);
        case NerItem.mountain:
          return const Color(0xFFE8EAF6);
        case NerItem.waterfall:
          return const Color(0xFFE0F7FA);
        case NerItem.craftJaapi:
          return const Color(0xFFFCE4EC);
        case NerItem.riverBoat:
          return const Color(0xFFEFEBE9);
        case NerItem.lotus:
          return const Color(0xFFFCE4EC);
        case NerItem.morningSun:
          return const Color(0xFFFFFDE7);
        case NerItem.traditionalBasket:
          return const Color(0xFFF0F3FA);
      }
    }
  }
}

/// Scalable, high-contrast, elderly-friendly NER illustration widget
class NerIllustration extends StatelessWidget {
  final NerItem item;
  final double size;
  final Color? color;
  final bool showLabel;

  const NerIllustration({
    super.key,
    required this.item,
    this.size = 48,
    this.color,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? item.primaryColor;

    final graphic = CustomPaint(
      size: Size(size, size),
      painter: _NerItemPainter(item: item, primaryColor: effectiveColor),
    );

    if (!showLabel) return graphic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        graphic,
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            fontSize: (size * 0.22).clamp(11.0, 15.0),
            fontWeight: FontWeight.w700,
            color: effectiveColor,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Specialized CustomPainter that renders clean, clear, recognizable vector art for NER symbols
class _NerItemPainter extends CustomPainter {
  final NerItem item;
  final Color primaryColor;

  _NerItemPainter({required this.item, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final fillPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.07).clamp(2.0, 4.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (item) {
      case NerItem.rhino:
        _drawRhino(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.hornbill:
        _drawHornbill(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.redPanda:
        _drawRedPanda(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.orchid:
        _drawOrchid(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.bamboo:
        _drawBamboo(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.teaLeaf:
        _drawTeaLeaf(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.mountain:
        _drawMountain(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.waterfall:
        _drawWaterfall(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.craftJaapi:
        _drawJaapi(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.riverBoat:
        _drawRiverBoat(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.lotus:
        _drawLotus(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.morningSun:
        _drawMorningSun(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
      case NerItem.traditionalBasket:
        _drawTraditionalBasket(canvas, w, h, fillPaint, strokePaint, accentPaint);
        break;
    }
  }

  // 1. One-Horned Rhino
  void _drawRhino(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Body & head shape
    final body = Path()
      ..moveTo(w * 0.20, h * 0.72)
      ..lineTo(w * 0.20, h * 0.52)
      ..cubicTo(w * 0.22, h * 0.38, w * 0.38, h * 0.35, w * 0.52, h * 0.35)
      ..lineTo(w * 0.68, h * 0.32)
      ..lineTo(w * 0.82, h * 0.44)
      ..lineTo(w * 0.88, h * 0.56)
      ..lineTo(w * 0.76, h * 0.66)
      ..lineTo(w * 0.55, h * 0.65)
      ..lineTo(w * 0.52, h * 0.78)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.42, h * 0.65)
      ..lineTo(w * 0.28, h * 0.65)
      ..lineTo(w * 0.28, h * 0.78)
      ..lineTo(w * 0.18, h * 0.78)
      ..close();
    canvas.drawPath(body, fill);

    // Horn
    final horn = Path()
      ..moveTo(w * 0.78, h * 0.42)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.85, h * 0.48)
      ..close();
    final hornPaint = Paint()
      ..color = const Color(0xFFFFA000)
      ..style = PaintingStyle.fill;
    canvas.drawPath(horn, hornPaint);

    // Ear
    final ear = Path()
      ..moveTo(w * 0.52, h * 0.36)
      ..lineTo(w * 0.56, h * 0.22)
      ..lineTo(w * 0.60, h * 0.35)
      ..close();
    canvas.drawPath(ear, fill);

    // Eye
    canvas.drawCircle(Offset(w * 0.72, h * 0.46), w * 0.035, accent);
  }

  // 2. Great Hornbill
  void _drawHornbill(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Head & neck
    final head = Path()
      ..moveTo(w * 0.25, h * 0.82)
      ..cubicTo(w * 0.28, h * 0.45, w * 0.45, h * 0.35, w * 0.60, h * 0.38)
      ..lineTo(w * 0.62, h * 0.65)
      ..lineTo(w * 0.48, h * 0.82)
      ..close();
    final darkHead = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;
    canvas.drawPath(head, darkHead);

    // Huge curved beak
    final beak = Path()
      ..moveTo(w * 0.56, h * 0.42)
      ..cubicTo(w * 0.75, h * 0.45, w * 0.88, h * 0.58, w * 0.92, h * 0.70)
      ..cubicTo(w * 0.78, h * 0.65, w * 0.65, h * 0.58, w * 0.54, h * 0.60)
      ..close();
    final beakPaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.fill;
    canvas.drawPath(beak, beakPaint);

    // Casque (horn on top of beak)
    final casque = Path()
      ..moveTo(w * 0.48, h * 0.35)
      ..lineTo(w * 0.75, h * 0.36)
      ..lineTo(w * 0.70, h * 0.46)
      ..lineTo(w * 0.50, h * 0.45)
      ..close();
    final casquePaint = Paint()
      ..color = const Color(0xFFFF6F00)
      ..style = PaintingStyle.fill;
    canvas.drawPath(casque, casquePaint);

    // Eye
    canvas.drawCircle(Offset(w * 0.48, h * 0.46), w * 0.045, accent);
    canvas.drawCircle(Offset(w * 0.48, h * 0.46), w * 0.022, Paint()..color = Colors.black);
  }

  // 3. Red Panda
  void _drawRedPanda(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Ears
    final leftEar = Path()
      ..moveTo(w * 0.22, h * 0.38)
      ..lineTo(w * 0.18, h * 0.18)
      ..lineTo(w * 0.38, h * 0.26)
      ..close();
    final rightEar = Path()
      ..moveTo(w * 0.78, h * 0.38)
      ..lineTo(w * 0.82, h * 0.18)
      ..lineTo(w * 0.62, h * 0.26)
      ..close();
    canvas.drawPath(leftEar, fill);
    canvas.drawPath(rightEar, fill);

    // Face oval
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.55), width: w * 0.66, height: h * 0.54),
      fill,
    );

    // White cheek patches
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.30, h * 0.62), width: w * 0.22, height: h * 0.22),
      accent,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.70, h * 0.62), width: w * 0.22, height: h * 0.22),
      accent,
    );

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF212121);
    canvas.drawCircle(Offset(w * 0.38, h * 0.50), w * 0.04, eyePaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.50), w * 0.04, eyePaint);

    // Muzzle & nose
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.68), width: w * 0.24, height: h * 0.16),
      accent,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.65), w * 0.035, eyePaint);
  }

  // 4. Foxtail Orchid (Kopou Phool)
  void _drawOrchid(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Arching green stem
    final stem = Path()
      ..moveTo(w * 0.25, h * 0.85)
      ..quadraticBezierTo(w * 0.35, h * 0.50, w * 0.75, h * 0.25);
    final stemPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stem, stemPaint);

    // Orchid flowers (cluster)
    void drawPetalCluster(Offset center, double radius) {
      for (int i = 0; i < 5; i++) {
        final double angle = (i * 2 * math.pi / 5) - (math.pi / 2);
        final double px = center.dx + radius * 0.7 * math.cos(angle);
        final double py = center.dy + radius * 0.7 * math.sin(angle);
        canvas.drawCircle(Offset(px, py), radius * 0.45, fill);
      }
      // Golden center
      canvas.drawCircle(center, radius * 0.32, Paint()..color = const Color(0xFFFFD54F));
    }

    drawPetalCluster(Offset(w * 0.68, h * 0.30), w * 0.18);
    drawPetalCluster(Offset(w * 0.48, h * 0.46), w * 0.20);
    drawPetalCluster(Offset(w * 0.35, h * 0.68), w * 0.17);
  }

  // 5. Bamboo Stalks
  void _drawBamboo(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // 3 Bamboo stalks
    void drawCulm(double x, double width, double y1, double y2) {
      final stalk = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, y1, x + width, y2),
        const Radius.circular(3),
      );
      canvas.drawRRect(stalk, fill);

      // Node rings
      final nodePaint = Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(x - 2, y1 + (y2 - y1) * 0.33), Offset(x + width + 2, y1 + (y2 - y1) * 0.33), nodePaint);
      canvas.drawLine(Offset(x - 2, y1 + (y2 - y1) * 0.66), Offset(x + width + 2, y1 + (y2 - y1) * 0.66), nodePaint);
    }

    drawCulm(w * 0.22, w * 0.13, h * 0.20, h * 0.85);
    drawCulm(w * 0.44, w * 0.15, h * 0.12, h * 0.88);
    drawCulm(w * 0.68, w * 0.13, h * 0.25, h * 0.85);

    // Bamboo leaves spray
    final leafPaint = Paint()
      ..color = const Color(0xFF43A047)
      ..style = PaintingStyle.fill;
    final leaf1 = Path()
      ..moveTo(w * 0.44, h * 0.35)
      ..quadraticBezierTo(w * 0.28, h * 0.32, w * 0.15, h * 0.40)
      ..quadraticBezierTo(w * 0.30, h * 0.42, w * 0.44, h * 0.38)
      ..close();
    final leaf2 = Path()
      ..moveTo(w * 0.60, h * 0.25)
      ..quadraticBezierTo(w * 0.75, h * 0.20, w * 0.90, h * 0.28)
      ..quadraticBezierTo(w * 0.75, h * 0.32, w * 0.60, h * 0.28)
      ..close();
    canvas.drawPath(leaf1, leafPaint);
    canvas.drawPath(leaf2, leafPaint);
  }

  // 6. Assam Tea Garden (Two leaves & bud)
  void _drawTeaLeaf(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Stem
    canvas.drawLine(
      Offset(w * 0.50, h * 0.85),
      Offset(w * 0.50, h * 0.48),
      Paint()
        ..color = const Color(0xFF004D40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round,
    );

    // Center young bud
    final bud = Path()
      ..moveTo(w * 0.50, h * 0.48)
      ..quadraticBezierTo(w * 0.44, h * 0.28, w * 0.50, h * 0.15)
      ..quadraticBezierTo(w * 0.56, h * 0.28, w * 0.50, h * 0.48)
      ..close();
    final budPaint = Paint()
      ..color = const Color(0xFF26A69A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(bud, budPaint);

    // Left Leaf
    final leftLeaf = Path()
      ..moveTo(w * 0.50, h * 0.52)
      ..cubicTo(w * 0.25, h * 0.45, w * 0.15, h * 0.30, w * 0.18, h * 0.20)
      ..cubicTo(w * 0.32, h * 0.25, w * 0.45, h * 0.40, w * 0.50, h * 0.52)
      ..close();
    canvas.drawPath(leftLeaf, fill);

    // Right Leaf
    final rightLeaf = Path()
      ..moveTo(w * 0.50, h * 0.52)
      ..cubicTo(w * 0.75, h * 0.45, w * 0.85, h * 0.30, w * 0.82, h * 0.20)
      ..cubicTo(w * 0.68, h * 0.25, w * 0.55, h * 0.40, w * 0.50, h * 0.52)
      ..close();
    canvas.drawPath(rightLeaf, fill);

    // Dew drop on leaf
    canvas.drawCircle(Offset(w * 0.30, h * 0.32), w * 0.045, accent);
  }

  // 7. Kanchenjunga Mountain Peaks
  void _drawMountain(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Sky sun
    canvas.drawCircle(Offset(w * 0.70, h * 0.30), w * 0.12, Paint()..color = const Color(0xFFFFCA28));

    // Large Mountain Peak
    final peak = Path()
      ..moveTo(w * 0.10, h * 0.82)
      ..lineTo(w * 0.46, h * 0.24)
      ..lineTo(w * 0.88, h * 0.82)
      ..close();
    canvas.drawPath(peak, fill);

    // Secondary smaller peak
    final smallPeak = Path()
      ..moveTo(w * 0.40, h * 0.82)
      ..lineTo(w * 0.75, h * 0.35)
      ..lineTo(w * 0.95, h * 0.82)
      ..close();
    final darkFill = Paint()
      ..color = primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawPath(smallPeak, darkFill);

    // Snowcap on main peak
    final snow = Path()
      ..moveTo(w * 0.46, h * 0.24)
      ..lineTo(w * 0.36, h * 0.42)
      ..lineTo(w * 0.43, h * 0.38)
      ..lineTo(w * 0.48, h * 0.44)
      ..lineTo(w * 0.58, h * 0.42)
      ..close();
    canvas.drawPath(snow, accent);
  }

  // 8. Meghalaya Waterfall
  void _drawWaterfall(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Rocky cliffs
    final rocks = Path()
      ..moveTo(w * 0.08, h * 0.20)
      ..lineTo(w * 0.36, h * 0.20)
      ..lineTo(w * 0.36, h * 0.82)
      ..lineTo(w * 0.08, h * 0.82)
      ..close();
    final rockRight = Path()
      ..moveTo(w * 0.64, h * 0.20)
      ..lineTo(w * 0.92, h * 0.20)
      ..lineTo(w * 0.92, h * 0.82)
      ..lineTo(w * 0.64, h * 0.82)
      ..close();
    final cliffPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rocks, cliffPaint);
    canvas.drawPath(rockRight, cliffPaint);

    // Waterfall cascade
    final cascade = Path()
      ..moveTo(w * 0.36, h * 0.22)
      ..lineTo(w * 0.64, h * 0.22)
      ..lineTo(w * 0.70, h * 0.75)
      ..lineTo(w * 0.30, h * 0.75)
      ..close();
    canvas.drawPath(cascade, fill);

    // Water streams (white foam lines)
    final foamPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w * 0.43, h * 0.24), Offset(w * 0.41, h * 0.72), foamPaint);
    canvas.drawLine(Offset(w * 0.50, h * 0.24), Offset(w * 0.50, h * 0.74), foamPaint);
    canvas.drawLine(Offset(w * 0.57, h * 0.24), Offset(w * 0.59, h * 0.72), foamPaint);

    // Pool at bottom
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.78), width: w * 0.55, height: h * 0.16),
      fill,
    );
  }

  // 9. Assamese Jaapi Sunhat
  void _drawJaapi(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    final center = Offset(w * 0.50, h * 0.50);
    final double radius = w * 0.40;

    // Outer bamboo woven cone base
    final basePaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    // Outer decorative red ring
    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;
    canvas.drawCircle(center, radius * 0.82, borderPaint);

    // Inner patterned circle
    canvas.drawCircle(center, radius * 0.45, fill);
    canvas.drawCircle(center, radius * 0.20, accent);

    // Geometric rays
    final rayPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (int i = 0; i < 6; i++) {
      final double angle = i * math.pi / 3;
      canvas.drawLine(
        Offset(center.dx + radius * 0.45 * math.cos(angle), center.dy + radius * 0.45 * math.sin(angle)),
        Offset(center.dx + radius * 0.78 * math.cos(angle), center.dy + radius * 0.78 * math.sin(angle)),
        rayPaint,
      );
    }
  }

  // 10. Brahmaputra Country Boat
  void _drawRiverBoat(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Boat hull
    final hull = Path()
      ..moveTo(w * 0.10, h * 0.52)
      ..quadraticBezierTo(w * 0.50, h * 0.78, w * 0.90, h * 0.52)
      ..lineTo(w * 0.82, h * 0.46)
      ..quadraticBezierTo(w * 0.50, h * 0.62, w * 0.18, h * 0.46)
      ..close();
    canvas.drawPath(hull, fill);

    // Canopy / shelter
    final canopy = Path()
      ..moveTo(w * 0.35, h * 0.50)
      ..quadraticBezierTo(w * 0.50, h * 0.28, w * 0.65, h * 0.50)
      ..close();
    final canopyPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(canopy, canopyPaint);

    // Oar
    final oarPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(w * 0.65, h * 0.42), Offset(w * 0.85, h * 0.74), oarPaint);

    // Water waves
    final wavePaint = Paint()
      ..color = const Color(0xFF0288D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final wave = Path()
      ..moveTo(w * 0.12, h * 0.80)
      ..quadraticBezierTo(w * 0.30, h * 0.74, w * 0.50, h * 0.80)
      ..quadraticBezierTo(w * 0.70, h * 0.86, w * 0.88, h * 0.80);
    canvas.drawPath(wave, wavePaint);
  }

  // 11. Loktak Lotus
  void _drawLotus(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Lily Pad
    final pad = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.50, h * 0.74), width: w * 0.76, height: h * 0.24));
    final padPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(pad, padPaint);

    // Center bud / petal
    final centerPetal = Path()
      ..moveTo(w * 0.50, h * 0.68)
      ..quadraticBezierTo(w * 0.42, h * 0.36, w * 0.50, h * 0.22)
      ..quadraticBezierTo(w * 0.58, h * 0.36, w * 0.50, h * 0.68)
      ..close();
    canvas.drawPath(centerPetal, fill);

    // Left petal
    final leftPetal = Path()
      ..moveTo(w * 0.50, h * 0.68)
      ..quadraticBezierTo(w * 0.30, h * 0.50, w * 0.26, h * 0.34)
      ..quadraticBezierTo(w * 0.44, h * 0.42, w * 0.50, h * 0.68)
      ..close();
    final lightPetal = Paint()
      ..color = const Color(0xFFF06292)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftPetal, lightPetal);

    // Right petal
    final rightPetal = Path()
      ..moveTo(w * 0.50, h * 0.68)
      ..quadraticBezierTo(w * 0.70, h * 0.50, w * 0.74, h * 0.34)
      ..quadraticBezierTo(w * 0.56, h * 0.42, w * 0.50, h * 0.68)
      ..close();
    canvas.drawPath(rightPetal, lightPetal);

    // Golden pistil
    canvas.drawCircle(Offset(w * 0.50, h * 0.56), w * 0.05, Paint()..color = const Color(0xFFFFD54F));
  }

  // 12. Dawning Sun over Hills
  void _drawMorningSun(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    // Sun Rays
    final rayPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final center = Offset(w * 0.50, h * 0.50);
    for (int i = 0; i < 7; i++) {
      final double angle = math.pi + (i * math.pi / 6);
      canvas.drawLine(
        Offset(center.dx + w * 0.28 * math.cos(angle), center.dy + h * 0.28 * math.sin(angle)),
        Offset(center.dx + w * 0.42 * math.cos(angle), center.dy + h * 0.42 * math.sin(angle)),
        rayPaint,
      );
    }

    // Sun Disc
    canvas.drawCircle(center, w * 0.22, fill);

    // Rolling green hills in front
    final hillLeft = Path()
      ..moveTo(w * 0.05, h * 0.85)
      ..quadraticBezierTo(w * 0.30, h * 0.55, w * 0.65, h * 0.85)
      ..close();
    final hillPaint1 = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hillLeft, hillPaint1);

    final hillRight = Path()
      ..moveTo(w * 0.35, h * 0.85)
      ..quadraticBezierTo(w * 0.70, h * 0.58, w * 0.95, h * 0.85)
      ..close();
    final hillPaint2 = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hillRight, hillPaint2);
  }

  // 13. Traditional North-Eastern Woven Cane Basket (for Memory Recall)
  void _drawTraditionalBasket(Canvas canvas, double w, double h, Paint fill, Paint stroke, Paint accent) {
    final basketBase = Path()
      ..moveTo(w * 0.28, h * 0.88)
      ..lineTo(w * 0.72, h * 0.88)
      ..cubicTo(w * 0.82, h * 0.60, w * 0.84, h * 0.35, w * 0.78, h * 0.22)
      ..lineTo(w * 0.22, h * 0.22)
      ..cubicTo(w * 0.16, h * 0.35, w * 0.18, h * 0.60, w * 0.28, h * 0.88)
      ..close();
    
    // Woven cane base
    final canePaint = Paint()
      ..color = const Color(0xFFD4AC0D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(basketBase, canePaint);

    // Subtle cane horizontal weave lines
    final weavePaint = Paint()
      ..color = const Color(0xFFB7950B).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double y = 0.28; y <= 0.84; y += 0.08) {
      canvas.drawLine(Offset(w * 0.22, h * y), Offset(w * 0.78, h * y), weavePaint);
    }

    // Ethnic woven band across the middle (red & black geometric motifs)
    final bandRect = Rect.fromLTRB(w * 0.20, h * 0.40, w * 0.80, h * 0.68);
    final bandPaint = Paint()
      ..color = const Color(0xFF922B21)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(2)), bandPaint);

    // Diamond / chevron ethnic patterns in band
    final ethnicPatternPaint = Paint()
      ..color = const Color(0xFFF9E79F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final blackYarn = Paint()
      ..color = const Color(0xFF1B2631)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 4; i++) {
      final double cx = w * (0.28 + i * 0.14);
      final diamond = Path()
        ..moveTo(cx, h * 0.43)
        ..lineTo(cx + w * 0.06, h * 0.54)
        ..lineTo(cx, h * 0.65)
        ..lineTo(cx - w * 0.06, h * 0.54)
        ..close();
      canvas.drawPath(diamond, ethnicPatternPaint);
      canvas.drawCircle(Offset(cx, h * 0.54), w * 0.02, blackYarn);
    }

    // Top woven rim
    final rimRect = Rect.fromCenter(center: Offset(w * 0.50, h * 0.22), width: w * 0.60, height: h * 0.09);
    final rimPaint = Paint()
      ..color = const Color(0xFF6E2C00)
      ..style = PaintingStyle.fill;
    canvas.drawOval(rimRect, rimPaint);

    // Decorative side woven strap / cloth overhang
    final strap = Path()
      ..moveTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.80, h * 0.24)
      ..lineTo(w * 0.84, h * 0.65)
      ..lineTo(w * 0.76, h * 0.62)
      ..close();
    final strapPaint = Paint()
      ..color = const Color(0xFFB03A2E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(strap, strapPaint);
  }

  @override
  bool shouldRepaint(covariant _NerItemPainter oldDelegate) {
    return oldDelegate.item != item || oldDelegate.primaryColor != primaryColor;
  }
}

/// Cultural motivational script badge (e.g. "Small Steps Brighter Days ❤️")
class NerScriptBadge extends StatelessWidget {
  final String text;
  final bool hasHeart;

  const NerScriptBadge({
    super.key,
    required this.text,
    this.hasHeart = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Color(0xFF2E7D32),
              height: 1.25,
            ),
            textAlign: TextAlign.right,
          ),
          if (hasHeart) ...[
            const SizedBox(width: 4),
            const Text('❤️', style: TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

/// A serene landscape banner showing misty blue-green mountains, river, and stilt cottage
class NerLandscapeBanner extends StatelessWidget {
  final double height;
  final String? overlayText;

  const NerLandscapeBanner({
    super.key,
    this.height = 70,
    this.overlayText,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEDF7F4),
          border: Border.all(color: const Color(0xFFB2DFDB).withValues(alpha: 0.6)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _NerLandscapePainter(),
              ),
            ),
            if (overlayText != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.eco_rounded, size: 20, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Text(
                        overlayText!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF1B3B36),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('❤️', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NerLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Distant soft blue-grey mountains
    final distantMountains = Path()
      ..moveTo(0, h * 0.70)
      ..lineTo(w * 0.22, h * 0.22)
      ..lineTo(w * 0.50, h * 0.65)
      ..lineTo(w * 0.75, h * 0.18)
      ..lineTo(w, h * 0.50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final distantPaint = Paint()
      ..color = const Color(0xFFB2DFDB).withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;
    canvas.drawPath(distantMountains, distantPaint);

    // Midground rolling green hills
    final midHills = Path()
      ..moveTo(0, h * 0.80)
      ..quadraticBezierTo(w * 0.28, h * 0.45, w * 0.58, h * 0.72)
      ..quadraticBezierTo(w * 0.82, h * 0.48, w, h * 0.68)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final midPaint = Paint()
      ..color = const Color(0xFF80CBC4).withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawPath(midHills, midPaint);

    // Foreground river
    final river = Path()
      ..moveTo(0, h * 0.90)
      ..quadraticBezierTo(w * 0.38, h * 0.78, w * 0.72, h * 0.90)
      ..lineTo(w, h * 0.85)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final riverPaint = Paint()
      ..color = const Color(0xFFE0F2F1)
      ..style = PaintingStyle.fill;
    canvas.drawPath(river, riverPaint);

    // Traditional stilt cottage on right bank
    final double hx = w * 0.90;
    final double hy = h * 0.62;
    final hutRoof = Path()
      ..moveTo(hx - 15, hy)
      ..lineTo(hx, hy - 12)
      ..lineTo(hx + 15, hy)
      ..close();
    final roofPaint = Paint()
      ..color = const Color(0xFF8D6E63)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hutRoof, roofPaint);

    final hutWall = Rect.fromLTRB(hx - 11, hy, hx + 11, hy + 10);
    canvas.drawRect(hutWall, Paint()..color = const Color(0xFFD7CCC8));

    // Stilt legs
    final stiltPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(hx - 8, hy + 10), Offset(hx - 8, hy + 18), stiltPaint);
    canvas.drawLine(Offset(hx + 8, hy + 10), Offset(hx + 8, hy + 18), stiltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A tactile traditional card-back widget featuring an embossed golden Jaapi/floral mandala
class NerCardBack extends StatelessWidget {
  final double size;
  const NerCardBack({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size * 0.75,
        height: size * 0.75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.5), width: 2),
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.spa_rounded,
          size: size * 0.42,
          color: const Color(0xFFFFD54F),
        ),
      ),
    );
  }
}

/// The 4 cognitive exercise types for clear, elderly-friendly game visual representation
enum GameHubVisual {
  memoryMatch,
  patternPath,
  memoryRecall,
  faceRecall,
}

/// A dedicated, high-clarity vector illustration widget for each of the 4 cognitive games,
/// pairing intuitive game mechanics visuals with authentic North-Eastern cultural touches.
class GameHubIllustration extends StatelessWidget {
  final GameHubVisual visual;
  final double size;

  const GameHubIllustration({
    super.key,
    required this.visual,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    if (visual == GameHubVisual.faceRecall) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.20),
          child: Image.asset(
            'assets/images/game_icon_face_recall.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => CustomPaint(
              size: Size(size, size),
              painter: _GameHubPainter(visual: visual),
            ),
          ),
        ),
      );
    }
    if (visual == GameHubVisual.memoryRecall) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.20),
          child: Image.asset(
            'assets/images/game_icon_object_finder.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => CustomPaint(
              size: Size(size, size),
              painter: _GameHubPainter(visual: visual),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GameHubPainter(visual: visual),
      ),
    );
  }
}

class _GameHubPainter extends CustomPainter {
  final GameHubVisual visual;
  const _GameHubPainter({required this.visual});

  @override
  void paint(Canvas canvas, Size size) {
    switch (visual) {
      case GameHubVisual.memoryMatch:
        _drawMemoryMatch(canvas, size);
        break;
      case GameHubVisual.patternPath:
        _drawPatternPath(canvas, size);
        break;
      case GameHubVisual.memoryRecall:
        _drawMemoryRecall(canvas, size);
        break;
      case GameHubVisual.faceRecall:
        _drawFaceRecall(canvas, size);
        break;
    }
  }

  // 1. Memory Match: Clear matching-pairs / cards visual with Kopou Orchid motif & golden sparkle
  void _drawMemoryMatch(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back card (tilted ~-10 degrees, peeking behind from the left)
    canvas.save();
    canvas.translate(w * 0.32, h * 0.46);
    canvas.rotate(-0.18);
    final backCardRect = Rect.fromCenter(center: Offset.zero, width: w * 0.48, height: h * 0.64);
    final backCardRRect = RRect.fromRectAndRadius(backCardRect, Radius.circular(w * 0.08));

    // Back card shadow
    canvas.drawRRect(
      backCardRRect.shift(Offset(w * 0.02, h * 0.02)),
      Paint()..color = const Color(0x20000000),
    );
    // Back card fill (Rich coral/rose)
    canvas.drawRRect(
      backCardRRect,
      Paint()..color = const Color(0xFFF06292),
    );
    // Back card border
    canvas.drawRRect(
      backCardRRect,
      Paint()
        ..color = const Color(0xFFC2185B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );
    // Back card decorative diamond/mandala
    final backDeco = Path()
      ..moveTo(0, -h * 0.16)
      ..lineTo(w * 0.12, 0)
      ..lineTo(0, h * 0.16)
      ..lineTo(-w * 0.12, 0)
      ..close();
    canvas.drawPath(
      backDeco,
      Paint()..color = const Color(0xFFFFD54F),
    );
    canvas.drawCircle(Offset.zero, w * 0.04, Paint()..color = Colors.white);
    canvas.restore();

    // Front card (upright, prominent on the right)
    canvas.save();
    canvas.translate(w * 0.58, h * 0.54);
    canvas.rotate(0.06);
    final frontCardRect = Rect.fromCenter(center: Offset.zero, width: w * 0.50, height: h * 0.66);
    final frontCardRRect = RRect.fromRectAndRadius(frontCardRect, Radius.circular(w * 0.08));

    // Front card shadow
    canvas.drawRRect(
      frontCardRRect.shift(Offset(w * 0.025, h * 0.03)),
      Paint()..color = const Color(0x30000000),
    );
    // Front card body (bright white)
    canvas.drawRRect(
      frontCardRRect,
      Paint()..color = Colors.white,
    );
    // Front card border (vibrant magenta rose)
    canvas.drawRRect(
      frontCardRRect,
      Paint()
        ..color = const Color(0xFFD81B60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );

    // Front card motif: Authentic North-East Kopou Orchid
    // Stem
    final stemPath = Path()
      ..moveTo(0, h * 0.22)
      ..quadraticBezierTo(-w * 0.05, h * 0.05, 0, -h * 0.05);
    canvas.drawPath(
      stemPath,
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..strokeCap = StrokeCap.round,
    );
    // Leaf
    final leaf = Path()
      ..moveTo(-w * 0.02, h * 0.10)
      ..quadraticBezierTo(-w * 0.15, h * 0.06, -w * 0.12, h * 0.18)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF43A047));

    // 3 Blossom Petals (Orchid cluster)
    final petalPaint = Paint()..color = const Color(0xFFE91E63);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -h * 0.12), width: w * 0.18, height: h * 0.12),
      petalPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-w * 0.08, -h * 0.05), width: w * 0.15, height: h * 0.12),
      petalPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.08, -h * 0.05), width: w * 0.15, height: h * 0.12),
      petalPaint,
    );
    // Orchid golden center
    canvas.drawCircle(Offset(0, -h * 0.07), w * 0.04, Paint()..color = const Color(0xFFFFD54F));
    canvas.restore();

    // Golden "Match" Sparkle at top right
    _drawSparkle(canvas, Offset(w * 0.85, h * 0.18), w * 0.10, const Color(0xFFFFB300));
  }

  // 2. Pattern Path: Clear path / stepping-stones visual with bamboo trail motif
  void _drawPatternPath(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Winding stone path / river trail
    final trailPath = Path()
      ..moveTo(w * 0.20, h * 0.82)
      ..cubicTo(w * 0.35, h * 0.82, w * 0.25, h * 0.50, w * 0.45, h * 0.48)
      ..cubicTo(w * 0.65, h * 0.46, w * 0.60, h * 0.20, w * 0.80, h * 0.20);

    // Soft river-trail background ribbon
    canvas.drawPath(
      trailPath,
      Paint()
        ..color = const Color(0xFFC8E6C9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.18
        ..strokeCap = StrokeCap.round,
    );

    // Meghalaya Living Root Bridge intertwined roots flanking the trail
    final rootUpper = Path()
      ..moveTo(w * 0.12, h * 0.74)
      ..cubicTo(w * 0.28, h * 0.74, w * 0.18, h * 0.44, w * 0.38, h * 0.42)
      ..cubicTo(w * 0.58, h * 0.40, w * 0.54, h * 0.14, w * 0.74, h * 0.14);
    canvas.drawPath(
      rootUpper,
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );

    final rootLower = Path()
      ..moveTo(w * 0.28, h * 0.90)
      ..cubicTo(w * 0.42, h * 0.90, w * 0.32, h * 0.56, w * 0.52, h * 0.54)
      ..cubicTo(w * 0.72, h * 0.52, w * 0.66, h * 0.26, w * 0.88, h * 0.26);
    canvas.drawPath(
      rootLower,
      Paint()
        ..color = const Color(0xFF4E342E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );

    // Root bridge vertical tendril ties connecting the boundary roots
    final tiePaint = Paint()
      ..color = const Color(0xFF3E2723).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.18, h * 0.79), Offset(w * 0.26, h * 0.87), tiePaint);
    canvas.drawLine(Offset(w * 0.36, h * 0.54), Offset(w * 0.44, h * 0.62), tiePaint);
    canvas.drawLine(Offset(w * 0.56, h * 0.36), Offset(w * 0.64, h * 0.44), tiePaint);

    // Stepping trail guide line
    final stepPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trailPath, stepPaint);

    // 4 Tactile circular Stepping Stones:
    final stones = [
      Offset(w * 0.20, h * 0.80),
      Offset(w * 0.38, h * 0.58),
      Offset(w * 0.58, h * 0.40),
      Offset(w * 0.80, h * 0.22),
    ];

    for (int i = 0; i < stones.length; i++) {
      final pos = stones[i];
      final r = w * 0.12;

      // Stone shadow
      canvas.drawCircle(pos.translate(0, h * 0.025), r, Paint()..color = const Color(0x33000000));

      // Stone body (Lush emerald green stone / Golden target stone)
      final isTarget = (i == stones.length - 1);
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = isTarget ? const Color(0xFFFFB300) : const Color(0xFF43A047),
      );

      // Stone border
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = isTarget ? const Color(0xFFFF6F00) : const Color(0xFF1B5E20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.03,
      );

      // Stone highlight
      canvas.drawCircle(
        pos.translate(-r * 0.28, -r * 0.28),
        r * 0.32,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );

      // Step indicator (Dots for steps 1-3, Star for final target step)
      if (isTarget) {
        _drawStar(canvas, pos, r * 0.55, Colors.white);
      } else {
        canvas.drawCircle(pos, r * 0.30, Paint()..color = Colors.white);
        canvas.drawCircle(pos, r * 0.16, Paint()..color = const Color(0xFF1B5E20));
      }
    }

    // Subtle Living Root Bridge / Bamboo stalk accent at bottom right
    final bamboo = Path()
      ..moveTo(w * 0.88, h * 0.95)
      ..quadraticBezierTo(w * 0.92, h * 0.65, w * 0.86, h * 0.50);
    canvas.drawPath(
      bamboo,
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeCap = StrokeCap.round,
    );
    final bLeaf = Path()
      ..moveTo(w * 0.87, h * 0.68)
      ..quadraticBezierTo(w * 0.72, h * 0.65, w * 0.70, h * 0.74)
      ..close();
    canvas.drawPath(bLeaf, Paint()..color = const Color(0xFF66BB6A));
  }


  // 4. Memory Recall: Mindful head profile recalling a luminous Jaapi memory spark
  void _drawMemoryRecall(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gentle thought/recall radiant waves (concentric arcs on top-right)
    final wavePaint = Paint()
      ..color = const Color(0xFF42A5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.60, h * 0.35), radius: w * 0.22), -1.2, 1.4, false, wavePaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.60, h * 0.35), radius: w * 0.32), -1.2, 1.4, false, wavePaint..color = const Color(0xFF90CAF9));

    // Mind profile head silhouette:
    final headPath = Path()
      ..moveTo(w * 0.20, h * 0.88)
      ..lineTo(w * 0.38, h * 0.88)
      ..quadraticBezierTo(w * 0.40, h * 0.76, w * 0.46, h * 0.72) // neck
      ..quadraticBezierTo(w * 0.54, h * 0.72, w * 0.52, h * 0.62) // chin
      ..lineTo(w * 0.46, h * 0.56) // lips
      ..lineTo(w * 0.50, h * 0.48) // nose tip
      ..quadraticBezierTo(w * 0.42, h * 0.44, w * 0.44, h * 0.34) // forehead
      ..cubicTo(w * 0.38, h * 0.16, w * 0.16, h * 0.16, w * 0.16, h * 0.42) // cranium
      ..quadraticBezierTo(w * 0.12, h * 0.65, w * 0.20, h * 0.88) // back of head
      ..close();

    // Head shadow
    canvas.drawPath(headPath.shift(Offset(w * 0.02, h * 0.02)), Paint()..color = const Color(0x22000000));
    // Head body (Calm serene cobalt blue)
    canvas.drawPath(headPath, Paint()..color = const Color(0xFF1E88E5));

    // Mind spark / lightbulb memory spark inside the mind
    final sparkCenter = Offset(w * 0.60, h * 0.34);

    // Luminous memory spark circle
    canvas.drawCircle(
      sparkCenter,
      w * 0.24,
      Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      sparkCenter,
      w * 0.17,
      Paint()..color = const Color(0xFFFFE082),
    );

    // Subtle NER cultural motif inside the spark: Golden Jaapi sunhat
    final jaapiCone = Path()
      ..moveTo(sparkCenter.dx, sparkCenter.dy - h * 0.12)
      ..lineTo(sparkCenter.dx - w * 0.12, sparkCenter.dy + h * 0.06)
      ..lineTo(sparkCenter.dx + w * 0.12, sparkCenter.dy + h * 0.06)
      ..close();
    canvas.drawPath(jaapiCone, Paint()..color = const Color(0xFFC2185B));

    final jaapiInner = Path()
      ..moveTo(sparkCenter.dx, sparkCenter.dy - h * 0.09)
      ..lineTo(sparkCenter.dx - w * 0.09, sparkCenter.dy + h * 0.04)
      ..lineTo(sparkCenter.dx + w * 0.09, sparkCenter.dy + h * 0.04)
      ..close();
    canvas.drawPath(jaapiInner, Paint()..color = const Color(0xFFFFD54F));

    // Central red peak dot
    canvas.drawCircle(sparkCenter.translate(0, -h * 0.03), w * 0.025, Paint()..color = const Color(0xFFD32F2F));

    // Radiating golden recall sparks
    _drawSparkle(canvas, sparkCenter.translate(w * 0.22, -h * 0.15), w * 0.06, const Color(0xFFFFB300));
    _drawSparkle(canvas, sparkCenter.translate(-w * 0.18, -h * 0.16), w * 0.05, const Color(0xFFFFB300));
  }

  // 5. Face Recall: Warm family photo portrait frame with loving silhouettes
  void _drawFaceRecall(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Portrait frame background
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.84, height: h * 0.88),
      const Radius.circular(12),
    );
    canvas.drawRRect(frameRect.shift(Offset(0, h * 0.03)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(frameRect, Paint()..color = const Color(0xFFD97706));

    // Inner photo canvas
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.74, height: h * 0.72),
      const Radius.circular(8),
    );
    canvas.drawRRect(innerRect, Paint()..color = const Color(0xFFFFFBEB));

    // Two smiling family silhouettes:
    final head1Center = Offset(w * 0.38, h * 0.40);
    canvas.drawCircle(head1Center, w * 0.14, Paint()..color = const Color(0xFF00796B));
    final body1Path = Path()
      ..moveTo(w * 0.16, h * 0.80)
      ..quadraticBezierTo(w * 0.38, h * 0.54, w * 0.60, h * 0.80)
      ..close();
    canvas.drawPath(body1Path, Paint()..color = const Color(0xFF00796B));

    final head2Center = Offset(w * 0.64, h * 0.46);
    canvas.drawCircle(head2Center, w * 0.11, Paint()..color = const Color(0xFFF59E0B));
    final body2Path = Path()
      ..moveTo(w * 0.46, h * 0.80)
      ..quadraticBezierTo(w * 0.64, h * 0.58, w * 0.82, h * 0.80)
      ..close();
    canvas.drawPath(body2Path, Paint()..color = const Color(0xFFF59E0B));

    // Golden memory sparkle on top
    _drawSparkle(canvas, Offset(w * 0.74, h * 0.22), w * 0.08, const Color(0xFFEF4444));
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final double angle = -math.pi / 2 + i * 4 * math.pi / 5;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GameHubPainter oldDelegate) => oldDelegate.visual != visual;
}

/// Reusable animated flowing wave landscape widget for Patient and Caregiver cards
class AnimatedNerLandscape extends StatefulWidget {
  final bool isDark;
  final Duration duration;

  const AnimatedNerLandscape({
    super.key,
    required this.isDark,
    this.duration = const Duration(seconds: 14), // slow, gentle, meditative
  });

  @override
  State<AnimatedNerLandscape> createState() => _AnimatedNerLandscapeState();
}

class _AnimatedNerLandscapeState extends State<AnimatedNerLandscape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: NerHeaderLandscapePainter(
              isDark: widget.isDark,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

/// Shared North-East India misty landscape background painter for Cards
class NerHeaderLandscapePainter extends CustomPainter {
  final bool isDark;
  final double progress;

  const NerHeaderLandscapePainter({
    required this.isDark,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Distant soft rolling green wave / hills (smooth forward flow)
    final wave1 = Path()..moveTo(0, h);
    final wave1Phase = progress * 2 * math.pi;
    for (double x = 0; x <= w; x += 6) {
      final y = h * 0.62 +
          math.sin((x / w) * 2 * math.pi + wave1Phase) * (h * 0.12) +
          math.cos((x / w) * math.pi + wave1Phase * 0.5) * (h * 0.05);
      wave1.lineTo(x, y);
    }
    wave1.lineTo(w, h);
    wave1.close();

    final paint1 = Paint()
      ..color = isDark
          ? const Color(0xFF263238).withValues(alpha: 0.38)
          : const Color(0xFFC8E6C9).withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1, paint1);

    // 2. Middle undulating green slope wave (flowing slightly counter-phase)
    final wave2 = Path()..moveTo(0, h);
    final wave2Phase = -progress * 2.4 * math.pi;
    for (double x = 0; x <= w; x += 6) {
      final y = h * 0.76 +
          math.sin((x / (w * 0.85)) * 2 * math.pi + wave2Phase) * (h * 0.09) +
          math.sin((x / w) * math.pi + wave2Phase) * (h * 0.04);
      wave2.lineTo(x, y);
    }
    wave2.lineTo(w, h);
    wave2.close();

    final paint2 = Paint()
      ..color = isDark
          ? const Color(0xFF1B2E24).withValues(alpha: 0.42)
          : const Color(0xFFA5D6A7).withValues(alpha: 0.48)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2, paint2);

    // 3. Foreground gentle undulating accent crest
    final wave3 = Path()..moveTo(0, h);
    final wave3Phase = progress * 1.8 * math.pi + math.pi / 3;
    for (double x = 0; x <= w; x += 6) {
      final y = h * 0.88 +
          math.sin((x / w) * 2 * math.pi + wave3Phase) * (h * 0.06);
      wave3.lineTo(x, y);
    }
    wave3.lineTo(w, h);
    wave3.close();

    final paint3 = Paint()
      ..color = isDark
          ? const Color(0xFF2E4C3E).withValues(alpha: 0.30)
          : const Color(0xFF81C784).withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave3, paint3);
  }

  @override
  bool shouldRepaint(covariant NerHeaderLandscapePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

