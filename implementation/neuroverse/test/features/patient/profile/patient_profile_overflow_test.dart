import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/profile/patient_profile_tab.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Widget buildTestProfileTab({required String language}) {
    final appProvider = AppProvider();
    appProvider.userLanguage = language;
    appProvider.userName = 'Lalremruata';
    appProvider.userAge = '72';
    appProvider.userGender = 'Male';
    appProvider.caretakerName = 'Zonunmawia';

    return ChangeNotifierProvider<AppProvider>.value(
      value: appProvider,
      child: const MaterialApp(
        home: Scaffold(
          body: PatientProfileTab(),
        ),
      ),
    );
  }

  group('PatientProfileTab Localization & Overflow Tests', () {
    final languages = ['miz', 'en', 'hi', 'bn', 'as', 'mni'];
    final viewports = [
      const Size(320, 568), // Ultra narrow
      const Size(360, 640), // Standard budget Android
      const Size(412, 915), // Standard Pixel
    ];

    for (final lang in languages) {
      for (final size in viewports) {
        testWidgets('PatientProfileTab zero overflow in $lang at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestProfileTab(language: lang));
          await tester.pump();

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow occurred in $lang on $size');
        });
      }
    }
  });
}
