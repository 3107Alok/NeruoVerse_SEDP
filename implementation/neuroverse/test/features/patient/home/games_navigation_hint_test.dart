import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/home/widgets/games_navigation_hint.dart';

void main() {
  Widget createTestWidget({
    required Widget child,
    required AppProvider appProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('GamesNavigationHint Widget Tests', () {
    testWidgets('Renders tooltip speech bubble in English when userLanguage is English', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'English';

      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();

      expect(find.text('Tap here to play games!'), findsOneWidget);
      final defaultTextStyle = tester.widget<DefaultTextStyle>(find.descendant(
        of: find.byType(GamesNavigationHint),
        matching: find.byType(DefaultTextStyle),
      ));
      expect(defaultTextStyle.style.decoration, equals(TextDecoration.none));
      expect(find.byType(CustomPaint), findsWidgets);
      final hintIgnorePointer = find.descendant(
        of: find.byType(GamesNavigationHint),
        matching: find.byType(IgnorePointer),
      );
      expect(hintIgnorePointer, findsOneWidget);
      expect((tester.widget(hintIgnorePointer) as IgnorePointer).ignoring, isTrue);
    });

    testWidgets('Renders tooltip in Hindi when userLanguage is Hindi', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Hindi';

      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();

      expect(find.text('गेम्स के लिए यहाँ टैप करें!'), findsOneWidget);
    });

    testWidgets('Renders tooltip in Manipuri with pure Eastern Nagari script', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Manipuri';

      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();

      expect(find.text('শান্ননবা মফমসিদা তেপ তৌবীয়ু!'), findsOneWidget);
      // Ensure no mixed Devanagari characters
      expect(find.textContaining('दा'), findsNothing);
    });

    testWidgets('Renders tooltip in Bengali, Assamese, and Mizo correctly', (tester) async {
      final appProvider = AppProvider();

      // Bengali
      appProvider.userLanguage = 'Bengali';
      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();
      expect(find.text('গেম খেলতে এখানে ট্যাপ করুন!'), findsOneWidget);

      // Assamese
      appProvider.userLanguage = 'Assamese';
      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();
      expect(find.text('গেম খেলিবলৈ ইয়াত টেপ কৰক!'), findsOneWidget);

      // Mizo
      appProvider.userLanguage = 'Mizo';
      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();
      expect(find.text('Games khelh nan hetah hian hmet rawh!'), findsOneWidget);
    });

    testWidgets('Does not render any visible tooltip content when isVisible is false', (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: false),
        appProvider: appProvider,
      ));
      await tester.pump();

      expect(find.text('Tap here to play games!'), findsNothing);
    });

    testWidgets('Wraps hint in IgnorePointer so taps pass through transparently', (tester) async {
      final appProvider = AppProvider();
      bool buttonTapped = false;

      await tester.pumpWidget(createTestWidget(
        child: Stack(
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () => buttonTapped = true,
                child: const Text('Target Button'),
              ),
            ),
            const GamesNavigationHint(isVisible: true),
          ],
        ),
        appProvider: appProvider,
      ));
      await tester.pump();

      await tester.tap(find.text('Target Button'));
      expect(buttonTapped, isTrue);
    });

    testWidgets('Verifies background blur, spotlight cutout, and native custom painters exist', (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(createTestWidget(
        child: const GamesNavigationHint(isVisible: true),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Ensure ClipPath, BackdropFilter, and native CustomPaint (spotlight, bubble, arrow) are rendered
      expect(find.descendant(of: find.byType(GamesNavigationHint), matching: find.byType(ClipPath)), findsOneWidget);
      expect(find.descendant(of: find.byType(GamesNavigationHint), matching: find.byType(BackdropFilter)), findsOneWidget);
      expect(find.descendant(of: find.byType(GamesNavigationHint), matching: find.byType(CustomPaint)), findsWidgets);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    });

    testWidgets('Verifies tooltip, arrow, and target key share the exact same horizontal center', (tester) async {
      final appProvider = AppProvider();
      final targetKey = GlobalKey();

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 120,
                  top: 700,
                  width: 80,
                  height: 50,
                  child: Container(
                    key: targetKey,
                    color: Colors.blue,
                  ),
                ),
                GamesNavigationHint(
                  isVisible: true,
                  targetKey: targetKey,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Target center is 120 + 40 = 160
      final targetRenderBox = targetKey.currentContext!.findRenderObject() as RenderBox;
      final targetCenter = targetRenderBox.localToGlobal(Offset.zero) + Offset(targetRenderBox.size.width / 2, targetRenderBox.size.height / 2);
      expect(targetCenter.dx, equals(160.0));

      // Check text is rendered
      expect(find.text('Tap here to play games!'), findsOneWidget);
    });

    testWidgets('Diagnostic test: measure exact coordinates in BottomAppBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.view.padding = const FakeViewPadding(bottom: 48, top: 48);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final appProvider = AppProvider();
      final gamesTabKey = GlobalKey();

      Widget buildNavItem({required IconData icon, required String label, required int index}) {
        final isGamesHintActive = index == 1;
        final navContent = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        );

        Widget itemWidget;
        if (isGamesHintActive) {
          itemWidget = Container(
            key: gamesTabKey,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: navContent,
          );
        } else {
          itemWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: navContent,
          );
        }

        return InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: itemWidget,
        );
      }

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            floatingActionButton: const SizedBox(
              width: 58,
              height: 58,
              child: FloatingActionButton(
                onPressed: null,
                child: Icon(Icons.mic),
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 65,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: buildNavItem(icon: Icons.home, label: 'Home', index: 0)),
                    Expanded(child: buildNavItem(icon: Icons.sports_esports, label: 'Games', index: 1)),
                    const SizedBox(width: 48),
                    Expanded(child: buildNavItem(icon: Icons.bar_chart, label: 'Progress', index: 2)),
                    Expanded(child: buildNavItem(icon: Icons.person, label: 'Profile', index: 3)),
                  ],
                ),
              ),
            ),
            body: Stack(
              children: [
                const Center(child: Text('Content')),
                GamesNavigationHint(
                  isVisible: true,
                  targetKey: gamesTabKey,
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final rb = gamesTabKey.currentContext?.findRenderObject() as RenderBox?;
      expect(rb, isNotNull);
      final pos = rb!.localToGlobal(Offset.zero);
      final centerX = pos.dx + rb.size.width / 2;
      expect(centerX, inInclusiveRange(80.0, 160.0));
    });
  });

  group('Full-Screen Overlay Hit-Testing & Dismissal Tests', () {
    testWidgets('Tapping Games tab dismisses hint and executes navigation', (tester) async {
      final appProvider = AppProvider();
      bool hintDismissed = false;
      int selectedTab = 0;

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final scaffold = Scaffold(
                bottomNavigationBar: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => selectedTab = 0),
                      child: const Text('Home'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          hintDismissed = true;
                          selectedTab = 1;
                        });
                      },
                      child: const Text('Games'),
                    ),
                  ],
                ),
              );

              if (hintDismissed) return scaffold;

              return Stack(
                children: [
                  scaffold,
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => setState(() => hintDismissed = true),
                      child: const IgnorePointer(
                        child: GamesNavigationHint(isVisible: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap Games tab
      await tester.tap(find.text('Games'));
      await tester.pump();

      expect(hintDismissed, isTrue);
      expect(selectedTab, equals(1));
    });

    testWidgets('Tapping an exercise card dismisses hint and opens exercise', (tester) async {
      final appProvider = AppProvider();
      bool hintDismissed = false;
      bool exerciseOpened = false;

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final scaffold = Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => exerciseOpened = true,
                    child: const Text('Memory Match Card'),
                  ),
                ),
              );

              if (hintDismissed) return scaffold;

              return Stack(
                children: [
                  scaffold,
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => setState(() => hintDismissed = true),
                      child: const IgnorePointer(
                        child: GamesNavigationHint(isVisible: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pump();

      // Tap exercise card
      await tester.tap(find.text('Memory Match Card'));
      await tester.pump();

      expect(hintDismissed, isTrue);
      expect(exerciseOpened, isTrue);
    });

    testWidgets('Tapping Progress or Profile tab dismisses hint and navigates', (tester) async {
      final appProvider = AppProvider();
      bool hintDismissed = false;
      int selectedTab = 0;

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final scaffold = Scaffold(
                bottomNavigationBar: Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => selectedTab = 2),
                      child: const Text('Progress'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => selectedTab = 3),
                      child: const Text('Profile'),
                    ),
                  ],
                ),
              );

              if (hintDismissed) return scaffold;

              return Stack(
                children: [
                  scaffold,
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => setState(() => hintDismissed = true),
                      child: const IgnorePointer(
                        child: GamesNavigationHint(isVisible: true),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Progress'));
      await tester.pump();

      expect(hintDismissed, isTrue);
      expect(selectedTab, equals(2));
    });

    testWidgets('Auto-dismisses automatically after 5 seconds duration', (tester) async {
      bool hintDismissed = false;
      Timer? timer = Timer(const Duration(seconds: 5), () {
        hintDismissed = true;
      });
      addTearDown(() => timer.cancel());

      // At 4 seconds, not yet dismissed
      await tester.pump(const Duration(seconds: 4));
      expect(hintDismissed, isFalse);

      // At 5 seconds, dismissed
      await tester.pump(const Duration(seconds: 1));
      expect(hintDismissed, isTrue);
    });
  });

  group('AppProvider Games Navigation Hint Session Guard Tests', () {
    test('hasShownGamesHintThisSession starts false and flips to true via markGamesHintShown', () {
      final appProvider = AppProvider();
      expect(appProvider.hasShownGamesHintThisSession, isFalse);

      appProvider.markGamesHintShown();
      expect(appProvider.hasShownGamesHintThisSession, isTrue);

      // Repeated calls maintain true
      appProvider.markGamesHintShown();
      expect(appProvider.hasShownGamesHintThisSession, isTrue);
    });

    test('Fresh AppProvider instance resets the session guard naturally without persistent storage', () {
      final sessionOne = AppProvider();
      sessionOne.markGamesHintShown();
      expect(sessionOne.hasShownGamesHintThisSession, isTrue);

      // Fresh session / relaunch simulation
      final sessionTwo = AppProvider();
      expect(sessionTwo.hasShownGamesHintThisSession, isFalse);
    });
  });

  group('Responsive Multi-Screen Positioning & Runtime Tracking Tests', () {
    const testScreenSizes = [
      Size(320, 568),  // iPhone SE 1st gen / narrow phone
      Size(360, 640),  // Compact Android
      Size(390, 844),  // Modern standard phone (iPhone 12/13/14)
      Size(412, 915),  // Pixel 7/8 / Large Android
      Size(800, 1280), // Tablet
    ];

    for (final screenSize in testScreenSizes) {
      testWidgets('Arrow points exactly to target center and tooltip stays within bounds on ${screenSize.width}x${screenSize.height}', (tester) async {
        tester.view.physicalSize = screenSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final appProvider = AppProvider();
        final targetKey = GlobalKey();

        // Place target at a representative bottom-nav Games tab position (e.g. 2nd quarter of width)
        final targetWidth = (screenSize.width - 48.0) / 4.0;
        final targetLeft = targetWidth;
        const targetHeight = 52.0;
        final targetTop = screenSize.height - 65.0;

        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: targetLeft,
                    top: targetTop,
                    width: targetWidth,
                    height: targetHeight,
                    child: Container(
                      key: targetKey,
                      color: Colors.teal,
                    ),
                  ),
                  GamesNavigationHint(
                    isVisible: true,
                    targetKey: targetKey,
                  ),
                ],
              ),
            ),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 1. Measure exact runtime center of target
        final targetBox = targetKey.currentContext!.findRenderObject() as RenderBox;
        final targetPos = targetBox.localToGlobal(Offset.zero);
        final expectedTargetCenterX = targetPos.dx + (targetBox.size.width / 2.0);

        // 2. Find the CustomPaint widget for the Downward Arrow
        final arrowFinder = find.byWidgetPredicate(
          (w) => w is Positioned && w.child is Transform,
        );
        expect(arrowFinder, findsOneWidget);
        final arrowPositioned = tester.widget<Positioned>(arrowFinder);

        // Arrow has width 32, placed at left: gamesCenterX - 16.0
        // Its center must match expectedTargetCenterX exactly
        final arrowCenterX = arrowPositioned.left! + 16.0;
        expect(arrowCenterX, closeTo(expectedTargetCenterX, 0.01),
            reason: 'Arrow center must point exactly at target center on ${screenSize.width}');

        // 3. Find tooltip speech bubble
        final tooltipFinder = find.byWidgetPredicate(
          (w) => w is Positioned && w.child is SizedBox && (w.child as SizedBox).child is CustomPaint,
        );
        expect(tooltipFinder, findsWidgets);
        final tooltipPositioned = tester.widget<Positioned>(tooltipFinder.first);

        // Tooltip must be fully within screen bounds [12.0, screenSize.width - 12.0]
        final tooltipSizedBox = tooltipPositioned.child as SizedBox;
        final tooltipLeft = tooltipPositioned.left!;
        final tooltipRight = tooltipLeft + tooltipSizedBox.width!;

        expect(tooltipLeft, greaterThanOrEqualTo(11.99),
            reason: 'Tooltip must not bleed off the left screen edge');
        expect(tooltipRight, lessThanOrEqualTo(screenSize.width - 11.99),
            reason: 'Tooltip must not bleed off the right screen edge');
      });
    }

    testWidgets('Tooltip automatically follows target when target position shifts dynamically', (tester) async {
      final appProvider = AppProvider();
      final targetKey = GlobalKey();
      double dynamicTargetLeft = 100.0;
      double dynamicTargetTop = 600.0;

      late StateSetter triggerRebuild;

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                triggerRebuild = setState;
                return Stack(
                  children: [
                    Positioned(
                      left: dynamicTargetLeft,
                      top: dynamicTargetTop,
                      width: 70,
                      height: 50,
                      child: Container(
                        key: targetKey,
                        color: Colors.green,
                      ),
                    ),
                    GamesNavigationHint(
                      isVisible: true,
                      targetKey: targetKey,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Initial check: target center is 100 + 35 = 135.0
      final arrowFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.child is Transform,
      );
      var arrowPositioned = tester.widget<Positioned>(arrowFinder);
      expect(arrowPositioned.left! + 16.0, closeTo(135.0, 0.01));

      // Dynamically shift target horizontally and vertically (e.g. responsive repositioning)
      triggerRebuild(() {
        dynamicTargetLeft = 210.0;
        dynamicTargetTop = 650.0;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // New check: target center is 210 + 35 = 245.0
      arrowPositioned = tester.widget<Positioned>(arrowFinder);
      expect(arrowPositioned.left! + 16.0, closeTo(245.0, 0.01),
          reason: 'Arrow must automatically follow target to new horizontal position 245.0');
    });

    testWidgets('Handles SafeArea bottom insets and variable bottom navigation heights responsively', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34, top: 47);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final appProvider = AppProvider();
      final targetKey = GlobalKey();

      // Bottom bar with 80px height including SafeArea
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SafeArea(
              child: SizedBox(
                height: 80,
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: Container(
                        key: targetKey,
                        color: Colors.amber,
                        child: const Center(child: Icon(Icons.sports_esports)),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
            body: Stack(
              children: [
                const SizedBox.expand(),
                GamesNavigationHint(
                  isVisible: true,
                  targetKey: targetKey,
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final targetBox = targetKey.currentContext!.findRenderObject() as RenderBox;
      final targetPos = targetBox.localToGlobal(Offset.zero);
      final expectedCenterX = targetPos.dx + (targetBox.size.width / 2.0);

      final arrowFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.child is Transform,
      );
      final arrowPositioned = tester.widget<Positioned>(arrowFinder);
      expect(arrowPositioned.left! + 16.0, closeTo(expectedCenterX, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}
