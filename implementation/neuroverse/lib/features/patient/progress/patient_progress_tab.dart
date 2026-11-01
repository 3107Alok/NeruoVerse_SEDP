import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/game_session.dart';
import '../../../../core/widgets/active_days_dialog.dart';
import '../../../../core/localization/app_translations.dart';

class PatientProgressTab extends StatelessWidget {
  const PatientProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final history = provider.gameHistory;

        // Empty state when no games have been played yet
        if (history.isEmpty) {
          return RefreshIndicator(
            color: const Color(0xFF00796B),
            onRefresh: () async {
              context.read<AppProvider>().loadProgress();
            },
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    children: [
                      _buildHeader(context, isDark),
                      const SizedBox(height: 48),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2422) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bar_chart_rounded,
                                size: 54,
                                color: Color(0xFF00796B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              context.tr('no_analytics'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1B3B36),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('no_analytics_sub'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // --- Aggregation Logic (strictly preserved & null-safe) ---
        int totalGames = history.length;
        double overallAccuracy = totalGames > 0
            ? (history.fold<double>(0.0, (prev, s) => prev + s.accuracyPercentage) / totalGames)
            : 0.0;
        double overallCogScore = 0;
        int cogCount = 0;
        for (var s in history) {
          final cog = s.cognitiveScore;
          if (cog != null && cog > 0) {
            overallCogScore += cog;
            cogCount++;
          }
        }
        if (cogCount > 0) overallCogScore /= cogCount;

        // Game specific stats
        Map<String, List<GameSession>> gameMap = {};
        for (var s in history) {
          gameMap.putIfAbsent(s.gameId, () => []).add(s);
        }

        // Daily specific stats (Group by Date)
        Map<String, List<GameSession>> dailyMap = {};
        for (var s in history) {
          final dateKey = DateFormat('yyyy-MM-dd').format(s.timestamp);
          dailyMap.putIfAbsent(dateKey, () => []).add(s);
        }

        final streakCount = calculateTrainingStreak(history);

        return RefreshIndicator(
          color: const Color(0xFF00796B),
          onRefresh: () async {
            context.read<AppProvider>().loadProgress();
          },
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  children: [
                    // Header
                    _buildHeader(context, isDark),
                    const SizedBox(height: 18),

                    // 1. Softer, Calmer Streak Card (Clickable to view active days)
                    _buildStreakCard(context, streakCount, history, isDark),
                    const SizedBox(height: 18),

                    // 2. High-Readability Overall Summary Cards
                    _buildOverallSummary(context, totalGames, overallAccuracy, overallCogScore, isDark),
                    const SizedBox(height: 28),

                    // 3. Daily Level & Game Tracking
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('daily_tracking'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1B3B36),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.09),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00796B).withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            context.tr('daily_reset_active'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('daily_tracking_sub'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...dailyMap.entries.take(7).map((entry) => _buildDailyTrackingCard(context, entry.key, entry.value, isDark)),

                    const SizedBox(height: 24),

                    // 4. Game-wise Analytics
                    Text(
                      context.tr('game_performance'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B3B36),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('game_performance_sub'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...gameMap.entries.map((entry) => _buildGameAnalyticsCard(context, entry.key, entry.value, isDark)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('analytics'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B3B36),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.tr('analytics_sub'),
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTrackingCard(BuildContext context, String dateKey, List<GameSession> daySessions, bool isDark) {
    if (daySessions.isEmpty) return const SizedBox.shrink();
    final firstDate = daySessions.first.timestamp;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final isToday = sessionDay.isAtSameMomentAs(today);
    final isYesterday = sessionDay.isAtSameMomentAs(today.subtract(const Duration(days: 1)));
    final theme = Theme.of(context);

    String displayDate;
    if (isToday) {
      displayDate = context.tr('today_date_fmt', params: {
        'date': context.formatDate(firstDate,
            includeWeekday: false, includeYear: false)
      });
    } else if (isYesterday) {
      displayDate = context.tr('yesterday_date_fmt', params: {
        'date': context.formatDate(firstDate,
            includeWeekday: false, includeYear: false)
      });
    } else {
      displayDate = context.formatDate(firstDate,
          includeWeekday: true, includeYear: true);
    }

    // Group by game for this day
    Map<String, List<GameSession>> gameInDay = {};
    for (var s in daySessions) {
      gameInDay.putIfAbsent(s.gameId, () => []).add(s);
    }

    final cardColor = isDark ? const Color(0xFF1A2422) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF00796B)),
          ),
          title: Text(
            displayDate,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: isToday ? const Color(0xFF00796B) : (isDark ? Colors.white : const Color(0xFF1B3B36)),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.tr(
                    daySessions.length == 1
                        ? 'day_play_single_fmt'
                        : 'day_plays_count_fmt',
                    params: {'count': daySessions.length.toString()},
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00796B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 22, color: isDark ? Colors.white60 : const Color(0xFF94A3B8)),
            ],
          ),
          children: [
            Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: gameInDay.entries.map((entry) {
                  final gId = entry.key;
                  final gSessions = entry.value;
                  final maxLevel = gSessions.fold<int>(1, (prev, s) => s.difficultyLevel > prev ? s.difficultyLevel : prev);
                  final bestAcc = gSessions.fold<int>(0, (prev, s) => s.accuracyPercentage > prev ? s.accuracyPercentage : prev);

                  String gName = context.tr('game');
                  IconData gIcon = Icons.sports_esports_rounded;
                  Color gColor = const Color(0xFFD97706);
                  if (gId.contains('memory_match')) {
                    gName = context.tr('memory_match');
                    gIcon = Icons.psychology_rounded;
                    gColor = const Color(0xFF9333EA);
                  } else if (gId.contains('pattern')) {
                    gName = context.tr('pattern_path');
                    gIcon = Icons.route_rounded;
                    gColor = const Color(0xFF16A34A);
                  } else if (gId.contains('face') || gId.contains('focus')) {
                    gName = context.tr('face_recall');
                    gIcon = Icons.people_alt_rounded;
                    gColor = const Color(0xFFD97706);
                  } else if (gId.contains('recall')) {
                    gName = context.tr('memory_recall');
                    gIcon = Icons.psychology_alt_rounded;
                    gColor = const Color(0xFF00796B);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gColor.withValues(alpha: isDark ? 0.2 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(gIcon, size: 18, color: gColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('best_acc_plays_fmt', params: {
                                  'acc': bestAcc.toString(),
                                  'count': gSessions.length.toString(),
                                }),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: gColor.withValues(alpha: isDark ? 0.18 : 0.09),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 15, color: gColor),
                              const SizedBox(width: 3),
                              Text(
                                context.tr('level_fmt',
                                    params: {'level': maxLevel.toString()}),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: gColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildOverallSummary(BuildContext context, int total, double avgAcc, double avgCog, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryBox(
            context,
            context.tr('total_games'),
            total.toString(),
            Icons.sports_esports_rounded,
            const Color(0xFF0284C7),
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryBox(
            context,
            context.tr('avg_accuracy'),
            '${avgAcc.toStringAsFixed(0)}%',
            Icons.check_circle_rounded,
            const Color(0xFF16A34A),
            isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryBox(
            context,
            context.tr('cognitive_score'),
            avgCog.toStringAsFixed(1),
            Icons.psychology_rounded,
            const Color(0xFF7C3AED),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final cardColor = isDark ? const Color(0xFF1A2422) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B3B36),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameAnalyticsCard(BuildContext context, String gameId, List<GameSession> sessions, bool isDark) {
    double avgAcc = sessions.isEmpty ? 0.0 : (sessions.fold<double>(0.0, (p, s) => p + s.accuracyPercentage) / sessions.length);
    double avgTime = sessions.isEmpty ? 0.0 : (sessions.fold<double>(0.0, (p, s) => p + s.completionTimeSeconds) / sessions.length);
    int maxLevel = sessions.fold<int>(1, (p, s) => s.difficultyLevel > p ? s.difficultyLevel : p);

    String gameName = context.tr('game');
    IconData gameIcon = Icons.sports_esports_rounded;
    Color color = const Color(0xFFD97706);

    if (gameId.contains('memory_match')) {
      gameName = context.tr('memory_match');
      gameIcon = Icons.psychology_rounded;
      color = const Color(0xFF9333EA);
    } else if (gameId.contains('pattern')) {
      gameName = context.tr('pattern_path');
      gameIcon = Icons.route_rounded;
      color = const Color(0xFF16A34A);
    } else if (gameId.contains('face') || gameId.contains('focus')) {
      gameName = context.tr('face_recall');
      gameIcon = Icons.people_alt_rounded;
      color = const Color(0xFFD97706);
    } else if (gameId.contains('recall')) {
      gameName = context.tr('memory_recall');
      gameIcon = Icons.psychology_alt_rounded;
      color = const Color(0xFF00796B);
    }

    final cardColor = isDark ? const Color(0xFF1A2422) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(gameIcon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gameName,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded, size: 16, color: color),
                    const SizedBox(width: 3),
                    Text(
                      context.tr('best_level_fmt', params: {'level': maxLevel.toString()}),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(context.tr('avg_accuracy'), '${avgAcc.toStringAsFixed(0)}%', isDark),
              Container(width: 1, height: 28, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              _buildMetric(context.tr('avg_time'), '${avgTime.toStringAsFixed(1)}s', isDark),
              Container(width: 1, height: 28, color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              _buildMetric(context.tr('total_plays'), '${sessions.length}', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('accuracy_level'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    '${avgAcc.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (avgAcc / 100.0).clamp(0.0, 1.0),
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B3B36),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak, List<GameSession> history, bool isDark) {
    final streakBg = isDark ? const Color(0xFF261C14) : const Color(0xFFFFF7ED);
    final streakBorder = isDark ? const Color(0xFF5A3816) : const Color(0xFFFED7AA);
    final iconBg = isDark ? const Color(0xFF3B2412) : const Color(0xFFFFEDD5);
    final titleColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412);
    final subtitleColor = isDark ? const Color(0xFFFED7AA) : const Color(0xFFC2410C);
    final pillBg = isDark ? const Color(0xFF3B2412) : Colors.white;
    final pillBorder = isDark ? const Color(0xFF5A3816) : const Color(0xFFFED7AA);
    final flameColor = const Color(0xFFEA580C);

    return InkWell(
      onTap: () => showActiveDaysDialog(context, streak, history),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: streakBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: streakBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_fire_department_rounded, color: flameColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.tr('day_streak_banner', params: {'days': streak.toString()}),
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak > 0
                        ? context.tr('streak_active_tip')
                        : context.tr('streak_start_tip'),
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pillBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$streak 🔥',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: flameColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16, color: flameColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
