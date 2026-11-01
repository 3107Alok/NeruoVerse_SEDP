import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';

/// Full-screen elderly-friendly navigation hint pointing directly to the "Games" bottom navigation tab.
///
/// Features (matching native NeuroVerse design language):
/// - Softly dimmed and subtly blurred background via BackdropFilter with Inverted RRect cutout.
/// - Unblurred, concentric spotlight cutout keeping the Games bottom nav button 100% sharp and glowing.
/// - Native Flutter rounded speech bubble tooltip perfectly centered above the arrow and Games tab.
/// - Localized text dynamically centered both horizontally and vertically inside the tooltip.
/// - Polished golden downward arrow with subtle gentle bounce and pulse animations.
/// - Unified vertical alignment: Tooltip -> Arrow -> Games tab all share the exact same horizontal center.
/// - 100% touch-transparent (wrapped in IgnorePointer).
class GamesNavigationHint extends StatefulWidget {
  final bool isVisible;
  final GlobalKey? targetKey;

  const GamesNavigationHint({
    super.key,
    required this.isVisible,
    this.targetKey,
  });

  @override
  State<GamesNavigationHint> createState() => _GamesNavigationHintState();
}

class _GamesNavigationHintState extends State<GamesNavigationHint>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);

    // Rebuild after first frame so targetKey's RenderBox coordinates are measured accurately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = (isDark ? Colors.black : const Color(0xFF0F1715))
        .withValues(alpha: 0.45);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          final padding = MediaQuery.of(context).padding;
          final bounceOffset = _bounceAnimation.value;
          final pulseScale = _pulseAnimation.value;

          // 1. Determine target Games tab geometry from runtime position
          double gamesCenterX;
          double gamesCenterY;
          double gamesWidth;
          double gamesHeight;
          double gamesTopY;

          final RenderBox? targetBox =
              widget.targetKey?.currentContext?.findRenderObject() as RenderBox?;
          final RenderBox? overlayBox = context.findRenderObject() as RenderBox?;

          Offset? localOffset;
          if (targetBox != null && targetBox.hasSize && targetBox.attached) {
            try {
              final globalOffset = targetBox.localToGlobal(Offset.zero);
              localOffset = (overlayBox != null && overlayBox.hasSize && overlayBox.attached)
                  ? overlayBox.globalToLocal(globalOffset)
                  : globalOffset;
            } catch (_) {
              localOffset = null;
            }
          }

          if (localOffset != null &&
              targetBox != null &&
              targetBox.hasSize &&
              targetBox.size.width > 0 &&
              targetBox.size.height > 0) {
            // Anchor directly to the actual Games navigation item at runtime
            gamesWidth = targetBox.size.width;
            gamesHeight = targetBox.size.height;
            gamesCenterX = localOffset.dx + (gamesWidth / 2.0);
            gamesCenterY = localOffset.dy + (gamesHeight / 2.0);
            gamesTopY = localOffset.dy;
          } else {
            // Responsive fallback when targetKey is not supplied or not yet laid out
            final itemWidth = (size.width - 48.0) / 4.0;
            gamesWidth = math.min(itemWidth - 4.0, 74.0);
            gamesHeight = 52.0;
            gamesCenterX = (1.5 * itemWidth).clamp(gamesWidth / 2.0, size.width - (gamesWidth / 2.0));
            const bottomBarHeight = 65.0;
            final bottomEdge = size.height - padding.bottom;
            gamesCenterY = bottomEdge - (bottomBarHeight / 2.0);
            gamesTopY = bottomEdge - bottomBarHeight + ((bottomBarHeight - gamesHeight) / 2.0);
          }

          // Concentric cutout hole around the Games tab with comfortable padding
          final holeRect = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(gamesCenterX, gamesCenterY),
              width: gamesWidth + 8.0,
              height: gamesHeight + 6.0,
            ),
            const Radius.circular(18),
          );

          // 2. Downward Arrow geometry (proportional and centered)
          const arrowWidth = 32.0;
          const arrowHeight = 34.0;
          const arrowGapAboveTab = 6.0;
          final arrowBaseY = gamesTopY - arrowGapAboveTab - arrowHeight;

          // 3. Tooltip Speech Bubble geometry (centered and compact)
          final tooltipWidth = (size.width - 24.0).clamp(180.0, 240.0);
          const tooltipTailHeight = 7.0;
          const tooltipBodyHeight = 46.0;
          const tooltipTotalHeight = tooltipBodyHeight + tooltipTailHeight;
          const gapBetweenTooltipAndArrow = 6.0;

          final tooltipBottomY = arrowBaseY - gapBetweenTooltipAndArrow;
          final tooltipTopY = tooltipBottomY - tooltipTotalHeight;

          // Keep tooltip centered on gamesCenterX while respecting screen margins
          final idealTooltipLeft = gamesCenterX - (tooltipWidth / 2.0);
          final maxTooltipLeft = math.max(12.0, size.width - tooltipWidth - 12.0);
          final tooltipLeft = idealTooltipLeft.clamp(12.0, maxTooltipLeft);

          // Point tail directly at gamesCenterX
          final idealTailCenterX = gamesCenterX - tooltipLeft;
          final tailCenterX = idealTailCenterX.clamp(16.0, tooltipWidth - 16.0);

          return SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Full-screen dimmed and subtly blurred background with spotlight cutout
                Positioned.fill(
                  child: ClipPath(
                    clipper: _InvertedRRectClipper(holeRect),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                      child: Container(
                        color: overlayColor,
                      ),
                    ),
                  ),
                ),

                // 2. Soft, natural golden glow around the cutout hole
                Positioned.fill(
                  child: CustomPaint(
                    size: size,
                    painter: _SpotlightGlowPainter(holeRect: holeRect),
                  ),
                ),

                // 3. Native Rounded Tooltip Speech Bubble with centered localized text
                Positioned(
                  left: tooltipLeft,
                  top: tooltipTopY,
                  child: SizedBox(
                    width: tooltipWidth,
                    height: tooltipTotalHeight,
                    child: CustomPaint(
                      painter: _SpeechBubblePainter(
                        tailCenterX: tailCenterX,
                        tailWidth: 14.0,
                        tailHeight: tooltipTailHeight,
                        cornerRadius: 16.0,
                        borderColor: const Color(0xFF00796B),
                        borderWidth: 1.8,
                        fillColor: Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: tooltipTailHeight,
                          left: 12.0,
                          right: 12.0,
                        ),
                        child: Center(
                          child: DefaultTextStyle(
                            style: const TextStyle(
                              decoration: TextDecoration.none,
                              color: Color(0xFF004D40),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.22,
                              letterSpacing: -0.15,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.eco_rounded,
                                  size: 15,
                                  color: Color(0xFF4DB6AC),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    context.tr('hint_tap_games'),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Animated Downward Golden Arrow with gentle bounce & pulse
                Positioned(
                  left: gamesCenterX - (arrowWidth / 2.0),
                  top: arrowBaseY + bounceOffset,
                  child: Transform.scale(
                    scale: pulseScale,
                    child: SizedBox(
                      width: arrowWidth,
                      height: arrowHeight,
                      child: CustomPaint(
                        painter: _DownwardArrowPainter(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Custom clipper that clips everything EXCEPT the rounded rectangle hole
class _InvertedRRectClipper extends CustomClipper<Path> {
  final RRect holeRect;

  _InvertedRRectClipper(this.holeRect);

  @override
  Path getClip(Size size) {
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRRect(holeRect);
    return Path.combine(PathOperation.difference, fullScreenPath, holePath);
  }

  @override
  bool shouldReclip(covariant _InvertedRRectClipper oldClipper) {
    return oldClipper.holeRect != holeRect;
  }
}

/// Custom painter for the soft, natural golden spotlight glow around the cutout hole
class _SpotlightGlowPainter extends CustomPainter {
  final RRect holeRect;

  _SpotlightGlowPainter({required this.holeRect});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(holeRect, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightGlowPainter oldDelegate) {
    return oldDelegate.holeRect != holeRect;
  }
}

/// Custom painter for drawing a seamless speech bubble with a downward pointing triangular tail
class _SpeechBubblePainter extends CustomPainter {
  final double tailCenterX;
  final double tailWidth;
  final double tailHeight;
  final double cornerRadius;
  final Color borderColor;
  final double borderWidth;
  final Color fillColor;

  _SpeechBubblePainter({
    required this.tailCenterX,
    required this.tailWidth,
    required this.tailHeight,
    required this.cornerRadius,
    required this.borderColor,
    required this.borderWidth,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bodyH = size.height - tailHeight;
    final r = cornerRadius;
    final tHalf = tailWidth / 2.0;
    final tc = tailCenterX;

    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));
    path.lineTo(w, bodyH - r);
    path.arcToPoint(Offset(w - r, bodyH), radius: Radius.circular(r));
    path.lineTo(tc + tHalf, bodyH);
    path.lineTo(tc, size.height);
    path.lineTo(tc - tHalf, bodyH);
    path.lineTo(r, bodyH);
    path.arcToPoint(Offset(0, bodyH - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.close();

    // 1. Soft natural elevation shadow
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.12),
      8.0,
      true,
    );

    // 2. Solid fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Teal border stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter oldDelegate) {
    return oldDelegate.tailCenterX != tailCenterX ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.fillColor != fillColor;
  }
}

/// Custom painter for drawing a polished, friendly golden downward arrow
class _DownwardArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2.0;

    final path = Path();
    const shaftHalfWidth = 6.0;
    const shaftTop = 0.0;
    final shaftBottom = h * 0.46;
    final wingWidth = w * 0.46;

    // Build smooth arrow path with rounded corners
    path.moveTo(cx - shaftHalfWidth, shaftTop + 3.0);
    path.quadraticBezierTo(cx - shaftHalfWidth, shaftTop, cx, shaftTop);
    path.quadraticBezierTo(cx + shaftHalfWidth, shaftTop, cx + shaftHalfWidth, shaftTop + 3.0);
    path.lineTo(cx + shaftHalfWidth, shaftBottom);
    // Right wing
    path.lineTo(cx + wingWidth - 1.5, shaftBottom);
    path.quadraticBezierTo(cx + wingWidth, shaftBottom, cx + wingWidth - 0.5, shaftBottom + 2.5);
    // Right slope down to tip
    path.lineTo(cx + 2.0, h - 2.0);
    // Rounded bottom tip
    path.quadraticBezierTo(cx, h, cx - 2.0, h - 2.0);
    // Left slope up to left wing
    path.lineTo(cx - wingWidth + 0.5, shaftBottom + 2.5);
    path.quadraticBezierTo(cx - wingWidth, shaftBottom, cx - wingWidth + 1.5, shaftBottom);
    // Left wing into shaft
    path.lineTo(cx - shaftHalfWidth, shaftBottom);
    path.close();

    // 1. Soft natural warm glow
    canvas.drawShadow(
      path,
      const Color(0xFFFFB300).withValues(alpha: 0.50),
      6.0,
      false,
    );

    // 2. Warm golden amber gradient fill
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFE082),
          Color(0xFFFFB300),
          Color(0xFFFFA000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Crisp warm outline highlight
    final strokePaint = Paint()
      ..color = const Color(0xFFFFFDE7).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
