import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/features/patient/home/widgets/call_caregiver_button.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/services/smart_alerts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SmartAlert supports rich fields id, type, patientPhone, and mapsUrl', () {
    final alert = SmartAlert(
      id: 'alert_123',
      type: 'CALL_CAREGIVER',
      title: '📞 Call from Ramesh',
      message: 'Ramesh tapped Call Caregiver to reach you.',
      severity: 'warning',
      timestamp: DateTime(2026, 10, 29),
      patientId: 'patient_001',
      patientPhone: '+919876543210',
      mapsUrl: 'https://maps.google.com/?q=28.7,77.1',
    );

    expect(alert.id, 'alert_123');
    expect(alert.type, 'CALL_CAREGIVER');
    expect(alert.title, '📞 Call from Ramesh');
    expect(alert.patientPhone, '+919876543210');
    expect(alert.mapsUrl, 'https://maps.google.com/?q=28.7,77.1');
  });

  testWidgets('CallCaregiverButton renders icon and call text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: const Scaffold(
            body: CallCaregiverButton(),
          ),
        ),
      ),
    );

    expect(find.byType(CallCaregiverButton), findsOneWidget);
    expect(find.byIcon(Icons.phone_in_talk_rounded), findsOneWidget);
    expect(find.text('Call Caregiver'), findsOneWidget);
  });

  testWidgets('CallCaregiverButton tap when phone empty opens Caregiver Phone dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: const Scaffold(
            body: CallCaregiverButton(),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CallCaregiverButton));
    await tester.pumpAndSettle();

    expect(find.text('Caregiver Phone'), findsOneWidget);
    expect(find.text('Save & Dial'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
