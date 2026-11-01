import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/models/reminder_model.dart';

void main() {
  group('ReminderModel Tests', () {
    test('creates model and serializes to and from Map accurately', () {
      final start = DateTime(2026, 9, 8, 8, 30);
      final end = DateTime(2026, 9, 22, 23, 59, 59);
      final created = DateTime(2026, 9, 7, 10, 0);

      final model = ReminderModel(
        id: 'test-med-1',
        patientId: 'patient-123',
        caregiverId: 'cg-456',
        caregiverName: 'Dr. Sarah',
        type: ReminderType.medicine,
        title: 'Metformin 500mg',
        medicineName: 'Metformin',
        doseQuantity: '1 tablet',
        mealTiming: MealTiming.afterMeal,
        startDateTime: start,
        endDateTime: end,
        repeatGapHours: 8,
        isActive: true,
        createdAt: created,
      );

      final map = model.toMap();
      expect(map['id'], 'test-med-1');
      expect(map['patientId'], 'patient-123');
      expect(map['caregiverName'], 'Dr. Sarah');
      expect(map['type'], 'medicine');
      expect(map['medicineName'], 'Metformin');
      expect(map['doseQuantity'], '1 tablet');
      expect(map['mealTiming'], 'afterMeal');
      expect(map['repeatGapHours'], 8);
      expect(map['isActive'], isTrue);

      final reconstituted = ReminderModel.fromMap(map, 'test-med-1');
      expect(reconstituted.id, model.id);
      expect(reconstituted.patientId, model.patientId);
      expect(reconstituted.type, ReminderType.medicine);
      expect(reconstituted.medicineName, 'Metformin');
      expect(reconstituted.mealTiming, MealTiming.afterMeal);
      expect(reconstituted.repeatGapHours, 8);
      expect(reconstituted.startDateTime, start);
    });

    test('hydration model serializes waterQuantity accurately', () {
      final start = DateTime(2026, 9, 8, 7, 0);
      final model = ReminderModel(
        id: 'test-hyd-1',
        patientId: 'patient-123',
        caregiverId: 'cg-456',
        caregiverName: 'Nurse John',
        type: ReminderType.hydration,
        title: 'Hydration Reminder',
        waterQuantity: '250 ml',
        startDateTime: start,
        repeatGapHours: 2,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final map = model.toMap();
      expect(map['type'], 'hydration');
      expect(map['waterQuantity'], '250 ml');

      final reconstituted = ReminderModel.fromMap(map, 'test-hyd-1');
      expect(reconstituted.type, ReminderType.hydration);
      expect(reconstituted.waterQuantity, '250 ml');
      expect(reconstituted.repeatGapHours, 2);
    });

    test('computes status correctly: upcoming, active, and expired', () {
      final now = DateTime.now();

      // 1. Upcoming: start date is in the future
      final upcoming = ReminderModel(
        id: '1',
        patientId: 'p',
        caregiverId: 'c',
        caregiverName: 'Dr. S',
        type: ReminderType.medicine,
        title: 'M',
        startDateTime: now.add(const Duration(days: 2)),
        endDateTime: now.add(const Duration(days: 10)),
        repeatGapHours: 4,
        isActive: true,
        createdAt: now,
      );
      expect(upcoming.status, ReminderStatus.upcoming);

      // 2. Active: started in the past, ends in the future
      final active = ReminderModel(
        id: '2',
        patientId: 'p',
        caregiverId: 'c',
        caregiverName: 'Dr. S',
        type: ReminderType.medicine,
        title: 'M',
        startDateTime: now.subtract(const Duration(days: 1)),
        endDateTime: now.add(const Duration(days: 5)),
        repeatGapHours: 4,
        isActive: true,
        createdAt: now,
      );
      expect(active.status, ReminderStatus.active);

      // 3. Expired by endDateTime
      final expiredByEnd = ReminderModel(
        id: '3',
        patientId: 'p',
        caregiverId: 'c',
        caregiverName: 'Dr. S',
        type: ReminderType.medicine,
        title: 'M',
        startDateTime: now.subtract(const Duration(days: 10)),
        endDateTime: now.subtract(const Duration(days: 2)),
        repeatGapHours: 4,
        isActive: true,
        createdAt: now,
      );
      expect(expiredByEnd.status, ReminderStatus.expired);

      // 4. Expired by isActive == false
      final inactive = ReminderModel(
        id: '4',
        patientId: 'p',
        caregiverId: 'c',
        caregiverName: 'Dr. S',
        type: ReminderType.medicine,
        title: 'M',
        startDateTime: now.subtract(const Duration(days: 1)),
        endDateTime: now.add(const Duration(days: 5)),
        repeatGapHours: 4,
        isActive: false,
        createdAt: now,
      );
      expect(inactive.status, ReminderStatus.expired);
    });

    test(
      'getNextOccurrence preserves startDateTime and interval spacing accurately',
      () {
        final start = DateTime(2026, 9, 8, 8, 15);
        final model = ReminderModel(
          id: '1',
          patientId: 'p',
          caregiverId: 'c',
          caregiverName: 'Dr. S',
          type: ReminderType.medicine,
          title: 'Metformin',
          startDateTime: start,
          endDateTime: DateTime(2026, 9, 15, 23, 59),
          repeatGapHours: 4,
          isActive: true,
          createdAt: DateTime(2026, 9, 7),
        );

        // Before start: next occurrence is startDateTime
        final beforeStart = DateTime(2026, 9, 8, 6, 0);
        expect(model.getNextOccurrence(beforeStart), start);

        // Exactly at start: next occurrence is start + 4 hours (12:15)
        final atStart = DateTime(2026, 9, 8, 8, 15);
        expect(model.getNextOccurrence(atStart), DateTime(2026, 9, 8, 12, 15));

        // At 9:30 AM: next occurrence is 12:15 PM
        final midSlot = DateTime(2026, 9, 8, 9, 30);
        expect(model.getNextOccurrence(midSlot), DateTime(2026, 9, 8, 12, 15));

        // After endDateTime: returns null
        final afterEnd = DateTime(2026, 9, 16, 1, 0);
        expect(model.getNextOccurrence(afterEnd), isNull);
      },
    );

    test(
      'getScheduledSlots generates slots respecting repeatGapHours within end boundaries',
      () {
        final start = DateTime(2026, 9, 8, 8, 0);
        final end = DateTime(2026, 9, 9, 8, 0); // exactly 24 hours later

        final model = ReminderModel(
          id: '1',
          patientId: 'p',
          caregiverId: 'c',
          caregiverName: 'Dr. S',
          type: ReminderType.hydration,
          title: 'Water Intake',
          waterQuantity: '250 ml',
          startDateTime: start,
          endDateTime: end,
          repeatGapHours: 6,
          isActive: true,
          createdAt: DateTime(2026, 9, 7),
        );

        // From start: slots at 8:00, 14:00, 20:00, 02:00, 08:00 (5 slots)
        final slots = model.getScheduledSlots(from: start, maxDays: 2);
        expect(slots.length, 5);
        expect(slots[0], DateTime(2026, 9, 8, 8, 0));
        expect(slots[1], DateTime(2026, 9, 8, 14, 0));
        expect(slots[2], DateTime(2026, 9, 8, 20, 0));
        expect(slots[3], DateTime(2026, 9, 9, 2, 0));
        expect(slots[4], DateTime(2026, 9, 9, 8, 0));
      },
    );
  });
}
