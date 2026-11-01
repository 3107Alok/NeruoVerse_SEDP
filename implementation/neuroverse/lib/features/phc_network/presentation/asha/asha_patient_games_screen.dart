import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../data/local/hive_service.dart';
import '../../models/phc_patient_model.dart';
import '../../data/phc_repository.dart';
import '../../../patient/games/common/ner_illustrations.dart';
import '../../../patient/games/memory_match/memory_match_screen.dart';
import '../../../patient/games/memory_recall/memory_recall_screen.dart';

class AshaPatientGamesScreen extends StatefulWidget {
  final PhcPatientModel patient;

  const AshaPatientGamesScreen({
    super.key,
    required this.patient,
  });

  @override
  State<AshaPatientGamesScreen> createState() => _AshaPatientGamesScreenState();
}

class _AshaPatientGamesScreenState extends State<AshaPatientGamesScreen> {
  late PhcPatientModel _patient;
  final HiveService _hiveService = HiveService();
  final PhcRepository _repository = PhcRepository();

  @override
  void initState() {
    super.initState();
    final matching = _repository.patients.where((p) => p.id == widget.patient.id);
    _patient = matching.isNotEmpty ? matching.first : widget.patient;
  }

  void _refreshPatient() {
    if (!mounted) return;
    final matching = _repository.patients.where((p) => p.id == widget.patient.id);
    if (matching.isNotEmpty) {
      setState(() {
        _patient = matching.first;
      });
    }
  }

  void _launchMemoryMatch() {
    final int level = _hiveService.getGameDifficultyForPatient(_patient.id, 'memory_match');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryMatchScreen(
          difficulty: level,
          patientId: _patient.id,
          patientName: _patient.name,
          onGameCompleted: (score, duration, accuracy) {
            _refreshPatient();
          },
        ),
      ),
    ).then((_) => _refreshPatient());
  }

  void _launchObjectFinder() {
    final int level = _hiveService.getGameDifficultyForPatient(_patient.id, 'memory_recall');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemoryRecallScreen(
          difficulty: level,
          patientId: _patient.id,
          patientName: _patient.name,
          onGameCompleted: (score, duration, accuracy) {
            _refreshPatient();
          },
        ),
      ),
    ).then((_) => _refreshPatient());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isSmall = screenW < 360;

    const primaryColor = Color(0xFF00796B);
    final bgColor = isDark ? const Color(0xFF0F1716) : const Color(0xFFF4F7F6);
    final cardBg = isDark ? const Color(0xFF162220) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF283B37) : const Color(0xFFE0EBE8);
    final titleColor = isDark ? Colors.white : const Color(0xFF142926);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF4A6B63);

    final bool isVisitedToday = _patient.status == 'visited_today';
    final int mmLevel = _hiveService.getGameDifficultyForPatient(_patient.id, 'memory_match');
    final int ofLevel = _hiveService.getGameDifficultyForPatient(_patient.id, 'memory_recall');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF14201E) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: titleColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('elder_cognitive_games'),
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: isSmall ? 17 : 19,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 14 : 18,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -------------------------------------------------------------
              // PINNED ELDER PROFILE HEADER (Strictly identifies active elder)
              // -------------------------------------------------------------
              Container(
                padding: EdgeInsets.all(isSmall ? 14 : 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVisitedToday
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : cardBorder,
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar Initial
                        Container(
                          width: isSmall ? 48 : 54,
                          height: isSmall ? 48 : 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00897B), Color(0xFF004D40)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _patient.name.trim().isNotEmpty
                                ? _patient.name.trim()[0].toUpperCase()
                                : 'E',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmall ? 20 : 23,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _patient.name,
                                style: TextStyle(
                                  fontSize: isSmall ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_patient.age} yrs · ${_patient.gender} · ${context.localizeVillage(_patient.village)}',
                                style: TextStyle(
                                  fontSize: isSmall ? 12 : 13,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE5EDE9)),
                    const SizedBox(height: 12),
                    // Elder ID & Status Verification Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Verified Elder ID Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_rounded, size: 14, color: primaryColor),
                              const SizedBox(width: 5),
                              Text(
                                'ID: ${_patient.id}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Screening Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVisitedToday
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isVisitedToday
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVisitedToday ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                size: 13,
                                color: isVisitedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isVisitedToday
                                    ? context.tr('elder_screened_today_score', params: {'score': _patient.latestScore.toString()})
                                    : context.tr('elder_due_screening'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isVisitedToday ? const Color(0xFF059669) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            context.tr('elder_session_guarantee_notice'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : const Color(0xFF5A756F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // -------------------------------------------------------------
              // SECTION TITLE & INSTRUCTION FOR ASHA
              // -------------------------------------------------------------
              Row(
                children: [
                  const Icon(Icons.sports_esports_rounded, size: 20, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('available_screening_games'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('elder_game_selection_sub'),
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // GAME 1: CARD MATCH (MEMORY MATCH)
              // -------------------------------------------------------------
              _buildElderGameCard(
                context: context,
                isDark: isDark,
                title: context.tr('memory_match'),
                subtitle: context.tr('memory_match_sub'),
                description: context.tr('desc_memory_match'),
                level: mmLevel,
                visual: GameHubVisual.memoryMatch,
                cardBgColor: isDark ? const Color(0xFF22151D) : const Color(0xFFFFF5F7),
                borderColor: isDark ? const Color(0xFF4D243B) : const Color(0xFFFED7E2),
                accentColor: const Color(0xFFD81B60),
                onPlay: _launchMemoryMatch,
              ),

              const SizedBox(height: 14),

              // -------------------------------------------------------------
              // GAME 2: OBJECT FINDER (MEMORY RECALL)
              // -------------------------------------------------------------
              _buildElderGameCard(
                context: context,
                isDark: isDark,
                title: context.tr('memory_recall'),
                subtitle: context.tr('memory_recall_sub'),
                description: context.tr('desc_memory_recall'),
                level: ofLevel,
                visual: GameHubVisual.memoryRecall,
                cardBgColor: isDark ? const Color(0xFF141F2B) : const Color(0xFFF0F7FF),
                borderColor: isDark ? const Color(0xFF233B54) : const Color(0xFFD0E2FF),
                accentColor: const Color(0xFF2563EB),
                onPlay: _launchObjectFinder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildElderGameCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required String description,
    required int level,
    required GameHubVisual visual,
    required Color cardBgColor,
    required Color borderColor,
    required Color accentColor,
    required VoidCallback onPlay,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF142926);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF4A6B63);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Illustration Visual
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: GameHubIllustration(
                  visual: visual,
                  size: 46,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Badges row: Adaptive Q-learning level & Voice assistance
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Q-Learning Level Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up_rounded, size: 13, color: accentColor),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('level_display_fmt', params: {'level': level.toString()}),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Voice Assisted Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up_rounded, size: 13, color: Color(0xFF00796B)),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('badge_voice_assisted'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              color: subtitleColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          // Action button to start game for this elder
          ElevatedButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
            label: Text(
              context.tr('start_game_for_elder_btn'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}
