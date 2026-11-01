import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/features/patient/home/patient_main_screen.dart';

void main() {
  Widget createTestWidget({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }

  group('Patient Caregiver Reminder Card Tests', () {
    testWidgets('Renders reminder title, description, and caregiver sender name', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Daily Memory Challenge',
          body: 'Time to practice your pattern skills!',
          senderName: 'Sarah Jenkins',
          isHighPriority: false,
          isRead: true,
          isDark: false,
          onPlayNow: () {},
        ),
      ));

      expect(find.text('Daily Memory Challenge'), findsOneWidget);
      expect(find.text('Time to practice your pattern skills!'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
    });

    testWidgets('Renders URGENT badge when isHighPriority is true', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Immediate Focus Workout',
          body: 'Please complete before dinner.',
          senderName: 'Dr. John',
          isHighPriority: true,
          isRead: false,
          isDark: false,
          onPlayNow: () {},
        ),
      ));

      expect(find.text('URGENT'), findsOneWidget);
    });

    testWidgets('Does NOT show "Mark Done" or "Done" button at all', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Evening Brain Games',
          body: 'A quick exercise session awaits.',
          senderName: 'Caregiver Emma',
          isHighPriority: false,
          isRead: false,
          isDark: false,
          onPlayNow: () {},
        ),
      ));

      // Assert that Mark Done and Done are completely absent
      expect(find.text('Mark Done'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('Shows elderly-friendly "Play Now" button with icon, and triggers callback on tap', (tester) async {
      bool playNowTapped = false;

      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Daily Exercises',
          body: 'Keep your streak going today!',
          senderName: 'Caregiver Liam',
          isHighPriority: false,
          isRead: false,
          isDark: false,
          onPlayNow: () {
            playNowTapped = true;
          },
        ),
      ));

      // Assert Play Now button is visible and properly styled
      final playNowFinder = find.text('Play Now');
      expect(playNowFinder, findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Tap Play Now
      await tester.tap(playNowFinder);
      await tester.pump();

      expect(playNowTapped, isTrue);
    });

    testWidgets('Renders without overflow on narrow 320px screen width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Long Title Memory Match Challenge Workout',
          body: 'Please make sure to complete all assigned exercises before noon today.',
          senderName: 'Caregiver Alexander',
          isHighPriority: true,
          isRead: false,
          isDark: false,
          onPlayNow: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
    });

    testWidgets('Renders properly in Dark Mode', (tester) async {
      await tester.pumpWidget(createTestWidget(
        themeMode: ThemeMode.dark,
        child: CaregiverReminderCard(
          title: 'Nightly Relaxation & Focus',
          body: 'Gentle training session before sleep.',
          senderName: 'Nurse Patel',
          isHighPriority: false,
          isRead: false,
          isDark: true,
          onPlayNow: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Play Now'), findsOneWidget);
    });

    testWidgets('Renders Doctor Appointment reminder with medical icon and View Details button', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Doctor Appointment: Dr. Sarah Jenkins',
          body: 'Appointment at City General Hospital on Wednesday, Sep 10 at 10:00 AM.',
          senderName: 'Caregiver Liam',
          isHighPriority: true,
          isRead: false,
          isDark: false,
          isAppointment: true,
          onPlayNow: () {},
        ),
      ));

      expect(find.text('Doctor Appointment: Dr. Sarah Jenkins'), findsOneWidget);
      expect(find.text('Appointment at City General Hospital on Wednesday, Sep 10 at 10:00 AM.'), findsOneWidget);
      expect(find.byIcon(Icons.medical_services_rounded), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.text('Play Now'), findsNothing);
      expect(find.text('URGENT'), findsOneWidget);
    });

    testWidgets('Tapping View Details triggers callback on Doctor Appointment', (tester) async {
      bool viewDetailsTapped = false;

      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Doctor Appointment: Dr. Patel',
          body: 'Apollo Clinic at 11:30 AM',
          senderName: 'Caregiver Emma',
          isHighPriority: false,
          isRead: false,
          isDark: false,
          isAppointment: true,
          onPlayNow: () {
            viewDetailsTapped = true;
          },
        ),
      ));

      final viewDetailsFinder = find.text('View Details');
      expect(viewDetailsFinder, findsOneWidget);
      await tester.tap(viewDetailsFinder);
      await tester.pump();

      expect(viewDetailsTapped, isTrue);
    });

    testWidgets('Renders Doctor Appointment cleanly on narrow 320px screen width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        child: CaregiverReminderCard(
          title: 'Doctor Appointment: Dr. Christopher Montgomery',
          body: 'Cardiology Consultation at St. Mary Medical Center, Suite 402 with full scan report review.',
          senderName: 'Caregiver Alexander',
          isHighPriority: true,
          isRead: false,
          isDark: false,
          isAppointment: true,
          onPlayNow: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('View Details'), findsOneWidget);
      expect(find.text('URGENT'), findsOneWidget);
    });
  });
}
