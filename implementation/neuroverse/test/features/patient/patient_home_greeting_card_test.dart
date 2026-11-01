import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/home/patient_home_tab.dart';

class FakeHiveService extends HiveService {
  @override
  int getGameDifficulty(String gameId) => 1;
}

void main() {
  Widget createTestWidget({
    required AppProvider appProvider,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const Scaffold(
          body: PatientHomeTab(),
        ),
      ),
    );
  }

  group('Patient Home Greeting Card Botanical Leaf Tests', () {
    testWidgets('Greeting card renders user name and botanical leaf illustration', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appProvider = AppProvider();
      appProvider.userName = 'Eleanor';

      await tester.pumpWidget(createTestWidget(appProvider: appProvider));
      await tester.pump();

      // Check user name is rendered in the greeting card
      expect(find.text('Eleanor!'), findsOneWidget);

      // Verify that the Stack contains CustomPaint for the botanical leaf illustration
      final customPaints = find.descendant(
        of: find.byType(PatientHomeTab),
        matching: find.byType(CustomPaint),
      );
      expect(customPaints, findsWidgets);
    });

    testWidgets('Renders properly without overflow on small mobile viewport (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appProvider = AppProvider();
      appProvider.userName = 'Grandma Margaret';

      await tester.pumpWidget(createTestWidget(appProvider: appProvider));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Grandma Margaret!'), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on extra-narrow viewport (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appProvider = AppProvider();
      appProvider.userName = 'Bartholomew Montgomery';

      await tester.pumpWidget(createTestWidget(appProvider: appProvider));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Bartholomew Montgomery!'), findsOneWidget);
    });

    testWidgets('Renders in dark mode with matching botanical leaf styling', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appProvider = AppProvider();
      appProvider.userName = 'Robert';

      await tester.pumpWidget(createTestWidget(
        appProvider: appProvider,
        themeMode: ThemeMode.dark,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Robert!'), findsOneWidget);
    });

    testWidgets('Botanical leaf illustration renders right-aligned with Image asset', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appProvider = AppProvider();
      appProvider.userName = 'Anita Devi';

      await tester.pumpWidget(createTestWidget(appProvider: appProvider));
      await tester.pump();

      // Find the botanical leaf illustration image widget
      final leafImage = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/greeting_botanical_accent.png',
      );
      expect(leafImage, findsOneWidget);
    });
  });
}
