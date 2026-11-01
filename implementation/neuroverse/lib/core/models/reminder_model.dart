import 'package:cloud_firestore/cloud_firestore.dart';

enum ReminderType { dailyActivity, medicine, hydration }

enum MealTiming { beforeMeal, afterMeal, withMeal, noMeal }

enum ReminderStatus { active, upcoming, expired }

class ReminderModel {
  final String id;
  final String patientId;
  final String caregiverId;
  final String caregiverName;
  final ReminderType type;
  final String title;
  final String? medicineName;
  final String? doseQuantity;
  final MealTiming? mealTiming;
  final String? waterQuantity;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final int repeatGapHours;
  final bool isActive;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    required this.caregiverName,
    required this.type,
    required this.title,
    this.medicineName,
    this.doseQuantity,
    this.mealTiming,
    this.waterQuantity,
    required this.startDateTime,
    this.endDateTime,
    required this.repeatGapHours,
    this.isActive = true,
    required this.createdAt,
  });

  /// Computes the current lifecycle status of the reminder
  ReminderStatus get status {
    if (!isActive) return ReminderStatus.expired;
    final now = DateTime.now();
    if (endDateTime != null && now.isAfter(endDateTime!)) {
      return ReminderStatus.expired;
    }
    if (now.isBefore(startDateTime)) {
      return ReminderStatus.upcoming;
    }
    return ReminderStatus.active;
  }

  /// Calculates the next upcoming occurrence after [from] (defaults to DateTime.now())
  DateTime? getNextOccurrence([DateTime? from]) {
    if (!isActive) return null;
    final base = from ?? DateTime.now();

    if (endDateTime != null && base.isAfter(endDateTime!)) {
      return null;
    }

    if (base.isBefore(startDateTime)) {
      return startDateTime;
    }

    final gapHours = repeatGapHours <= 0 ? 24 : repeatGapHours;
    final diffMilliseconds = base.difference(startDateTime).inMilliseconds;
    final intervalMilliseconds = Duration(hours: gapHours).inMilliseconds;

    final steps = (diffMilliseconds / intervalMilliseconds).floor();
    var candidate = startDateTime.add(
      Duration(milliseconds: (steps + 1) * intervalMilliseconds),
    );

    if (candidate.isBefore(base) || candidate.isAtSameMomentAs(base)) {
      candidate = candidate.add(Duration(hours: gapHours));
    }

    if (endDateTime != null && candidate.isAfter(endDateTime!)) {
      return null;
    }

    return candidate;
  }

  /// Calculates scheduled slot trigger times starting from [from] or now, up to [maxDays] ahead
  List<DateTime> getScheduledSlots({
    DateTime? from,
    int maxDays = 7,
    int maxSlots = 50,
  }) {
    if (!isActive) return [];
    final now = from ?? DateTime.now();

    if (endDateTime != null && now.isAfter(endDateTime!)) {
      return [];
    }

    final cutoff = now.add(Duration(days: maxDays));
    final effectiveEnd = endDateTime != null && endDateTime!.isBefore(cutoff)
        ? endDateTime!
        : cutoff;

    final gapHours = repeatGapHours <= 0 ? 24 : repeatGapHours;
    final interval = Duration(hours: gapHours);

    final List<DateTime> slots = [];
    var current = startDateTime;

    // Fast-forward to the first slot at or after now
    if (current.isBefore(now)) {
      final diffMs = now.difference(startDateTime).inMilliseconds;
      final stepMs = interval.inMilliseconds;
      final steps = (diffMs / stepMs).floor();
      current = startDateTime.add(Duration(milliseconds: steps * stepMs));
      while (current.isBefore(now)) {
        current = current.add(interval);
      }
    }

    while (!current.isAfter(effectiveEnd) && slots.length < maxSlots) {
      slots.add(current);
      current = current.add(interval);
    }

    return slots;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'caregiverId': caregiverId,
      'caregiverName': caregiverName,
      'type': type.name,
      'title': title,
      'medicineName': medicineName,
      'doseQuantity': doseQuantity,
      'mealTiming': mealTiming?.name,
      'waterQuantity': waterQuantity,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'repeatGapHours': repeatGapHours,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {}
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        try {
          return DateTime.parse(val);
        } catch (_) {}
      }
      return null;
    }

    ReminderType parseType(String? val) {
      switch (val) {
        case 'medicine':
          return ReminderType.medicine;
        case 'hydration':
          return ReminderType.hydration;
        case 'dailyActivity':
        default:
          return ReminderType.dailyActivity;
      }
    }

    MealTiming? parseMealTiming(String? val) {
      if (val == null) return null;
      for (final item in MealTiming.values) {
        if (item.name == val) return item;
      }
      return null;
    }

    return ReminderModel(
      id: (docId != null && docId.isNotEmpty)
          ? docId
          : (map['id']?.toString() ?? ''),
      patientId: map['patientId']?.toString() ?? '',
      caregiverId: map['caregiverId']?.toString() ?? '',
      caregiverName: map['caregiverName']?.toString() ?? 'Caregiver',
      type: parseType(map['type']?.toString()),
      title: map['title']?.toString() ?? '',
      medicineName: map['medicineName']?.toString(),
      doseQuantity: map['doseQuantity']?.toString(),
      mealTiming: parseMealTiming(map['mealTiming']?.toString()),
      waterQuantity: map['waterQuantity']?.toString(),
      startDateTime: parseDate(map['startDateTime'], DateTime.now()),
      endDateTime: parseNullableDate(map['endDateTime']),
      repeatGapHours: (map['repeatGapHours'] as num?)?.toInt() ?? 24,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDate(map['createdAt'], DateTime.now()),
    );
  }

  factory ReminderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReminderModel.fromMap(data, doc.id);
  }

  ReminderModel copyWith({
    String? id,
    String? patientId,
    String? caregiverId,
    String? caregiverName,
    ReminderType? type,
    String? title,
    String? medicineName,
    String? doseQuantity,
    MealTiming? mealTiming,
    String? waterQuantity,
    DateTime? startDateTime,
    DateTime? endDateTime,
    int? repeatGapHours,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      caregiverId: caregiverId ?? this.caregiverId,
      caregiverName: caregiverName ?? this.caregiverName,
      type: type ?? this.type,
      title: title ?? this.title,
      medicineName: medicineName ?? this.medicineName,
      doseQuantity: doseQuantity ?? this.doseQuantity,
      mealTiming: mealTiming ?? this.mealTiming,
      waterQuantity: waterQuantity ?? this.waterQuantity,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      repeatGapHours: repeatGapHours ?? this.repeatGapHours,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
