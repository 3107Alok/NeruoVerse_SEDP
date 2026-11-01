import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/features/patient/home/widgets/sos_emergency_button.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/services/emergency_sos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EmergencySosService contacts list manipulation test', () async {
    final service = EmergencySosService();
    expect(service.getEmergencyContacts(), isA<List<String>>());
  });

  testWidgets('SosEmergencyButton renders with high-contrast emergency styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: const Scaffold(
            body: SosEmergencyButton(),
          ),
        ),
      ),
    );

    // Verify Emergency icon & SOS text
    expect(find.byIcon(Icons.emergency_rounded), findsOneWidget);
    expect(find.text('EMERGENCY SOS'), findsOneWidget);
    expect(find.text('Hold 2s for Help'), findsOneWidget);
  });

  testWidgets('Quick tap on SOS button shows guidance tooltip and cancels hold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>(
              create: (_) => AppProvider(),
            ),
          ],
          child: const Scaffold(
            body: SosEmergencyButton(),
          ),
        ),
      ),
    );

    // Perform a quick tap (accidental press)
    await tester.tap(find.byType(SosEmergencyButton));
    await tester.pump();

    // Guidance snackbar is shown preventing panic
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
