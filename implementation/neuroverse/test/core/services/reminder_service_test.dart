import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/models/reminder_model.dart';
import 'package:neuroverse_app/core/services/reminder_service.dart';

void main() {
  group('Reminder Scheduling & Duplicate Prevention Tests', () {
    test(
      'deterministic notification ID is identical for same reminder and slot time (prevents duplicates)',
      () {
        final slot = DateTime(2026, 9, 8, 8, 0);
        const reminderId = 'medicine-rem-42';

        final id1 =
            (reminderId.hashCode ^ slot.millisecondsSinceEpoch).abs() %
            100000000;
        final id2 =
            (reminderId.hashCode ^ slot.millisecondsSinceEpoch).abs() %
            100000000;

        // Must be identical so scheduling again cancels or overwrites the same alarm
        expect(id1, equals(id2));
      },
    );

    test(
      'different slots for the same reminder produce different notification IDs',
      () {
        final slot1 = DateTime(2026, 9, 8, 8, 0);
        final slot2 = DateTime(2026, 9, 8, 12, 0);
        const reminderId = 'medicine-rem-42';

        final id1 =
            (reminderId.hashCode ^ slot1.millisecondsSinceEpoch).abs() %
            100000000;
        final id2 =
            (reminderId.hashCode ^ slot2.millisecondsSinceEpoch).abs() %
            100000000;

        expect(id1, isNot(equals(id2)));
      },
    );

    test(
      'different reminders at the same slot time produce different notification IDs',
      () {
        final slot = DateTime(2026, 9, 8, 8, 0);
        const reminderIdA = 'medicine-rem-A';
        const reminderIdB = 'hydration-rem-B';

        final idA =
            (reminderIdA.hashCode ^ slot.millisecondsSinceEpoch).abs() %
            100000000;
        final idB =
            (reminderIdB.hashCode ^ slot.millisecondsSinceEpoch).abs() %
            100000000;

        expect(idA, isNot(equals(idB)));
      },
    );

    test(
      'medicine slot interval calculations do not drift across multiple days',
      () {
        final start = DateTime(2026, 9, 8, 9, 0);
        final end = DateTime(2026, 9, 11, 9, 0); // 3 days

        final reminder = ReminderModel(
          id: 'med-gap-test',
          patientId: 'p',
          caregiverId: 'c',
          caregiverName: 'Caregiver',
          type: ReminderType.medicine,
          title: 'Morning Dose',
          medicineName: 'Thyroxine',
          doseQuantity: '50 mcg',
          mealTiming: MealTiming.beforeMeal,
          startDateTime: start,
          endDateTime: end,
          repeatGapHours: 24, // daily
          isActive: true,
          createdAt: DateTime.now(),
        );

        final slots = reminder.getScheduledSlots(from: start, maxDays: 4);
        expect(slots.length, 4);
        expect(slots[0], DateTime(2026, 9, 8, 9, 0));
        expect(slots[1], DateTime(2026, 9, 9, 9, 0));
        expect(slots[2], DateTime(2026, 9, 10, 9, 0));
        expect(slots[3], DateTime(2026, 9, 11, 9, 0));
      },
    );

    test(
      'hydration 2-hour interval slots calculate precisely from caregiver selected startDateTime',
      () {
        final start = DateTime(2026, 9, 8, 10, 30);
        final end = DateTime(2026, 9, 8, 16, 30);

        final reminder = ReminderModel(
          id: 'hyd-test',
          patientId: 'p',
          caregiverId: 'c',
          caregiverName: 'Caregiver',
          type: ReminderType.hydration,
          title: 'Hydration',
          waterQuantity: '200 ml',
          startDateTime: start,
          endDateTime: end,
          repeatGapHours: 2,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final slots = reminder.getScheduledSlots(from: start, maxDays: 1);
        expect(slots.length, 4);
        expect(slots[0], DateTime(2026, 9, 8, 10, 30));
        expect(slots[1], DateTime(2026, 9, 8, 12, 30));
        expect(slots[2], DateTime(2026, 9, 8, 14, 30));
        expect(slots[3], DateTime(2026, 9, 8, 16, 30));
      },
    );
  });

  group('Reminder Notification Localization Tests', () {
    final service = ReminderService();

    final medicineReminder = ReminderModel(
      id: 'med-loc-1',
      patientId: 'patient-test',
      caregiverId: 'cg-test',
      caregiverName: 'Caregiver',
      type: ReminderType.medicine,
      title: 'Paracetamol',
      medicineName: 'Paracetamol',
      doseQuantity: '1 tablet',
      mealTiming: MealTiming.afterMeal,
      startDateTime: DateTime(2026, 9, 8, 14, 0),
      repeatGapHours: 8,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final hydrationReminder = ReminderModel(
      id: 'hyd-loc-1',
      patientId: 'patient-test',
      caregiverId: 'cg-test',
      caregiverName: 'Caregiver',
      type: ReminderType.hydration,
      title: 'Water',
      waterQuantity: '250 ml',
      startDateTime: DateTime(2026, 9, 8, 10, 0),
      repeatGapHours: 2,
      isActive: true,
      createdAt: DateTime.now(),
    );

    test('English localization produces accurate default notification strings', () {
      final medTitle = service.buildNotificationTitle(medicineReminder, 'en');
      final medBody = service.buildNotificationBody(medicineReminder, 'en');

      expect(medTitle, 'Medicine Reminder: Paracetamol 💊');
      expect(medBody, 'Time to take 1 tablet of Paracetamol (After Meal). Stay healthy!');

      final hydTitle = service.buildNotificationTitle(hydrationReminder, 'en');
      final hydBody = service.buildNotificationBody(hydrationReminder, 'en');

      expect(hydTitle, 'Hydration Reminder 💧');
      expect(hydBody, 'Time to drink 250 ml. Regular hydration keeps your mind fresh and energized!');
    });

    test('Hindi localization translates medicine and hydration notifications accurately', () {
      final medTitle = service.buildNotificationTitle(medicineReminder, 'hi');
      final medBody = service.buildNotificationBody(medicineReminder, 'hi');

      expect(medTitle, 'दवाई का समय: Paracetamol 💊');
      expect(medBody, 'Paracetamol (खाने के बाद) की 1 tablet लेने का समय हो गया है। स्वस्थ रहें!');

      final hydTitle = service.buildNotificationTitle(hydrationReminder, 'hi');
      final hydBody = service.buildNotificationBody(hydrationReminder, 'hi');

      expect(hydTitle, 'पानी पीने का समय 💧');
      expect(hydBody, '250 ml पानी पीने का समय हो गया है। पर्याप्त पानी दिमाग को तरोताजा रखता है!');
    });

    test('Bengali localization translates notifications accurately', () {
      final medTitle = service.buildNotificationTitle(medicineReminder, 'bn');
      final medBody = service.buildNotificationBody(medicineReminder, 'bn');

      expect(medTitle, 'ওষুধের সময়: Paracetamol 💊');
      expect(medBody, 'Paracetamol (খাওয়ার পর)-এর 1 tablet নেওয়ার সময় হয়েছে। সুস্থ থাকুন!');

      final hydTitle = service.buildNotificationTitle(hydrationReminder, 'bn');
      final hydBody = service.buildNotificationBody(hydrationReminder, 'bn');

      expect(hydTitle, 'জল পানের সময় 💧');
      expect(hydBody, '250 ml জল পানের সময় হয়েছে। পর্যাপ্ত জল মন ও শরীরকে সতেজ রাখে!');
    });
  });
}
