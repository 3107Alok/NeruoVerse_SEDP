import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_session.dart';
import '../localization/app_translations.dart';

List<DateTime> getActiveTrainingDays(List<GameSession> history) {
  final Map<String, DateTime> map = {};
  for (var s in history) {
    final d = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
    final key = DateFormat('yyyy-MM-dd').format(d);
    map.putIfAbsent(key, () => d);
  }
  final sorted = map.values.toList()..sort((a, b) => b.compareTo(a));
  return sorted;
}

int calculateTrainingStreak(List<GameSession> history) {
  final activeDays = getActiveTrainingDays(history);
  if (activeDays.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final latest = activeDays.first;
  if (latest.isBefore(yesterday)) {
    return 0;
  }

  int streak = 0;
  DateTime check = latest;
  for (var day in activeDays) {
    if (day.year == check.year && day.month == check.month && day.day == check.day) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
}

void showActiveDaysDialog(BuildContext context, int streak, List<GameSession> history) {
  final activeDays = getActiveTrainingDays(history);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final now = DateTime.now();

  final past14Days = List.generate(14, (index) {
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: 13 - index));
  });

  final activeSet = activeDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('active_training_days'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  context.tr('streak_consecutive_fmt', params: {'streak': streak.toString()}),
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Streak counter highlight
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$streak',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      context.tr('current_streak'),
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Column(
                  children: [
                    Text(
                      '${activeDays.length}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      context.tr('total_active_days'),
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('past_14_days'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          // Grid of past 14 days
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: past14Days.map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final isActive = activeSet.contains(dateStr);
              final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.getWeekdayLetter(date),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF00796B)
                          : (isToday ? Colors.orange.shade50 : (isDark ? Colors.white10 : Colors.grey.shade100)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? Colors.orange
                            : (isActive ? const Color(0xFF004D40) : Colors.transparent),
                        width: isToday ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isActive
                        ? const Icon(Icons.local_fire_department_rounded, size: 18, color: Colors.white)
                        : Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? Colors.orange.shade800 : (isDark ? Colors.white60 : Colors.grey.shade600),
                            ),
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(context.tr('keep_training'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}
