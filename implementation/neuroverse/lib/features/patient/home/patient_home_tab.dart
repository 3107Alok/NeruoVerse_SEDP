import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/game_session.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../games/common/game_intro_screen.dart';
import '../games/common/ner_illustrations.dart';
import '../games/common/daily_thought_card.dart';
import '../games/memory_match/memory_match_screen.dart';
import '../games/pattern_path/pattern_path_screen.dart';
import '../games/face_recall/face_recall_screen.dart';
import '../games/memory_recall/memory_recall_screen.dart';
import '../../../../core/localization/app_translations.dart';
import 'widgets/sos_emergency_button.dart';
import 'widgets/call_caregiver_button.dart';

class PatientHomeTab extends StatefulWidget {
  final DateTime Function()? nowOverride;

  const PatientHomeTab({super.key, this.nowOverride});

  @override
  State<PatientHomeTab> createState() => _PatientHomeTabState();
}

class _PatientHomeTabState extends State<PatientHomeTab>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightTimer();
  }

  @override
  void didUpdateWidget(PatientHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nowOverride != widget.nowOverride) {
      _scheduleMidnightTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<AppProvider>().loadProgress();
        setState(() {});
        _scheduleMidnightTimer();
      }
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = widget.nowOverride?.call() ?? DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight =
        nextMidnight.difference(now) + const Duration(milliseconds: 100);

    _midnightTimer = Timer(durationUntilMidnight, () {
      if (mounted) {
        context.read<AppProvider>().loadProgress();
        setState(() {});
        _scheduleMidnightTimer();
      }
    });
  }

  String _getGreeting(BuildContext context, DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return context.tr('greeting_morning');
    } else if (hour >= 12 && hour < 17) {
      return context.tr('greeting_afternoon');
    } else if (hour >= 17 && hour < 21) {
      return context.tr('greeting_evening');
    } else {
      return context.tr('greeting_night');
    }
  }

  IconData _getGreetingIcon(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_rounded;
    } else if (hour >= 12 && hour < 17) {
      return Icons.light_mode_rounded;
    } else if (hour >= 17 && hour < 21) {
      return Icons.wb_twilight_rounded;
    } else {
      return Icons.nights_stay_rounded;
    }
  }

  String _getGreetingSubtitle(BuildContext context, DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) {
      return context.tr('subtitle_morning');
    } else if (hour >= 12 && hour < 17) {
      return context.tr('subtitle_afternoon');
    } else if (hour >= 17 && hour < 21) {
      return context.tr('subtitle_evening');
    } else {
      return context.tr('subtitle_night');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hiveService = context.read<app_hive.HiveService>();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<AppProvider>().loadProgress();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          child: Consumer<AppProvider>(
            builder: (context, appProvider, child) {
              final name =
                  (appProvider.userName != null &&
                      appProvider.userName!.trim().isNotEmpty)
                  ? appProvider.userName!.trim()
                  : 'Champion';
              final now = widget.nowOverride?.call() ?? DateTime.now();
              final greeting = _getGreeting(context, now);
              final icon = _getGreetingIcon(now);
              final subtitle = _getGreetingSubtitle(context, now);

              final todaySessions = appProvider.gameHistory
                  .where(
                    (s) =>
                        s.timestamp.year == now.year &&
                        s.timestamp.month == now.month &&
                        s.timestamp.day == now.day,
                  )
                  .toList();

              final mmDone = todaySessions.any(
                (s) => s.gameId == 'memory_match',
              );
              final frDone = todaySessions.any(
                (s) => s.gameId == 'face_recall',
              );
              final ppDone = todaySessions.any(
                (s) => s.gameId == 'pattern_path',
              );
              final completedTasks =
                  (mmDone ? 1 : 0) + (frDone ? 1 : 0) + (ppDone ? 1 : 0);


              final sortedTodaySessions = List<GameSession>.from(todaySessions)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
              final playedGameIds = <String>[];
              final seenGameIds = <String>{};
              for (final session in sortedTodaySessions) {
                if (seenGameIds.add(session.gameId)) {
                  playedGameIds.add(session.gameId);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic Warm Greeting Header with North-East Landscape Art and Botanical Leaf Accent
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1B2E27)
                          : const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E4C3E)
                            : const Color(0xFFC8E6C9),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedNerLandscape(
                              isDark: isDark,
                              duration: const Duration(seconds: 14),
                            ),
                          ),
                          // Decorative green botanical leaf illustration on the right side
                          Positioned(
                            right: 4,
                            bottom: 0,
                            child: IgnorePointer(
                              child: _GreetingLeafIllustration(
                                isDark: isDark,
                                height: 92,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            icon,
                                            color: const Color(0xFFE65100),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '$greeting,',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF2E7D32),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$name!',
                                        style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1B3B36),
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF4A6B63),
                                          height: 1.25,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Reserve breathing room for the botanical leaf illustration on the right
                                const SizedBox(width: 64),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Today's Goal Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.eco_rounded,
                                      size: 16,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.tr('todays_goal'),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF2C3E50),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: completedTasks == 3
                                    ? const Color(0xFFE8F5E9)
                                    : (isDark
                                          ? Colors.white12
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (completedTasks == 3) ...[
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 13,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    completedTasks == 3
                                        ? context.tr('completed')
                                        : '$completedTasks / 3',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: completedTasks == 3
                                          ? const Color(0xFF2E7D32)
                                          : (isDark
                                                ? Colors.white70
                                                : const Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            'exercises_completed_fmt',
                            params: {
                              'completed': '$completedTasks',
                              'total': '3',
                            },
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1B3B36),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          completedTasks == 3
                              ? context.tr('goal_achieved')
                              : context.tr(
                                  'goal_remaining',
                                  params: {
                                    'remaining': '${3 - completedTasks}',
                                  },
                                ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: completedTasks == 3
                                ? const Color(0xFF2E7D32)
                                : (isDark
                                      ? Colors.white60
                                      : Colors.grey.shade600),
                            fontWeight: completedTasks == 3
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: completedTasks / 3.0,
                            backgroundColor: isDark
                                ? Colors.white12
                                : const Color(0xFFE8F5E9),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2E7D32),
                            ),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Stats Glance (Streak & Accuracy)
                  Row(
                    children: [
                      // Streak Tile (Clickable to open active days dialog)
                      // Call Caregiver Tile (Direct 1-tap dialer)
                      const Expanded(
                        child: CallCaregiverButton(),
                      ),
                      const SizedBox(width: 12),

                      // Emergency SOS Button (Hold 2s for accidental tap prevention)
                      const Expanded(
                        child: SosEmergencyButton(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Daily Tasks Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.spa_rounded,
                              size: 18,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                context.tr('todays_exercises'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  fontSize: 13.5,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF1B3B36),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr(
                            'active_tasks_fmt',
                            params: {
                              'completed': '$completedTasks',
                              'total': '3',
                            },
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Today's Exercises Cards or Empty State
                  if (playedGameIds.isEmpty)
                    _buildExercisesEmptyState(context, isDark)
                  else
                    for (int i = 0; i < playedGameIds.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildGameCardForId(
                        context: context,
                        gameId: playedGameIds[i],
                        todaySessions: todaySessions,
                        isDark: isDark,
                        hiveService: hiveService,
                      ),
                    ],

                  const SizedBox(height: 20),

                  // Positive Calming Thought Card
                  DailyThoughtCard(page: DailyThoughtPage.home, isDark: isDark),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExercisesEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF263238) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF2E7D32),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('exercises_empty_title'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF1B3B36),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('exercises_empty_subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCardForId({
    required BuildContext context,
    required String gameId,
    required List<GameSession> todaySessions,
    required bool isDark,
    required app_hive.HiveService hiveService,
  }) {
    final gameSessions = todaySessions
        .where((s) => s.gameId == gameId)
        .toList();
    final playsCount = gameSessions.length;
    final bestAcc = gameSessions.fold<double>(
      0.0,
      (max, s) =>
          s.accuracyPercentage > max ? s.accuracyPercentage.toDouble() : max,
    );
    final progress = bestAcc / 100.0;
    final statusWidget = _buildStatusWidget(
      context,
      isDark,
      playsCount > 0,
      playsCount,
      progress,
    );

    switch (gameId) {
      case 'memory_match':
        final mmLevel = hiveService.getGameDifficulty('memory_match');
        return _buildTaskCard(
          context: context,
          visual: GameHubVisual.memoryMatch,
          title: context.tr('memory_match'),
          subtitle: context.tr('memory_match_sub'),
          level: mmLevel,
          cardBg: const Color(0xFFFFF5F7),
          borderColor: const Color(0xFFFED7E2),
          accentColor: const Color(0xFFD81B60),
          statusWidget: statusWidget,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameIntroScreen(
                  title: context.tr('memory_match'),
                  description: context.tr('desc_memory_match'),
                  challengeCount: 2 + (mmLevel - 1),
                  icon: Icons.psychology_rounded,
                  themeTag: context.tr('tag_tea_estates'),
                  visual: GameHubVisual.memoryMatch,
                  gameBuilder: () => MemoryMatchScreen(difficulty: mmLevel),
                ),
              ),
            );
          },
        );

      case 'face_recall':
        final frLevel = hiveService.getGameDifficulty('face_recall');
        return _buildTaskCard(
          context: context,
          visual: GameHubVisual.faceRecall,
          title: context.tr('face_recall'),
          subtitle: context.tr('face_recall_sub').split('•').first.trim(),
          level: frLevel,
          cardBg: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          accentColor: const Color(0xFFD97706),
          statusWidget: statusWidget,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameIntroScreen(
                  title: context.tr('face_recall'),
                  description: context.tr('desc_face_recall'),
                  challengeCount: 1,
                  icon: Icons.family_restroom_rounded,
                  themeTag: context.tr('tag_family_faces'),
                  visual: GameHubVisual.faceRecall,
                  gameBuilder: () => FaceRecallScreen(difficulty: frLevel),
                ),
              ),
            );
          },
        );

      case 'pattern_path':
        final ppLevel = hiveService.getGameDifficulty('pattern_path');
        return _buildTaskCard(
          context: context,
          visual: GameHubVisual.patternPath,
          title: context.tr('pattern_path'),
          subtitle: context.tr('pattern_path_sub'),
          level: ppLevel,
          cardBg: const Color(0xFFF0FDF4),
          borderColor: const Color(0xFFBBF7D0),
          accentColor: const Color(0xFF16A34A),
          statusWidget: statusWidget,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameIntroScreen(
                  title: context.tr('pattern_path'),
                  description: context.tr('desc_pattern_path'),
                  challengeCount: 2 + ppLevel,
                  icon: Icons.extension_rounded,
                  themeTag: context.tr('tag_root_bridge'),
                  visual: GameHubVisual.patternPath,
                  gameBuilder: () => PatternPathScreen(difficulty: ppLevel),
                ),
              ),
            );
          },
        );

      case 'memory_recall':
        final mrLevel = hiveService.getGameDifficulty('memory_recall');
        return _buildTaskCard(
          context: context,
          visual: GameHubVisual.memoryRecall,
          title: context.tr('memory_recall'),
          subtitle: context.tr('memory_recall_sub'),
          level: mrLevel,
          cardBg: const Color(0xFFF0F4F8),
          borderColor: const Color(0xFFD1E2EE),
          accentColor: const Color(0xFF2563EB),
          statusWidget: statusWidget,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameIntroScreen(
                  title: context.tr('memory_recall'),
                  description: context.tr('desc_memory_recall'),
                  challengeCount: (3 + (mrLevel - 1) ~/ 2).clamp(3, 8),
                  icon: Icons.record_voice_over_rounded,
                  themeTag: context.tr('tag_heritage_echoes'),
                  visual: GameHubVisual.memoryRecall,
                  gameBuilder: () => MemoryRecallScreen(difficulty: mrLevel),
                ),
              ),
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusWidget(
    BuildContext context,
    bool isDark,
    bool isStarted,
    int playsCount,
    double progress,
  ) {
    if (isStarted) {
      return Row(
        children: [
          const Icon(
            Icons.play_circle_fill,
            size: 15,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 5),
          Text(
            context.tr('plays_fmt', params: {'count': '$playsCount'}),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
              fontSize: 11.5,
            ),
          ),
          const Spacer(),
          Text(
            context.tr(
              'best_acc_fmt',
              params: {'acc': '${(progress * 100).toInt()}'},
            ),
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.tr('not_started_yet'),
          style: TextStyle(
            fontSize: 11.5,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required GameHubVisual visual,
    required String title,
    required String subtitle,
    required int level,
    required Color cardBg,
    required Color borderColor,
    required Color accentColor,
    required Widget statusWidget,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF263238) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: GameHubIllustration(visual: visual, size: 70),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.5,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1B3B36),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF5A6E68),
                        fontSize: 11.8,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    statusWidget,
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative botanical leaf illustration displayed on the right side of the
/// Wish/Greeting card on the Patient Home page.
///
/// Features an elegant, full botanical composition with curved stems,
/// soft layered foliage, and an organic flowing ribbon base that seamlessly
/// integrates with the card's North-East landscape theme.
class _GreetingLeafIllustration extends StatelessWidget {
  final bool isDark;
  final double height;

  const _GreetingLeafIllustration({required this.isDark, this.height = 92});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/greeting_botanical_accent.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
