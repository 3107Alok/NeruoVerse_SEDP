import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';
import 'notification_service.dart';
import '../../data/local/hive_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // In-memory registry of scheduled notification IDs per reminder: reminderId -> Set<int>
  final Map<String, Set<int>> _scheduledAlarmIds = {};

  Future<void> init() async {
    // Ensure notifications and timezone system are ready
    try {
      await _notificationService.init();
    } catch (e) {
      debugPrint('ReminderService init notice: $e');
    }
  }

  /// One-time sync on patient app open:
  /// 1. Fetches active reminders from Firestore (users/{patientId}/reminders where isActive == true)
  /// 2. Cancels obsolete or removed alarms
  /// 3. Computes exact upcoming slots from preserved startDateTime to endDateTime
  /// 4. Schedules native Android exact alarms with exactAllowWhileIdle and sound
  /// 5. Strictly prevents duplicate alarms via deterministic notification IDs
  Future<void> syncAndSchedulePatientReminders(String patientId) async {
    if (patientId.isEmpty) return;

    try {
      debugPrint('Starting one-time Reminder sync for patient: $patientId');
      final querySnapshot = await _firestore
          .collection('users')
          .doc(patientId)
          .collection('reminders')
          .where('isActive', isEqualTo: true)
          .get();

      final List<ReminderModel> activeReminders = querySnapshot.docs
          .map((doc) => ReminderModel.fromFirestore(doc))
          .where((r) => r.status != ReminderStatus.expired)
          .toList();

      final activeReminderIds = activeReminders.map((r) => r.id).toSet();

      // 1. Cancel alarms for any reminder that is no longer active or was deleted
      final List<String> remindersToCancel = _scheduledAlarmIds.keys
          .where((id) => !activeReminderIds.contains(id))
          .toList();

      for (final id in remindersToCancel) {
        await cancelReminderAlarms(id);
      }

      // 2. Schedule upcoming slots for each active reminder
      for (final reminder in activeReminders) {
        await _scheduleSlotsForReminder(reminder);
      }

      debugPrint(
        'Reminder sync completed. Active reminders synced: ${activeReminders.length}',
      );
    } catch (e) {
      debugPrint('Error syncing patient reminders from Firestore: $e');
    }
  }

  /// Calculates upcoming slots starting from preserved startDateTime and registers exact alarms
  Future<void> _scheduleSlotsForReminder(ReminderModel reminder) async {
    // First cancel any existing registered alarms for this reminder to avoid duplicates
    final existingIds = _scheduledAlarmIds[reminder.id] ?? <int>{};
    for (final notifId in existingIds) {
      await _notificationService.cancelNotification(notifId);
    }
    existingIds.clear();

    // Get up to 7 days of upcoming slots based on startDateTime and repeatGapHours
    final slots = reminder.getScheduledSlots(maxDays: 7, maxSlots: 35);
    if (slots.isEmpty) return;

    final langCode = _getPatientLanguageCode();
    final title = _buildNotificationTitle(reminder, langCode);
    final body = _buildNotificationBody(reminder, langCode);

    for (final slot in slots) {
      // Deterministic notification ID derived from reminder.id and slot timestamp
      final int notifId =
          (reminder.id.hashCode ^ slot.millisecondsSinceEpoch).abs() %
          100000000;

      await _notificationService.scheduleExactAlarm(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: slot,
        payload: 'reminder:${reminder.id}',
      );

      existingIds.add(notifId);
    }

    _scheduledAlarmIds[reminder.id] = existingIds;
    debugPrint(
      'Scheduled ${existingIds.length} exact alarms for reminder: ${reminder.title} (${reminder.id})',
    );
  }

  /// Cancels all scheduled local alarms for a given reminder
  Future<void> cancelReminderAlarms(String reminderId) async {
    final ids = _scheduledAlarmIds.remove(reminderId);
    if (ids != null) {
      for (final notifId in ids) {
        await _notificationService.cancelNotification(notifId);
      }
      debugPrint('Cancelled ${ids.length} alarms for reminder: $reminderId');
    }
  }

  /// Saves or updates a reminder in Firestore
  Future<void> saveReminder(ReminderModel reminder) async {
    try {
      await _firestore
          .collection('users')
          .doc(reminder.patientId)
          .collection('reminders')
          .doc(reminder.id)
          .set(reminder.toMap(), SetOptions(merge: true));

      // If active, schedule locally on this device as well
      if (reminder.isActive && reminder.status != ReminderStatus.expired) {
        await _scheduleSlotsForReminder(reminder);
      } else {
        await cancelReminderAlarms(reminder.id);
      }
    } catch (e) {
      debugPrint('Error saving reminder to Firestore: $e');
      rethrow;
    }
  }

  /// Toggles reminder active status in Firestore
  Future<void> toggleReminderActive(
    String patientId,
    String reminderId,
    bool isActive,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(patientId)
          .collection('reminders')
          .doc(reminderId)
          .update({'isActive': isActive});

      if (!isActive) {
        await cancelReminderAlarms(reminderId);
      } else {
        final doc = await _firestore
            .collection('users')
            .doc(patientId)
            .collection('reminders')
            .doc(reminderId)
            .get();
        if (doc.exists) {
          final reminder = ReminderModel.fromFirestore(doc);
          await _scheduleSlotsForReminder(reminder);
        }
      }
    } catch (e) {
      debugPrint('Error toggling reminder status: $e');
      rethrow;
    }
  }

  /// Deletes a reminder from Firestore and cancels any scheduled alarms
  Future<void> deleteReminder(String patientId, String reminderId) async {
    try {
      await _firestore
          .collection('users')
          .doc(patientId)
          .collection('reminders')
          .doc(reminderId)
          .delete();

      await cancelReminderAlarms(reminderId);
    } catch (e) {
      debugPrint('Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Stream of reminders for a patient from Firestore
  Stream<List<ReminderModel>> getPatientRemindersStream(String patientId) {
    if (patientId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(patientId)
        .collection('reminders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReminderModel.fromFirestore(doc))
              .toList(),
        );
  }

  String buildNotificationTitle(ReminderModel reminder, [String? langCode]) =>
      _buildNotificationTitle(reminder, langCode);

  String buildNotificationBody(ReminderModel reminder, [String? langCode]) =>
      _buildNotificationBody(reminder, langCode);

  String _normalizeLang(String? lang) {
    if (lang == null) return 'en';
    final l = lang.trim().toLowerCase();
    if (l == 'hi' || l == 'hindi' || l == 'हिंदी') return 'hi';
    if (l == 'bn' || l == 'bengali' || l == 'বাংলা') return 'bn';
    if (l == 'as' || l == 'assamese' || l == 'অসমীয়া') return 'as';
    if (l == 'mni' || l == 'manipuri' || l == 'মৈতৈলোন') return 'mni';
    if (l == 'miz' || l == 'mizo') return 'miz';
    return 'en';
  }

  String _getPatientLanguageCode() {
    try {
      final profile = HiveService().getUserProfile();
      final lang = profile?['language']?.toString();
      return _normalizeLang(lang);
    } catch (_) {
      return 'en';
    }
  }

  String _getMealTimingText(MealTiming? timing, String lang) {
    if (timing == null || timing == MealTiming.noMeal) return '';
    switch (lang) {
      case 'hi':
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (खाने से पहले)';
          case MealTiming.afterMeal:
            return ' (खाने के बाद)';
          case MealTiming.withMeal:
            return ' (खाने के साथ)';
          case MealTiming.noMeal:
            return '';
        }
      case 'bn':
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (খাওয়ার আগে)';
          case MealTiming.afterMeal:
            return ' (খাওয়ার পর)';
          case MealTiming.withMeal:
            return ' (খাবারের সাথে)';
          case MealTiming.noMeal:
            return '';
        }
      case 'as':
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (খোৱাৰ আগত)';
          case MealTiming.afterMeal:
            return ' (খোৱাৰ পিছত)';
          case MealTiming.withMeal:
            return ' (খোৱাৰ লগত)';
          case MealTiming.noMeal:
            return '';
        }
      case 'mni':
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (চাক চাদ্রিঙেয়দা)';
          case MealTiming.afterMeal:
            return ' (চাক চাবা লোইবা মতমদা)';
          case MealTiming.withMeal:
            return ' (চাক্কা লোয়ননা)';
          case MealTiming.noMeal:
            return '';
        }
      case 'miz':
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (Chaw ei hma)';
          case MealTiming.afterMeal:
            return ' (Chaw ei hnu)';
          case MealTiming.withMeal:
            return ' (Chaw ei laia)';
          case MealTiming.noMeal:
            return '';
        }
      default: // en
        switch (timing) {
          case MealTiming.beforeMeal:
            return ' (Before Meal)';
          case MealTiming.afterMeal:
            return ' (After Meal)';
          case MealTiming.withMeal:
            return ' (With Meal)';
          case MealTiming.noMeal:
            return '';
        }
    }
  }

  String _buildNotificationTitle(ReminderModel reminder, [String? langCode]) {
    final lang = langCode ?? _getPatientLanguageCode();
    switch (reminder.type) {
      case ReminderType.medicine:
        final name = reminder.medicineName?.isNotEmpty == true
            ? reminder.medicineName!
            : reminder.title;
        switch (lang) {
          case 'hi':
            return 'दवाई का समय: $name 💊';
          case 'bn':
            return 'ওষুধের সময়: $name 💊';
          case 'as':
            return 'ঔষধৰ সময়: $name 💊';
          case 'mni':
            return 'হিদাক চাবগী মতম: $name 💊';
          case 'miz':
            return 'Damdawi ei hun: $name 💊';
          default:
            return 'Medicine Reminder: $name 💊';
        }
      case ReminderType.hydration:
        switch (lang) {
          case 'hi':
            return 'पानी पीने का समय 💧';
          case 'bn':
            return 'জল পানের সময় 💧';
          case 'as':
            return 'পানী খোৱাৰ সময় 💧';
          case 'mni':
            return 'ঈশিং থকপগী মতম 💧';
          case 'miz':
            return 'Tui in hun 💧';
          default:
            return 'Hydration Reminder 💧';
        }
      case ReminderType.dailyActivity:
        switch (lang) {
          case 'hi':
            return 'दैनिक दिमागी अभ्यास 🧠';
          case 'bn':
            return 'দৈনিক মস্তিষ্কের ব্যায়াম 🧠';
          case 'as':
            return 'দৈনিক মগজুৰ অনুশীলন 🧠';
          case 'mni':
            return 'নোংমগী ৱাখলগী এক্সারসাইজ 🧠';
          case 'miz':
            return 'Ni tin thluak insawizawina 🧠';
          default:
            return 'Daily Brain Training 🧠';
        }
    }
  }

  String _buildNotificationBody(ReminderModel reminder, [String? langCode]) {
    final lang = langCode ?? _getPatientLanguageCode();
    switch (reminder.type) {
      case ReminderType.medicine:
        final dose = reminder.doseQuantity?.isNotEmpty == true
            ? reminder.doseQuantity!
            : 'prescribed dose';
        final medName = reminder.medicineName ?? reminder.title;
        final meal = _getMealTimingText(reminder.mealTiming, lang);

        switch (lang) {
          case 'hi':
            return '$medName$meal की $dose लेने का समय हो गया है। स्वस्थ रहें!';
          case 'bn':
            return '$medName$meal-এর $dose নেওয়ার সময় হয়েছে। সুস্থ থাকুন!';
          case 'as':
            return '$medName$meal ৰ $dose লোৱাৰ সময় হৈছে। সুস্থ থাকক!';
          case 'mni':
            return '$medName$meal গী $dose চাবগী মতম ওইরে। নশাগী য়েংশিনবিউ!';
          case 'miz':
            return '$medName$meal $dose ei a hun e. Hrisel takin awm rawh!';
          default:
            return 'Time to take $dose of $medName$meal. Stay healthy!';
        }

      case ReminderType.hydration:
        final amount = reminder.waterQuantity?.isNotEmpty == true
            ? reminder.waterQuantity!
            : 'a glass of water';
        switch (lang) {
          case 'hi':
            return '$amount पानी पीने का समय हो गया है। पर्याप्त पानी दिमाग को तरोताजा रखता है!';
          case 'bn':
            return '$amount জল পানের সময় হয়েছে। পর্যাপ্ত জল মন ও শরীরকে সতেজ রাখে!';
          case 'as':
            return '$amount পানী খোৱাৰ সময় হৈছে। নিয়মীয়া পানীয়ে মন সতেজ ৰাখে!';
          case 'mni':
            return '$amount ঈশিং থকপগী মতম ওইরে। ঈশিং থকপনা পুক্নীং নুংশিলহল্লী!';
          case 'miz':
            return '$amount in a hun e. Tui in tam hian thluak a ti harhvang ṭhin!';
          default:
            return 'Time to drink $amount. Regular hydration keeps your mind fresh and energized!';
        }

      case ReminderType.dailyActivity:
        switch (lang) {
          case 'hi':
            return 'आज के दिमागी अभ्यास का समय हो गया है! दिमाग को चुस्त रखने के लिए 3 मिनट दें।';
          case 'bn':
            return 'আজকের মস্তিষ্কের ব্যায়ামের সময় হয়েছে! মন তীক্ষ্ণ রাখতে ৩ মিনিট সময় দিন।';
          case 'as':
            return 'আজিৰ মগজুৰ অনুশীলনৰ সময় হৈছে! মগজু সতেজ ৰাখিবলৈ ৩ মিনিট সময় দিয়ক।';
          case 'mni':
            return 'ঙসিগী ৱাখলগী এক্সারসাইজকী মতম ওইরে! ৱাখল শেংহনবদা মিনিট ৩ কত্তোকউ।';
          case 'miz':
            return 'Ni tin thluak exercise neih a hun e! Thluak ti chak turin minute 3 hmang rawh.';
          default:
            return 'Time for your daily cognitive exercises! Spend 3 minutes to keep your mind sharp.';
        }
    }
  }
}
