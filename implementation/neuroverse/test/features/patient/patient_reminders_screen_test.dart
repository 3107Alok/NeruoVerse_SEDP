import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/models/reminder_model.dart';
import 'package:neuroverse_app/features/patient/reminders/patient_reminders_screen.dart';

void main() {
  Widget createTestWidget({
    ThemeMode themeMode = ThemeMode.light,
    Stream<List<ReminderModel>>? stream,
  }) {
    return ChangeNotifierProvider<AppProvider>(
      create: (_) => AppProvider()..userLanguage = 'en',
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: PatientRemindersScreen(
          patientIdOverride: 'mock-patient',
          remindersStreamOverride: stream ?? Stream.value([]),
        ),
      ),
    );
  }

  group('Patient Reminders Screen UI Tests', () {
    testWidgets('Renders app bar title, back button, and all 4 filter chips', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Medicine 💊'), findsOneWidget);
      expect(find.text('Hydration 💧'), findsOneWidget);
      expect(find.text('Daily Activities 🧠'), findsOneWidget);
    });

    testWidgets('Renders Daily Brain Training system card on All filter', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Daily Brain Training'), findsOneWidget);
      expect(
        find.text('Morning (9:00 AM) & Evening (7:00 PM) cognitive workouts'),
        findsOneWidget,
      );
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Daily (2x)'), findsOneWidget);
    });

    testWidgets(
      'Tapping Medicine filter switches tab and hides Daily Brain card',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap Medicine filter
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pumpAndSettle();

        // Daily Brain card should not appear under Medicine filter
        expect(find.text('Daily Brain Training'), findsNothing);

        // Shows empty state when no medicines in stream
        expect(find.text('No reminders found'), findsOneWidget);
        expect(
          find.text('Caregiver scheduled reminders will appear here.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping Hydration filter switches tab and shows empty state when none exist',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap Hydration filter
        await tester.tap(find.text('Hydration 💧'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No reminders found'), findsOneWidget);
        expect(find.text('Daily Brain Training'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Daily Activities filter restores Daily Brain Training card',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Switch to Medicine first
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Daily Brain Training'), findsNothing);

        // Switch to Daily Activities
        await tester.tap(find.text('Daily Activities 🧠'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Daily Brain Training'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders medicine cards with dose and meal timing when stream emits data',
      (tester) async {
        final mockReminders = [
          ReminderModel(
            id: 'med-1',
            patientId: 'mock-patient',
            caregiverId: 'cg-1',
            caregiverName: 'Dr. Sarah',
            type: ReminderType.medicine,
            title: 'Metformin',
            medicineName: 'Metformin',
            doseQuantity: '500 mg',
            mealTiming: MealTiming.afterMeal,
            startDateTime: DateTime.now().subtract(const Duration(days: 1)),
            endDateTime: DateTime.now().add(const Duration(days: 6)),
            repeatGapHours: 8,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(stream: Stream.value(mockReminders)),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Metformin'), findsOneWidget);
        expect(find.text('500 mg • After Meal'), findsOneWidget);
        expect(find.text('Every 8 hours'), findsOneWidget);
        expect(find.text('By Dr. Sarah'), findsOneWidget);
      },
    );

    testWidgets('Renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(createTestWidget(themeMode: ThemeMode.dark));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Daily Brain Training'), findsOneWidget);
    });

    testWidgets('Renders without overflow on narrow 320px viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });
  });
}
