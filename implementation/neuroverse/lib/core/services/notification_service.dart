import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/local/hive_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // Initialize local timezones for scheduling exact reminders in the user's real timezone
    try {
      tz.initializeTimeZones();
      final Duration offset = DateTime.now().timeZoneOffset;
      tz.Location? localLoc;

      // 1. Check for standard Indian Standard Time (+5:30 / 330 mins)
      if (offset.inMinutes == 330) {
        try {
          localLoc = tz.getLocation('Asia/Kolkata');
        } catch (_) {}
      }

      // 2. Try device timeZoneName
      if (localLoc == null) {
        try {
          localLoc = tz.getLocation(DateTime.now().timeZoneName);
        } catch (_) {}
      }

      // 3. Match from database by exact offset
      if (localLoc == null) {
        final nowUtc = DateTime.now().toUtc();
        for (final loc in tz.timeZoneDatabase.locations.values) {
          final tzTime = tz.TZDateTime.from(nowUtc, loc);
          if (Duration(milliseconds: tzTime.timeZoneOffset.inMilliseconds) == offset) {
            localLoc = loc;
            break;
          }
        }
      }

      if (localLoc != null) {
        tz.setLocalLocation(localLoc);
        debugPrint('Notification local timezone set to: ${localLoc.name} (offset: ${offset.inHours}h ${offset.inMinutes % 60}m)');
      }
    } catch (e) {
      debugPrint('Timezone initialization note: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // Request permissions for Android 13+ (POST_NOTIFICATIONS) and Exact Alarms
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();

      const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
        'reminders_alarm_channel',
        'Medicine & Hydration Reminders',
        description: 'Scheduled alerts for medicines, hydration, and daily activities',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidImplementation?.createNotificationChannel(remindersChannel);

      const AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
        'emergency_sos_channel',
        'Emergency SOS Alerts',
        description: 'Urgent emergency alerts from connected patients',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      await androidImplementation?.createNotificationChannel(sosChannel);
    } catch (e) {
      debugPrint('Notification/alarm permission request note: $e');
    }

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    _isInitialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    final isEmergency = title.toUpperCase().contains('EMERGENCY') ||
        title.toUpperCase().contains('SOS') ||
        title.contains('🚨') ||
        (payload?.startsWith('sos_') ?? false);

    // Quiet hours guard: Never disturb users between 10:00 PM and 7:00 AM for non-critical notifications
    final currentHour = DateTime.now().hour;
    if (!isEmergency && (currentHour >= 22 || currentHour < 7)) {
      debugPrint('Suppressing non-critical notification during quiet hours ($currentHour:00).');
      return;
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics = isEmergency
        ? const AndroidNotificationDetails(
            'emergency_sos_channel',
            'Emergency SOS Alerts',
            channelDescription: 'Urgent emergency alerts from connected patients',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
            fullScreenIntent: true,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/launcher_icon',
          )
        : const AndroidNotificationDetails(
            'neuroverse_channel_id',
            'NeuroVerse Alerts',
            channelDescription: 'Notifications for caregiver requests and smart alerts',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/launcher_icon',
          );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    
    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // If the scheduled time has already passed today, schedule for TOMORROW
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

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

  /// Schedules daily morning reminder (defaults to 9:00 AM local time every single morning)
  Future<void> scheduleDailyReminder({int hour = 9, int minute = 0, String? langCode}) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily morning brain training exercises reminder',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Cancel old reminder with ID 999 to prevent duplicate notifications
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: 999);
    } catch (_) {}

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final lang = langCode ?? _getPatientLanguageCode();
    String title = 'Daily Brain Training 🧠';
    String body = 'Good morning! Ready for your quick cognitive exercises today? Let\'s keep your mind sharp!';

    switch (lang) {
      case 'hi':
        title = 'दैनिक दिमागी अभ्यास 🧠';
        body = 'सुप्रभात! आज के आसान दिमागी अभ्यास के लिए तैयार हैं? चलिए दिमाग को चुस्त रखते हैं!';
        break;
      case 'bn':
        title = 'দৈনিক মস্তিষ্কের ব্যায়াম 🧠';
        body = 'সুপ্রভাত! আজকের সহজ মস্তিষ্কের অনুশীলনের জন্য প্রস্তুত? আসুন মনকে সতেজ রাখি!';
        break;
      case 'as':
        title = 'দৈনিক মগজুৰ অনুশীলন 🧠';
        body = 'সুপ্ৰভাত! আজিৰ সহজ মগজুৰ অনুশীলনৰ বাবে সাজুনে? মগজু সতেজ ৰাখক!';
        break;
      case 'mni':
        title = 'নোংমগী ৱাখলগী এক্সারসাইজ 🧠';
        body = 'অয়ুক্কী য়াইফ-পাউজেল! ঙসিগী ৱাখলগী এক্সারসাইজকীদমক শেম-শারেব্রা? ৱাখল কাওখন্দনা লৈহন্সি!';
        break;
      case 'miz':
        title = 'Ni tin thluak insawizawina 🧠';
        body = 'Zing chibai! Vawiin thluak insawizawina ti turin i inpeih em? I thluak ti chak ang che!';
        break;
      default:
        break;
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: 999, // Fixed ID for morning reminder
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Exact daily repetition at 9:00 AM local time
      );
      debugPrint('Daily morning reminder scheduled for local: $scheduledDate ($lang)');
    } catch (e) {
      debugPrint('Error scheduling zoned daily morning reminder: $e');
    }
  }

  /// Schedules evening catch-up reminder (defaults to 7:00 PM / 19:00 local time)
  /// Triggers only if user hasn't completed exercises today.
  Future<void> scheduleEveningReminder({int hour = 19, int minute = 0, String? langCode}) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Daily evening workout reminder',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await _flutterLocalNotificationsPlugin.cancel(id: 998);
    } catch (_) {}

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final lang = langCode ?? _getPatientLanguageCode();
    String title = 'Evening Brain Workout 🌙';
    String body = 'A gentle reminder: You haven\'t completed today\'s brain exercises yet! Spend 3 minutes to keep your streak alive 🔥';

    switch (lang) {
      case 'hi':
        title = 'शाम का दिमागी अभ्यास 🌙';
        body = 'याद दिलाना: आपने आज का दिमागी अभ्यास पूरा नहीं किया है! अपनी स्ट्रीक जारी रखने के लिए 3 मिनट दें 🔥';
        break;
      case 'bn':
        title = 'সন্ধ্যার মস্তিষ্কের অনুশীলন 🌙';
        body = 'একটি অনুস্মারক: আপনি আজকের অনুশীলন এখনও সম্পন্ন করেননি! স্ট্রিক বজায় রাখতে ৩ মিনিট ব্যয় করুন 🔥';
        break;
      case 'as':
        title = 'সন্ধিয়াৰ মগজুৰ অনুশীলন 🌙';
        body = 'এয়া এক সোঁৱৰণী: আপুনি আজিৰ অনুশীলন সম্পূৰ্ণ কৰা নাই! ষ্ট্ৰীক বজাই ৰাখিবলৈ ৩ মিনিট সময় দিয়ক 🔥';
        break;
      case 'mni':
        title = 'নুমিদাংগী ৱাখলগী এক্সারসাইজ 🌙';
        body = 'নিংশিংবা পাউজেল: নহাক্না ঙসিগী এক্সারসাইজ লোইশিন্দ্রি! মিনিট ৩ কত্তোকউ 🔥';
        break;
      case 'miz':
        title = 'Zan thluak exercise 🌙';
        body = 'Hriattirna: Vawiin thluak exercise i la ti zo lo! Minute 3 chhung ti rawh le 🔥';
        break;
      default:
        break;
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: 998, // Fixed ID for evening reminder
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Exact daily repetition at 7:00 PM local time
      );
      debugPrint('Evening reminder scheduled for local: $scheduledDate ($lang)');
    } catch (e) {
      debugPrint('Error scheduling zoned evening reminder: $e');
    }
  }

  /// Cancels today's evening reminder once the patient plays/completes their workout!
  Future<void> cancelEveningReminder() async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: 998);
      debugPrint('Evening reminder cancelled because patient completed workout today.');
    } catch (e) {
      debugPrint('Error cancelling evening reminder: $e');
    }
  }

  /// Schedules both morning (9:00 AM local) and evening catch-up (7:00 PM local) reminders
  Future<void> scheduleDailyReminders() async {
    await scheduleDailyReminder(hour: 9, minute: 0);
    await scheduleEveningReminder(hour: 19, minute: 0);
  }

  /// Cancels a specific notification by integer ID
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error cancelling notification $id: $e');
    }
  }

  /// Schedules an exact native alarm using Android native AlarmManager exactAllowWhileIdle
  /// Triggering sound and high-priority heads-up popup even when idle or offline.
  Future<void> scheduleExactAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminders_alarm_channel',
      'Medicine & Hydration Reminders',
      channelDescription: 'Scheduled alerts for medicines, hydration, and daily activities',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: false,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // Cancel any previous notification with this exact ID first
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (_) {}

    // Convert DateTime to TZDateTime in local timezone
    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Guard: only schedule if in the future
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugPrint('Exact alarm [$id] successfully scheduled for: $tzDate');
    } catch (e) {
      debugPrint('Error scheduling zoned exact alarm [$id]: $e');
    }
  }
}

