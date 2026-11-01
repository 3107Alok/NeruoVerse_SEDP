import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/localization/app_translations.dart';
import 'package:neuroverse_app/features/patient/home/patient_main_screen.dart';

void main() {
  Widget buildTestDrawer({
    required String language,
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onClose,
  }) {
    final appProvider = AppProvider();
    appProvider.userLanguage = language;

    return ChangeNotifierProvider<AppProvider>.value(
      value: appProvider,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          endDrawer: PatientNotificationDrawer(
            onClose: onClose,
          ),
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Patient Notification Drawer Redesign Tests', () {
    testWidgets('Renders empty state with bell, leaf background, and eco info card', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool closed = false;
      await tester.pumpWidget(buildTestDrawer(
        language: 'en',
        onClose: () => closed = true,
      ));
      await tester.pump();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify header texts
      expect(find.text('Invitations & Alerts'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Caregiver connection requests & updates'), findsOneWidget);

      // Verify empty state texts
      expect(find.text('No Pending Invitations'), findsOneWidget);
      expect(find.text('No new reminders or invitations right now. You are all caught up!'), findsOneWidget);
      expect(find.text("We'll let you know here when there's something new."), findsOneWidget);

      // Verify Image assets
      final images = find.byType(Image);
      expect(images, findsNWidgets(2));

      final leafImage = tester.widget<Image>(find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/notifications_leaf_bg.png',
      ));
      expect(leafImage, isNotNull);

      final bellImage = tester.widget<Image>(find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/notifications_bell_empty.png',
      ));
      expect(bellImage, isNotNull);

      // Verify Eco icon in info card
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

      // Verify close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('Renders properly in Dark Mode without issues', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestDrawer(
        language: 'en',
        themeMode: ThemeMode.dark,
      ));
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Notifications'), findsOneWidget);
    });

    final languages = ['en', 'hi', 'bn', 'as', 'mni', 'miz'];
    final viewports = [
      const Size(320, 568), // Ultra narrow
      const Size(360, 640), // Standard budget Android
      const Size(412, 915), // Standard Pixel
    ];

    for (final lang in languages) {
      for (final size in viewports) {
        testWidgets('Zero RenderFlex overflow in $lang on ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestDrawer(language: lang));
          await tester.pump();

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          final err = tester.takeException();
          expect(
            err,
            isNull,
            reason: 'RenderFlex overflow occurred in $lang at ${size.width.toInt()}x${size.height.toInt()}',
          );

          // Verify that translated strings from app_translations exist
          final title = AppTranslations.get(lang, 'notifications');
          final emptyHeading = AppTranslations.get(lang, 'no_pending_invitations');
          final hint = AppTranslations.get(lang, 'notifications_empty_hint');

          expect(find.text(title), findsOneWidget);
          expect(find.text(emptyHeading), findsOneWidget);
          expect(find.text(hint), findsOneWidget);
        });
      }
    }

    testWidgets('Header pill badge truncates smoothly with ellipsis on ultra-narrow viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(260, 500); // Extremely narrow edge case
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestDrawer(language: 'miz'));
      await tester.pump();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
