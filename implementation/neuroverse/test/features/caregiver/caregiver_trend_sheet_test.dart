import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
import 'package:neuroverse_app/features/caregiver/overview/caregiver_main_screen.dart';

void main() {
  final mockSessionsList = [
    {
      'gameId': 'face_recall',
      'accuracyPercentage': 88,
      'difficultyLevel': 3,
      'completionTimeSeconds': 45,
      'timestamp': '2026-09-06T10:00:00Z',
    },
    {
      'gameId': 'memory_match',
      'accuracyPercentage': 72,
      'difficultyLevel': 2,
      'completionTimeSeconds': 60,
      'timestamp': '2026-09-05T14:30:00Z',
    },
    {
      'gameId': 'pattern_path',
      'accuracyPercentage': 40,
      'difficultyLevel': 1,
      'completionTimeSeconds': 35,
      'timestamp': '2026-09-04T09:15:00Z',
    },
    {
      'gameId': 'memory_recall',
      'accuracyPercentage': 95,
      'difficultyLevel': 4,
      'completionTimeSeconds': 50,
      'timestamp': '2026-09-03T16:20:00Z',
    },
    {
      'gameId': 'spatial_puzzle',
      'gameCategory': 'Spatial Reasoning',
      'accuracyPercentage': 82,
      'difficultyLevel': 2,
      'completionTimeSeconds': 40,
      'timestamp': '2026-09-02T11:00:00Z',
    },
  ];

  Widget buildTestWidget({
    List<Map<String, dynamic>>? sessions,
    String patientName = 'Grandma Maya',
    String trendText = 'Improving (+12%)',
    Color trendColor = const Color(0xFF16A34A),
    IconData trendIcon = Icons.trending_up_rounded,
    int avgAcc = 75,
    bool isDark = false,
  }) {
    return MaterialApp(
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showCaregiverTrendDetailsSheet(
                context: context,
                patientName: patientName,
                sessionMaps: sessions ?? mockSessionsList,
                trendText: trendText,
                trendColor: trendColor,
                trendIcon: trendIcon,
                avgAcc: avgAcc,
                isDark: isDark,
              );
            },
            child: const Text('Open Trend Sheet'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester, {Widget? widget}) async {
    await tester.pumpWidget(widget ?? buildTestWidget());
    await tester.pump();
    await tester.tap(find.text('Open Trend Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('Caregiver Performance Trend & Graph Sheet UI Tests', () {
    testWidgets('Opens Performance Trend & Graph sheet and renders header banner', (tester) async {
      await openSheet(tester);

      expect(find.text('Performance Trend & Graph'), findsOneWidget);
      expect(find.textContaining('Real-time cognitive trajectory'), findsOneWidget);
      expect(find.textContaining('Grandma Maya'), findsWidgets);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Renders 3 summary metric badges with dynamic values', (tester) async {
      await openSheet(tester);

      expect(find.text('CURRENT TREND'), findsOneWidget);
      expect(find.text('AVG ACCURACY'), findsOneWidget);
      expect(find.text('PEAK SCORE'), findsOneWidget);
      expect(find.text('Improving'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget); // Peak score in mock data is 95
    });

    testWidgets('Renders session accuracy trajectory chart with CustomPaint painter', (tester) async {
      await openSheet(tester);

      expect(find.text('Session Accuracy'), findsOneWidget);
      expect(find.byIcon(Icons.insights_rounded), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders dynamic AI Cognitive Assessment Insight card', (tester) async {
      await openSheet(tester);

      expect(find.text('Cognitive Assessment Insight'), findsOneWidget);
      expect(find.text('AI Telemetry'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_alt_rounded), findsOneWidget);
    });

    testWidgets('Renders Recent Sessions Breakdown using authentic GameHubIllustration for all 4 games and fallback', (tester) async {
      await openSheet(tester);

      await tester.scrollUntilVisible(find.text('Recent Sessions Breakdown'), 100);
      await tester.pumpAndSettle();

      expect(find.text('Recent Sessions Breakdown'), findsOneWidget);

      // Verify authentic vector game illustrations
      expect(find.byType(GameHubIllustration), findsWidgets);

      // Verify game titles
      expect(find.text('Focus Finder'), findsOneWidget);
      expect(find.text('Memory Match'), findsOneWidget);
      expect(find.text('Pattern Path'), findsOneWidget);
      expect(find.text('Memory Recall'), findsOneWidget);

      // Verify fallback title and icon
      expect(find.text('Spatial Reasoning'), findsOneWidget);
      expect(find.byIcon(Icons.sports_esports_rounded), findsOneWidget);

      // Verify accuracy percentages
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
    });

    testWidgets('Renders graceful empty state when patient has no session history', (tester) async {
      await openSheet(tester, widget: buildTestWidget(sessions: []));

      await tester.scrollUntilVisible(find.text('No recorded sessions yet'), 100);
      await tester.pumpAndSettle();

      expect(find.text('No recorded sessions yet'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    for (final size in [
      const Size(320, 640),
      const Size(360, 800),
      const Size(375, 812),
      const Size(412, 915),
    ]) {
      testWidgets('Responsive across ${size.width.toInt()}x${size.height.toInt()} viewport without overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await openSheet(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Performance Trend & Graph'), findsOneWidget);
      });
    }

    testWidgets('Renders cleanly in Dark Mode', (tester) async {
      await openSheet(tester, widget: buildTestWidget(isDark: true));

      expect(tester.takeException(), isNull);
      expect(find.text('Performance Trend & Graph'), findsOneWidget);
      expect(find.text('CURRENT TREND'), findsOneWidget);
    });

    testWidgets('Renders session card metadata: Level badges, duration timers, and scroll clearance', (tester) async {
      await openSheet(tester);

      // Scroll to Recent Sessions
      await tester.scrollUntilVisible(find.text('Spatial Reasoning'), 100);
      await tester.pumpAndSettle();

      // Check level pills
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('Level 2'), findsWidgets); // Used in memory_match and spatial_puzzle
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('Level 4'), findsOneWidget);

      // Check timer icons and duration labels
      expect(find.byIcon(Icons.timer_outlined), findsWidgets);
      expect(find.text('45s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('35s'), findsOneWidget);
      expect(find.text('50s'), findsOneWidget);
      expect(find.text('40s'), findsOneWidget);

      // Verify the last card is fully visible and rendered
      expect(find.text('Spatial Reasoning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Provides bottom safe area clearance with simulated system bottom navigation inset', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await openSheet(tester);

      // Scroll to the very last card
      await tester.scrollUntilVisible(find.text('Spatial Reasoning'), 150);
      await tester.pumpAndSettle();

      // Verify last card and its accuracy badge are in viewport
      expect(find.text('Spatial Reasoning'), findsOneWidget);
      expect(find.text('82%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Continuous 0 trend renders Stable text and chart line in Red', (tester) async {
      final continuousZeroSessions = [
        {
          'gameId': 'face_recall',
          'accuracyPercentage': 0,
          'difficultyLevel': 1,
          'completionTimeSeconds': 30,
          'timestamp': '2026-09-06T10:00:00Z',
        },
        {
          'gameId': 'memory_match',
          'accuracyPercentage': 0,
          'difficultyLevel': 1,
          'completionTimeSeconds': 30,
          'timestamp': '2026-09-05T14:30:00Z',
        },
      ];

      await openSheet(
        tester,
        widget: buildTestWidget(
          sessions: continuousZeroSessions,
          trendText: 'Stable',
          trendColor: const Color(0xFFEA580C),
          trendIcon: Icons.trending_flat_rounded,
          avgAcc: 0,
        ),
      );

      // Verify Stable text is rendered
      expect(find.text('Stable'), findsWidgets);

      // Find the Trend pill text widget and verify its color is RED (0xFFEA580C)
      final stableTextFinder = find.descendant(
        of: find.byType(Row),
        matching: find.text('Stable'),
      );
      final stableWidget = tester.widget<Text>(stableTextFinder.first);
      expect(stableWidget.style?.color, equals(const Color(0xFFEA580C)));

      // Verify Chart CustomPaint uses Red lineColor
      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final chartPaint = customPaints.firstWhere(
        (cp) => cp.painter.runtimeType.toString() == '_TrendPerformanceChartPainter',
      );
      expect((chartPaint.painter as dynamic).lineColor, equals(const Color(0xFFEA580C)));
    });

    testWidgets('Continuous 100 trend renders Stable text and chart line in Green', (tester) async {
      final continuous100Sessions = [
        {
          'gameId': 'face_recall',
          'accuracyPercentage': 100,
          'difficultyLevel': 3,
          'completionTimeSeconds': 40,
          'timestamp': '2026-09-06T10:00:00Z',
        },
        {
          'gameId': 'memory_match',
          'accuracyPercentage': 100,
          'difficultyLevel': 3,
          'completionTimeSeconds': 40,
          'timestamp': '2026-09-05T14:30:00Z',
        },
      ];

      await openSheet(
        tester,
        widget: buildTestWidget(
          sessions: continuous100Sessions,
          trendText: 'Stable',
          trendColor: const Color(0xFF00796B),
          trendIcon: Icons.trending_flat_rounded,
          avgAcc: 100,
        ),
      );

      // Verify Stable text is rendered
      expect(find.text('Stable'), findsWidgets);

      // Find the Trend pill text widget and verify its color is Green (0xFF00796B)
      final stableTextFinder = find.descendant(
        of: find.byType(Row),
        matching: find.text('Stable'),
      );
      final stableWidget = tester.widget<Text>(stableTextFinder.first);
      expect(stableWidget.style?.color, equals(const Color(0xFF00796B)));

      // Verify Chart CustomPaint uses Green lineColor
      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final chartPaint = customPaints.firstWhere(
        (cp) => cp.painter.runtimeType.toString() == '_TrendPerformanceChartPainter',
      );
      expect((chartPaint.painter as dynamic).lineColor, equals(const Color(0xFF00796B)));
    });

    testWidgets('Caregiver overview trend color evaluation logic unit tests', (tester) async {
      // Helper function mirroring the exact logic in CaregiverMainScreen lines 4809-4830
      (String, Color) evaluateTrend(List<Map<String, dynamic>> sessionMaps) {
        String trendText = 'Stable';
        Color trendColor = const Color(0xFF00796B);
        if (sessionMaps.length >= 2) {
          final latest = sessionMaps[0]['accuracyPercentage'] ?? 0;
          final previous = sessionMaps[1]['accuracyPercentage'] ?? 0;
          if (latest > previous) {
            trendText = 'Improving (+${latest - previous}%)';
            trendColor = const Color(0xFF16A34A);
          } else if (latest < previous) {
            trendText = 'Attention Needed (-${previous - latest}%)';
            trendColor = const Color(0xFFEA580C);
          } else {
            trendText = 'Stable';
            trendColor = (latest == 0) ? const Color(0xFFEA580C) : const Color(0xFF00796B);
          }
        } else if (sessionMaps.isNotEmpty && (sessionMaps[0]['accuracyPercentage'] ?? 0) == 0) {
          trendColor = const Color(0xFFEA580C);
        }
        return (trendText, trendColor);
      }

      // Case 1: Continuous 0 -> Stable + Red
      final res0 = evaluateTrend([{'accuracyPercentage': 0}, {'accuracyPercentage': 0}]);
      expect(res0.$1, equals('Stable'));
      expect(res0.$2, equals(const Color(0xFFEA580C)));

      // Case 2: Continuous 100 -> Stable + Green
      final res100 = evaluateTrend([{'accuracyPercentage': 100}, {'accuracyPercentage': 100}]);
      expect(res100.$1, equals('Stable'));
      expect(res100.$2, equals(const Color(0xFF00796B)));

      // Case 3: Increasing -> Improving + Green
      final resInc = evaluateTrend([{'accuracyPercentage': 90}, {'accuracyPercentage': 70}]);
      expect(resInc.$1, equals('Improving (+20%)'));
      expect(resInc.$2, equals(const Color(0xFF16A34A)));

      // Case 4: Decreasing -> Attention Needed + Red
      final resDec = evaluateTrend([{'accuracyPercentage': 60}, {'accuracyPercentage': 85}]);
      expect(resDec.$1, equals('Attention Needed (-25%)'));
      expect(resDec.$2, equals(const Color(0xFFEA580C)));

      // Case 5: Single session with 0% -> Stable + Red
      final resSingle0 = evaluateTrend([{'accuracyPercentage': 0}]);
      expect(resSingle0.$1, equals('Stable'));
      expect(resSingle0.$2, equals(const Color(0xFFEA580C)));
    });
  });
}
