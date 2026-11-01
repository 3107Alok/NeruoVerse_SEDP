import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';

enum DailyThoughtPage { home, games }

/// Shared repository and manager for positive calming thoughts across tabs
class DailyThoughts {
  static const List<String> thoughts = [
    '“Every small step makes a difference.”',
    '“Take your time. You’re doing great.”',
    '“A calm mind makes a brighter day.”',
    '“Keep learning, keep smiling.”',
    '“Today is a good day to exercise your mind.”',
    '“You’re stronger than you think.”',
    '“Small moments of practice build stronger memories.”',
    '“Stay curious, stay positive.”',
  ];

  static int? _homeIndex;
  static int? _gamesIndex;

  static void _ensureInitialized() {
    if (_homeIndex != null && _gamesIndex != null) return;
    final rand = math.Random();
    final hIndex = rand.nextInt(thoughts.length);
    int gIndex = rand.nextInt(thoughts.length - 1);
    if (gIndex >= hIndex) {
      gIndex += 1;
    }
    _homeIndex = hIndex;
    _gamesIndex = gIndex;
  }

  static String getHomeThought(BuildContext context) {
    _ensureInitialized();
    return context.tr('thought_${_homeIndex!}');
  }

  static String getGamesThought(BuildContext context) {
    _ensureInitialized();
    return context.tr('thought_${_gamesIndex!}');
  }

  static String get homeThought {
    _ensureInitialized();
    return thoughts[_homeIndex!];
  }

  static String get gamesThought {
    _ensureInitialized();
    return thoughts[_gamesIndex!];
  }

  /// Resets selection (e.g. for testing or fresh app session)
  static void reset() {
    _homeIndex = null;
    _gamesIndex = null;
  }
}

/// A warm, positive, calming thought card suitable for elderly users
class DailyThoughtCard extends StatelessWidget {
  final DailyThoughtPage page;
  final bool isDark;

  const DailyThoughtCard({
    super.key,
    required this.page,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final thought = page == DailyThoughtPage.home
        ? DailyThoughts.getHomeThought(context)
        : DailyThoughts.getGamesThought(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2824) : const Color(0xFFF6FAF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFD1E7DD),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2416) : const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF4A3816) : const Color(0xFFFDE68A),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.lightbulb_rounded,
                color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFD97706),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              thought,
              style: TextStyle(
                fontSize: 15.0,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1B3B36),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
