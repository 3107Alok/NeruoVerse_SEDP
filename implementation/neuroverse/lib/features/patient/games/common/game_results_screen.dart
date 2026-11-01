import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/localization/app_translations.dart';

class GameResultsScreen extends StatefulWidget {
  final int totalChallenges;
  final int completedChallenges;
  final double accuracy;
  final Widget nextLevelWidget;
  final int? currentLevel;
  final int? nextLevel;
  final String? gameId;
  final String? audioKey;
  final String? patientId;
  final String? patientName;

  const GameResultsScreen({
    super.key,
    required this.totalChallenges,
    required this.completedChallenges,
    required this.accuracy,
    required this.nextLevelWidget,
    this.currentLevel,
    this.nextLevel,
    this.gameId,
    this.audioKey,
    this.patientId,
    this.patientName,
  });

  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double length;
  final double width;
  final Color color;
  final double flipSpeed;
  final double swaySpeed;
  final double swayMagnitude;
  final double gravity;
  final double delay;
  final bool isCircle;

  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.length,
    required this.width,
    required this.color,
    required this.flipSpeed,
    required this.swaySpeed,
    required this.swayMagnitude,
    required this.gravity,
    required this.delay,
    required this.isCircle,
  });
}

class _GameResultsScreenState extends State<GameResultsScreen> with TickerProviderStateMixin {
  late AnimationController _trophyController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  late AnimationController _confettiController;
  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _trophyController, curve: Curves.easeInOut),
    );

    // Confetti party popper animation controller
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _initConfettiParticles();

    // Trigger animations in sequence
    _trophyController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _confettiController.forward(from: 0.0);
      }
    });

    // Speak victory announcement with pre-recorded neural voice
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _speakResultVoice();
      }
    });
  }

  void _speakResultVoice() {
    try {
      AppProvider? appProvider;
      VoiceService? voice;
      try {
        appProvider = context.read<AppProvider>();
      } catch (_) {}
      try {
        voice = context.read<VoiceService>();
      } catch (_) {}

      if (voice == null) return;

      final lang = appProvider?.voiceLanguage ?? appProvider?.userLanguage ?? 'hi';
      final cleanLang = AppTranslations.normalizeLangCode(lang);

      String audioKey = widget.audioKey ?? '';
      if (audioKey.isEmpty && widget.gameId != null) {
        final gId = widget.gameId!.toLowerCase();
        if (gId.contains('match')) {
          audioKey = 'match_win';
        } else if (gId.contains('pattern')) {
          audioKey = 'pattern_win';
        } else if (gId.contains('face')) {
          audioKey = 'face_win';
        } else {
          audioKey = 'talk_praise';
        }
      }
      if (audioKey.isEmpty) {
        audioKey = 'match_win';
      }

      final fallbackText = AppTranslations.get(cleanLang, 'great_work');
      voice.speakKey(
        audioKey,
        lang: lang,
        fallbackText: fallbackText,
      );
    } catch (e) {
      debugPrint("GameResultsScreen: Error playing victory voice: $e");
    }
  }

  void _initConfettiParticles() {
    final random = Random(42);
    final colors = [
      const Color(0xFF00796B), // Emerald
      const Color(0xFF26A69A), // Teal
      const Color(0xFFFFB300), // Gold
      const Color(0xFFFF7043), // Tangerine
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Violet
      const Color(0xFF29B6F6), // Sky Blue
      const Color(0xFF66BB6A), // Green
      const Color(0xFFFFCA28), // Bright Yellow
      const Color(0xFFFF5252), // Coral
    ];

    _particles = List.generate(80, (i) {
      final angle = -pi * 0.96 + (random.nextDouble() * pi * 0.92);
      final speed = 1.0 + random.nextDouble() * 2.2;
      final isCircle = random.nextDouble() < 0.22;
      final length = isCircle ? 6.0 : (10.0 + random.nextDouble() * 12.0);
      final width = isCircle ? 6.0 : (3.5 + random.nextDouble() * 3.0);
      final color = colors[random.nextInt(colors.length)];
      final flipSpeed = 2.0 + random.nextDouble() * 5.0;
      final swaySpeed = 1.5 + random.nextDouble() * 3.0;
      final swayMagnitude = 16.0 + random.nextDouble() * 32.0;
      final gravity = 1.2 + random.nextDouble() * 1.5;
      final delay = random.nextDouble() * 0.16;

      return _ConfettiParticle(
        angle: angle,
        speed: speed,
        length: length,
        width: width,
        color: color,
        flipSpeed: flipSpeed,
        swaySpeed: swaySpeed,
        swayMagnitude: swayMagnitude,
        gravity: gravity,
        delay: delay,
        isCircle: isCircle,
      );
    });
  }

  void _triggerPartyPopper() {
    _confettiController.reset();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  double get _normalizedAccuracy {
    if (widget.accuracy > 1.0) {
      return (widget.accuracy / 100.0).clamp(0.0, 1.0);
    }
    return widget.accuracy.clamp(0.0, 1.0);
  }

  String _getPerformanceRating(BuildContext context, double acc) {
    if (acc >= 0.85) return context.tr('rating_excellent');
    if (acc >= 0.65) return context.tr('rating_good');
    if (acc >= 0.40) return context.tr('rating_well_played');
    return context.tr('rating_keep_practicing');
  }

  String _cleanRatingText(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'^[⭐💪\s]+|[!⭐💪\s]+$'), '').trim();
    return '$cleaned!';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLevelUp = widget.nextLevel != null && widget.currentLevel != null && widget.nextLevel! > widget.currentLevel!;
    final isCalibrated = widget.nextLevel != null && widget.currentLevel != null && widget.nextLevel! < widget.currentLevel!;

    final levelTitle = isLevelUp
        ? context.tr('level_up')
        : (isCalibrated ? context.tr('level_down') : context.tr('same_level'));

    final bgColor = isDark ? const Color(0xFF0F1716) : const Color(0xFFF7FBF9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          context.tr('game_summary'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF142926),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF142926),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // -------------------------------------------------------------
      // PINNED BOTTOM ACTION BUTTONS (Clean spacing at bottom)
      // -------------------------------------------------------------
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          children: [
            // Back to Home
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded, size: 20, color: Color(0xFF00796B)),
                  label: Text(
                    context.tr('back_to_home'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1F3D37),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF162321) : Colors.white,
                    side: BorderSide(
                      color: isDark ? const Color(0xFF283F3B) : const Color(0xFFD4DFDB),
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Next Level
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => widget.nextLevelWidget),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.tr('play_next'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // -------------------------------------------------------------
          // DECORATIVE BACKGROUND ACCENTS (Subtle, without top text watermarks)
          // -------------------------------------------------------------
          // Subtle Brain Line Art Doodle (Top Right)
          Positioned(
            right: 28,
            top: 4,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.16 : 0.22,
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  size: 38,
                  color: Color(0xFF00796B),
                ),
              ),
            ),
          ),
          // Subtle Stars & Sparkles
          Positioned(
            left: 36,
            top: 70,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.25 : 0.45,
                child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
              ),
            ),
          ),
          Positioned(
            right: 38,
            top: 90,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.25 : 0.45,
                child: const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFB300)),
              ),
            ),
          ),

          // -------------------------------------------------------------
          // SCROLLABLE MAIN CONTENT (Balanced Spacing)
          // -------------------------------------------------------------
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. CELEBRATORY TROPHY & SUNBURST GLOW
                  Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: GestureDetector(
                        onTap: _triggerPartyPopper,
                        child: SizedBox(
                          width: 250,
                          height: 155,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Soft background sunburst glow circle
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      width: 145,
                                      height: 145,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? const Color(0xFF2E2614)
                                            : const Color(0xFFFFF7DB),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withValues(alpha: isDark ? 0.18 : 0.25),
                                            blurRadius: 32,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Exact user trophy illustration with leaves & confetti
                              Image.asset(
                                'assets/images/game_trophy_celebration.png',
                                width: 240,
                                height: 140,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Container(
                                  width: 86,
                                  height: 86,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFFFD54F), Color(0xFFFFB300)],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.emoji_events_rounded,
                                    size: 52,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. TITLE WITH AUDIO REPLAY CUE & SUBTITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.tr('great_work'),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF142926),
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _speakResultVoice,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: Color(0xFF00796B),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('session_recorded'),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // User Identity Chip (Patient / Elder Session)
                  if (widget.patientName != null && widget.patientName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.20 : 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00796B).withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF00796B)),
                            const SizedBox(width: 6),
                            Text(
                              widget.patientId != null && widget.patientId!.isNotEmpty
                                  ? '${widget.patientName} · ${widget.patientId}'
                                  : widget.patientName!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00796B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 3. LEVEL CARD (Strict user requirements: Dynamic heading, no subheading, nothing below)
                  if (widget.nextLevel != null && widget.currentLevel != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132034) : const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E3557) : const Color(0xFFD6E4FF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isLevelUp
                                    ? Colors.green
                                    : isCalibrated
                                        ? Colors.orange
                                        : Colors.blue)
                                .withValues(alpha: isDark ? 0.15 : 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left circular bar chart icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2F4D) : const Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bar_chart_rounded,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Dynamic level title heading ONLY (no subheading, no text below)
                          Expanded(
                            child: Text(
                              levelTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          // Right decorative growth trend bars graphic
                          Opacity(
                            opacity: isDark ? 0.50 : 0.75,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 7,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF93C5FD),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 7,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF60A5FA),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 7,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.trending_up_rounded,
                                  size: 20,
                                  color: Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. "YOUR RESULTS" CARD (With bigger accuracy circle!)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162321) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF263C38) : const Color(0xFFE8EFEA),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.20 : 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF00796B)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('your_results'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1A3530),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Metric 1: Accuracy (Enlarged circle per user request)
                        Row(
                          children: [
                            // Big, bold circular progress indicator
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: CircularProgressIndicator(
                                      value: _normalizedAccuracy,
                                      strokeWidth: 7.2,
                                      backgroundColor: isDark
                                          ? const Color(0xFF213632)
                                          : const Color(0xFFE0F2F1),
                                      color: const Color(0xFF00796B),
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Text(
                                    '${(_normalizedAccuracy * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF163832),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('accuracy_label'),
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E3834),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.tr('correct_responses'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.20 : 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.crisis_alert_rounded, size: 21, color: Color(0xFF00796B)),
                            ),
                          ],
                        ),

                        Divider(height: 28, color: isDark ? const Color(0xFF263C38) : const Color(0xFFF0F4F2)),

                        // Metric 2: Performance
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2C2411) : const Color(0xFFFFF8E1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, size: 34, color: Color(0xFFFFA000)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('performance'),
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1E3834),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.tr('based_on_gameplay'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _cleanRatingText(_getPerformanceRating(context, _normalizedAccuracy)),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('✨', style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 5. MOTIVATIONAL QUOTE BANNER
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF142421) : const Color(0xFFEAF5F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF223E38) : const Color(0xFFD2ECE5),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -8,
                          bottom: -10,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: isDark ? 0.20 : 0.40,
                              child: Image.asset(
                                'assets/images/greeting_botanical_accent.png',
                                height: 48,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const SizedBox(),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF00796B)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('effort_keeps_mind_active'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: isDark ? const Color(0xFFB2DFDB) : const Color(0xFF1B4D43),
                                ),
                              ),
                            ),
                            const SizedBox(width: 30),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti party popper overlay
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final origin = Offset(size.width / 2, size.height * 0.18);

    for (final p in particles) {
      if (progress < p.delay) continue;
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);

      final blastDist = p.speed * t * (size.height * 0.38);
      final dx = cos(p.angle) * blastDist;
      final dy = sin(p.angle) * blastDist;

      final gravityDrop = p.gravity * t * t * (size.height * 0.65);
      final sway = sin(t * p.swaySpeed * pi * 2) * p.swayMagnitude;

      final posX = origin.dx + dx + sway;
      final posY = origin.dy + dy + gravityDrop;

      double alpha = 1.0;
      if (t > 0.72) {
        alpha = ((1.0 - t) / 0.28).clamp(0.0, 1.0);
      }
      if (alpha <= 0.0) continue;

      final flipX = cos(t * p.flipSpeed * pi * 2);
      final rotateAngle = p.angle + t * p.flipSpeed * 2.2;

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(posX, posY);
      canvas.rotate(rotateAngle);
      canvas.scale(flipX, 1.0);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.width / 2, paint);
      } else {
        final rect = Rect.fromCenter(center: Offset.zero, width: p.length, height: p.width);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
