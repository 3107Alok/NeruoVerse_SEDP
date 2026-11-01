import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../common/game_intro_screen.dart';
import '../common/ner_illustrations.dart';
import '../common/daily_thought_card.dart';
import '../memory_match/memory_match_screen.dart';
import '../pattern_path/pattern_path_screen.dart';
import '../face_recall/face_recall_screen.dart';
import '../memory_recall/memory_recall_screen.dart';
import '../../../../core/localization/app_translations.dart';

class GameHubTab extends StatelessWidget {
  const GameHubTab({super.key});

  String _getGameDescription(BuildContext context, String gameId) {
    return context.tr('desc_$gameId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hiveService = context.read<app_hive.HiveService>();
    final mmLevel = hiveService.getGameDifficulty('memory_match');
    final ppLevel = hiveService.getGameDifficulty('pattern_path');
    final frLevel = hiveService.getGameDifficulty('face_recall');
    final mrLevel = hiveService.getGameDifficulty('memory_recall');

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final screenW = MediaQuery.of(context).size.width;
    final userLang = context.watch<AppProvider>().userLanguage;
    final isRegional = AppTranslations.normalizeLangCode(userLang) != 'en';

    // Slightly more compact responsive aspect ratio to decrease card size as requested
    double gridRatio = 0.83;
    if (isRegional || textScale > 1.05) {
      gridRatio = 0.79;
    }
    if (screenW < 360) {
      gridRatio = 0.74;
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with title and subtitle (clean and spacious)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 24, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('cognitive_games'),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B3B36),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('cognitive_games_sub'),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF5A6E68),
                    height: 1.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2x2 Grid of Culturally-Themed Game Cards
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: gridRatio,
              children: [
                _buildGameCard(
                  context: context,
                  title: context.tr('memory_match'),
                  category: context.tr('memory_match_sub'),
                  visual: GameHubVisual.memoryMatch,
                  level: mmLevel,
                  description: _getGameDescription(context, 'memory_match'),
                  challengeCount: 2 + (mmLevel - 1),
                  themeTag: context.tr('tag_tea_estates'),
                  cardBg: const Color(0xFFFFF5F7),
                  borderColor: const Color(0xFFFED7E2),
                  accentColor: const Color(0xFFD81B60),
                  screenBuilder: () => MemoryMatchScreen(difficulty: mmLevel),
                ),
                _buildGameCard(
                  context: context,
                  title: context.tr('pattern_path'),
                  category: context.tr('pattern_path_sub'),
                  visual: GameHubVisual.patternPath,
                  level: ppLevel,
                  description: _getGameDescription(context, 'pattern_path'),
                  challengeCount: 2 + ppLevel,
                  themeTag: context.tr('tag_root_bridge'),
                  cardBg: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFBBF7D0),
                  accentColor: const Color(0xFF16A34A),
                  screenBuilder: () => PatternPathScreen(difficulty: ppLevel),
                ),
                _buildGameCard(
                  context: context,
                  title: context.tr('face_recall'),
                  category: context.tr('face_recall_sub'),
                  visual: GameHubVisual.faceRecall,
                  level: frLevel,
                  description: _getGameDescription(context, 'face_recall'),
                  challengeCount: 1,
                  themeTag: context.tr('tag_family_faces'),
                  cardBg: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                  accentColor: const Color(0xFFD97706),
                  screenBuilder: () => FaceRecallScreen(difficulty: frLevel),
                ),
                _buildGameCard(
                  context: context,
                  title: context.tr('memory_recall'),
                  category: context.tr('memory_recall_sub'),
                  visual: GameHubVisual.memoryRecall,
                  level: mrLevel,
                  description: _getGameDescription(context, 'memory_recall'),
                  challengeCount: (3 + (mrLevel - 1) ~/ 2).clamp(3, 8),
                  themeTag: context.tr('tag_heritage_echoes'),
                  cardBg: const Color(0xFFF0F4F8),
                  borderColor: const Color(0xFFD1E2EE),
                  accentColor: const Color(0xFF2563EB),
                  screenBuilder: () => MemoryRecallScreen(difficulty: mrLevel),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Positive Calming Thought Card (Guaranteed distinct from Home page)
            DailyThoughtCard(
              page: DailyThoughtPage.games,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String category,
    required GameHubVisual visual,
    required int level,
    required String description,
    required int challengeCount,
    required String themeTag,
    required Color cardBg,
    required Color borderColor,
    required Color accentColor,
    required Widget Function() screenBuilder,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : borderColor,
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameIntroScreen(
                  title: title,
                  description: description,
                  challengeCount: challengeCount,
                  icon: Icons.psychology_rounded,
                  themeTag: themeTag,
                  visual: visual,
                  gameBuilder: screenBuilder,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 7.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slightly decreased illustration container (64x64, icon size 52)
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF263238) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: GameHubIllustration(
                      visual: visual,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Category tag (First point only)
                Text(
                  category.contains('•') ? category.split('•').first.trim() : category,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Clean stress-free action row (No numeric level shown)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr('play_now'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

