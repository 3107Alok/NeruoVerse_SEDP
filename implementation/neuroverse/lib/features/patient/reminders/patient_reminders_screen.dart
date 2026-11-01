import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/models/reminder_model.dart';
import '../../../core/services/reminder_service.dart';

class PatientRemindersScreen extends StatefulWidget {
  final String? patientIdOverride;
  final Stream<List<ReminderModel>>? remindersStreamOverride;

  const PatientRemindersScreen({
    super.key,
    this.patientIdOverride,
    this.remindersStreamOverride,
  });

  @override
  State<PatientRemindersScreen> createState() => _PatientRemindersScreenState();
}

class _PatientRemindersScreenState extends State<PatientRemindersScreen> {
  int _selectedFilterIndex =
      0; // 0: All, 1: Medicine, 2: Hydration, 3: Daily Activities
  final ReminderService _reminderService = ReminderService();

  String get _currentPatientId {
    if (widget.patientIdOverride != null &&
        widget.patientIdOverride!.isNotEmpty) {
      return widget.patientIdOverride!;
    }
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF80CBC4)
        : const Color(0xFF00796B);
    final bgColor = isDark ? const Color(0xFF101B19) : const Color(0xFFF7FAF9);

    final filters = [
      {
        'key': 'filter_all',
        'label': context.tr('filter_all'),
        'icon': Icons.list_alt_rounded,
      },
      {
        'key': 'filter_medicine',
        'label': context.tr('filter_medicine'),
        'icon': Icons.medication_rounded,
      },
      {
        'key': 'filter_hydration',
        'label': context.tr('filter_hydration'),
        'icon': Icons.water_drop_rounded,
      },
      {
        'key': 'filter_daily_activities',
        'label': context.tr('filter_daily_activities'),
        'icon': Icons.psychology_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          context.tr('reminders'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF132B27),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF162422) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF132B27),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.tr('close'),
        ),
      ),
      body: Column(
        children: [
          // 1. Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF162422) : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  final item = filters[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF4A6B63)),
                        ),
                      ),
                      backgroundColor: isDark
                          ? const Color(0xFF1E2F2B)
                          : const Color(0xFFEDF5F2),
                      selectedColor: primaryColor,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? primaryColor
                              : (isDark
                                    ? const Color(0xFF2E433E)
                                    : const Color(0xFFD6E6E1)),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedFilterIndex = index),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 2. Reminders Stream / List
          Expanded(
            child: StreamBuilder<List<ReminderModel>>(
              stream:
                  widget.remindersStreamOverride ??
                  (_currentPatientId.isNotEmpty
                      ? _reminderService.getPatientRemindersStream(
                          _currentPatientId,
                        )
                      : const Stream.empty()),
              builder: (context, snapshot) {
                final allReminders = snapshot.data ?? [];

                // Filter reminders according to tab
                List<ReminderModel> filtered = [];
                bool includeDailyActivitiesCard = false;

                if (_selectedFilterIndex == 0) {
                  // All
                  filtered = allReminders;
                  includeDailyActivitiesCard = true;
                } else if (_selectedFilterIndex == 1) {
                  // Medicine
                  filtered = allReminders
                      .where((r) => r.type == ReminderType.medicine)
                      .toList();
                } else if (_selectedFilterIndex == 2) {
                  // Hydration
                  filtered = allReminders
                      .where((r) => r.type == ReminderType.hydration)
                      .toList();
                } else if (_selectedFilterIndex == 3) {
                  // Daily Activities
                  filtered = allReminders
                      .where((r) => r.type == ReminderType.dailyActivity)
                      .toList();
                  includeDailyActivitiesCard = true;
                }

                if (filtered.isEmpty && !includeDailyActivitiesCard) {
                  return _buildEmptyState(context, isDark);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    // System Daily Activities card when relevant
                    if (includeDailyActivitiesCard)
                      _buildDailyBrainCard(context, isDark, primaryColor),

                    // Reminders list
                    ...filtered.map(
                      (reminder) => _buildReminderCard(
                        context,
                        reminder,
                        isDark,
                        primaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2E2A)
                    : const Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.alarm_on_rounded,
                size: 56,
                color: isDark
                    ? const Color(0xFF80CBC4)
                    : const Color(0xFF00796B),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('no_reminders_found'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF132B27),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_reminders_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? Colors.white60 : const Color(0xFF5A7B73),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBrainCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
  ) {
    final now = DateTime.now();
    // Next occurrence for 9:00 AM or 7:00 PM (19:00)
    final morning = DateTime(now.year, now.month, now.day, 9, 0);
    final evening = DateTime(now.year, now.month, now.day, 19, 0);

    String nextTimeStr;
    if (now.isBefore(morning)) {
      nextTimeStr = 'Today at 9:00 AM';
    } else if (now.isBefore(evening)) {
      nextTimeStr = 'Today at 7:00 PM';
    } else {
      nextTimeStr = 'Tomorrow at 9:00 AM';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E433E) : const Color(0xFFD6E6E1),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF182825) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('daily_brain_reminder_title'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF132B27),
                              ),
                            ),
                          ),
                          _buildStatusBadge(
                            context,
                            ReminderStatus.active,
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('daily_brain_reminder_desc'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF4A6B63),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22, thickness: 0.8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('next_reminder', params: {'time': nextTimeStr}),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily (2x)',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    ReminderModel reminder,
    bool isDark,
    Color primaryColor,
  ) {
    IconData iconData;
    Color iconColor;

    switch (reminder.type) {
      case ReminderType.medicine:
        iconData = Icons.medication_rounded;
        iconColor = const Color(0xFF00796B);
        break;
      case ReminderType.hydration:
        iconData = Icons.water_drop_rounded;
        iconColor = const Color(0xFF0288D1);
        break;
      case ReminderType.dailyActivity:
        iconData = Icons.psychology_rounded;
        iconColor = const Color(0xFF8B5CF6);
        break;
    }

    final nextOccur = reminder.getNextOccurrence();
    String nextTimeText = '---';
    if (nextOccur != null) {
      final now = DateTime.now();
      final timeStr = DateFormat('h:mm a').format(nextOccur);
      if (nextOccur.year == now.year &&
          nextOccur.month == now.month &&
          nextOccur.day == now.day) {
        nextTimeText = context.tr('today_at_fmt', params: {'time': timeStr});
      } else if (nextOccur.year == now.year &&
          nextOccur.month == now.month &&
          nextOccur.day == now.day + 1) {
        nextTimeText =
            context.tr('tomorrow_at_fmt', params: {'time': timeStr});
      } else {
        nextTimeText = context.tr('date_at_time_fmt', params: {
          'date': context.formatDate(nextOccur,
              includeWeekday: false, includeYear: false),
          'time': timeStr,
        });
      }
    } else if (reminder.status == ReminderStatus.expired) {
      nextTimeText = context.tr('status_expired');
    }

    String repeatText;
    if (reminder.repeatGapHours == 24 || reminder.repeatGapHours <= 0) {
      repeatText = context.tr('repeat_once_daily');
    } else {
      repeatText = context.tr(
        'repeat_every_hours',
        params: {'count': '${reminder.repeatGapHours}'},
      );
    }

    // Meal timing string
    String? mealText;
    if (reminder.mealTiming != null) {
      switch (reminder.mealTiming!) {
        case MealTiming.beforeMeal:
          mealText = context.tr('before_meal');
          break;
        case MealTiming.afterMeal:
          mealText = context.tr('after_meal');
          break;
        case MealTiming.withMeal:
          mealText = context.tr('with_meal');
          break;
        case MealTiming.noMeal:
          mealText = null;
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E433E) : const Color(0xFFD6E6E1),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF182825) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Title + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.medicineName ?? reminder.title,
                              style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF132B27),
                              ),
                            ),
                          ),
                          _buildStatusBadge(context, reminder.status, isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (reminder.type == ReminderType.medicine &&
                          reminder.doseQuantity != null)
                        Text(
                          '${reminder.doseQuantity}${mealText != null ? ' • $mealText' : ''}',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF80CBC4)
                                : const Color(0xFF00796B),
                          ),
                        ),
                      if (reminder.type == ReminderType.hydration &&
                          reminder.waterQuantity != null)
                        Text(
                          reminder.waterQuantity!,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0288D1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.8),
            const SizedBox(height: 12),

            // Next Reminder Row
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('next_reminder', params: {'time': nextTimeText}),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                Text(
                  repeatText,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            // Duration / End Date & Caregiver details
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 15,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    reminder.endDateTime != null
                        ? context.tr('ends_date_fmt', params: {
                            'date': context.formatDate(reminder.endDateTime!,
                                includeWeekday: false, includeYear: true)
                          })
                        : context.tr('started_date_fmt', params: {
                            'date': context.formatDate(reminder.startDateTime,
                                includeWeekday: false, includeYear: false)
                          }),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'By ${reminder.caregiverName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    ReminderStatus status,
    bool isDark,
  ) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ReminderStatus.active:
        bg = const Color(0xFF10B981).withValues(alpha: 0.16);
        fg = const Color(0xFF059669);
        label = context.tr('status_active');
        break;
      case ReminderStatus.upcoming:
        bg = const Color(0xFF0288D1).withValues(alpha: 0.16);
        fg = const Color(0xFF0288D1);
        label = context.tr('status_upcoming');
        break;
      case ReminderStatus.expired:
        bg = Colors.grey.withValues(alpha: 0.18);
        fg = isDark ? Colors.white60 : const Color(0xFF64748B);
        label = context.tr('status_expired');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
