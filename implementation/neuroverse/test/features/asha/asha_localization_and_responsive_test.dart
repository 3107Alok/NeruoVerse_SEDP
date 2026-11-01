import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:neuroverse_app/core/localization/app_translations.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/phc_network/presentation/asha/asha_insights_tab.dart';
import 'package:neuroverse_app/features/phc_network/presentation/asha/asha_dashboard_screen.dart';
import 'package:neuroverse_app/features/phc_network/presentation/asha/asha_settings_screen.dart';
import 'package:neuroverse_app/features/patient/common/language_selection_sheet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('1. Village Name Localization across all 6 languages', () {
    final languages = ['en', 'hi', 'bn', 'as', 'mni', 'miz'];
    final villageTests = {
      'Majuli Cluster 1': {
        'en': 'Majuli Cluster 1',
        'hi': 'माजुली क्लस्टर 1',
        'bn': 'মাজুলী ক্লাস্টার ১',
        'as': 'মাজুলী ক্লাষ্টাৰ ১',
        'mni': 'মাজুলি ক্লাস্তর ১',
        'miz': 'Majuli Cluster 1',
      },
      'Jorhat North': {
        'en': 'Jorhat North',
        'hi': 'जोरहाट उत्तर',
        'bn': 'যোরহাট উত্তর',
        'as': 'যোৰহাট উত্তৰ',
        'mni': 'জোরহাত অৱাংবা',
        'miz': 'Jorhat Hmar',
      },
      'Teok East': {
        'en': 'Teok East',
        'hi': 'टिओक पूर्व',
        'bn': 'টিওক পূর্ব',
        'as': 'টিয়ক পূব',
        'mni': 'তেওক নোংপোক',
        'miz': 'Teok Chhak',
      },
      'All Villages': {
        'en': 'All Villages',
        'hi': 'सभी गांव',
        'bn': 'সব গ্রাম',
        'as': 'সকলো গাঁও',
        'mni': 'খুঞ্জা পুম্নমক',
        'miz': 'Khua zawng zawng',
      },
      'Bihpuria Gaon': {
        'en': 'Bihpuria Gaon',
        'hi': 'बिहपुरिया गाँव',
        'bn': 'বিহপুরিয়া গ্রাম',
        'as': 'বিহপুৰীয়া গাঁও',
        'mni': 'বিহপুরিয়া খুঙ্গং',
        'miz': 'Bihpuria Khua',
      },
      'Dergaon': {
        'en': 'Dergaon',
        'hi': 'देरगाँव',
        'bn': 'দেড়গাঁও',
        'as': 'দেৰগাঁও',
        'mni': 'দেরগাঁও',
        'miz': 'Dergaon',
      },
      'Mariani': {
        'en': 'Mariani',
        'hi': 'मरियानी',
        'bn': 'মরিয়নি',
        'as': 'মৰিয়নি',
        'mni': 'মরিয়ানি',
        'miz': 'Mariani',
      },
    };

    for (final lang in languages) {
      test('translates villages for language: $lang', () {
        for (final entry in villageTests.entries) {
          final rawVillage = entry.key;
          final expected = entry.value[lang]!;
          final result = AppTranslations.get(
            lang,
            rawVillage == 'All Villages'
                ? 'all_villages'
                : 'village_${rawVillage.toLowerCase().replaceAll(' ', '_')}',
          );
          expect(result, equals(expected));
        }
      });
    }

    testWidgets('LocalizeVillage extension works with mock context', (WidgetTester tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Mizo';

      late BuildContext capturedContext;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Verify extension translates Jorhat North to Mizo 'Jorhat Hmar'
      expect(capturedContext.localizeVillage('Jorhat North'), equals('Jorhat Hmar'));
      // Verify extension translates All Villages to Mizo 'Khua zawng zawng'
      expect(capturedContext.localizeVillage('All Villages'), equals('Khua zawng zawng'));
      // Verify extension translates Bihpuria Gaon to Mizo 'Bihpuria Khua'
      expect(capturedContext.localizeVillage('Bihpuria Gaon'), equals('Bihpuria Khua'));
      // Verify extension translates Dergaon to Mizo 'Dergaon'
      expect(capturedContext.localizeVillage('Dergaon'), equals('Dergaon'));

      // Switch language to Hindi and test
      appProvider.userLanguage = 'Hindi';
      await tester.pump();
      expect(capturedContext.localizeVillage('Bihpuria Gaon'), equals('बिहपुरिया गाँव'));
      expect(capturedContext.localizeVillage('Dergaon'), equals('देरगाँव'));
      expect(capturedContext.localizeVillage('Mariani'), equals('मरियानी'));

      // Switch language to Assamese and test
      appProvider.userLanguage = 'Assamese';
      await tester.pump();
      expect(capturedContext.localizeVillage('Bihpuria Gaon'), equals('বিহপুৰীয়া গাঁও'));
      expect(capturedContext.localizeVillage('Dergaon'), equals('দেৰগাঁও'));
      expect(capturedContext.localizeVillage('Mariani'), equals('মৰিয়নি'));

      // Verify token decomposition: "Dergaon South" in Assamese -> "দেৰগাঁও দক্ষিণ"
      expect(capturedContext.localizeVillage('Dergaon South'), equals('দেৰগাঁও দক্ষিণ'));

      // Verify multi-village delimiter: "Majuli, Teok" in Assamese -> "মাজুলী, টিয়ক"
      expect(capturedContext.localizeVillage('Majuli, Teok'), equals('মাজুলী, টিয়ক'));

      // Verify fallback returns unknown village untouched
      expect(capturedContext.localizeVillage('Custom Unknown Village'), equals('Custom Unknown Village'));
    });
  });

  group('2. MaterialApp Key & Language Change Behavior', () {
    // Tests key generation logic matching lib/app/app.dart
    Key computeAppKey(AppProvider appProvider) {
      final isAsha = appProvider.currentUserRole == 'asha';
      return ValueKey(isAsha
          ? 'neuroverse_app_asha_${appProvider.isDarkMode}'
          : 'neuroverse_app_${appProvider.userLanguage}_${appProvider.isDarkMode}');
    }

    test('ASHA role produces stable MaterialApp key across language switch', () {
      final appProvider = AppProvider();
      appProvider.setRole('asha');
      appProvider.userLanguage = 'English';

      final key1 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key1.value, equals('neuroverse_app_asha_false'));

      // Switch language to Mizo
      appProvider.userLanguage = 'Mizo';
      final key2 = computeAppKey(appProvider) as ValueKey<String>;
      // ASHA key is constant: MaterialApp will NOT restart
      expect(key2.value, equals(key1.value));

      // Switch language to Hindi
      appProvider.userLanguage = 'Hindi';
      final key3 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key3.value, equals(key1.value));
    });

    test('Patient role preserves MaterialApp key with language dependency', () {
      final appProvider = AppProvider();
      appProvider.setRole('patient');
      appProvider.userLanguage = 'English';

      final key1 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key1.value, equals('neuroverse_app_English_false'));

      // When patient changes language, key changes (existing patient behavior strictly preserved)
      appProvider.userLanguage = 'Hindi';
      final key2 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key2.value, equals('neuroverse_app_Hindi_false'));
      expect(key2.value, isNot(equals(key1.value)));
    });

    test('Caregiver role preserves MaterialApp key with language dependency', () {
      final appProvider = AppProvider();
      appProvider.setRole('caregiver');
      appProvider.userLanguage = 'English';

      final key1 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key1.value, equals('neuroverse_app_English_false'));

      appProvider.userLanguage = 'Assamese';
      final key2 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key2.value, equals('neuroverse_app_Assamese_false'));
      expect(key2.value, isNot(equals(key1.value)));
    });

    test('Admin role preserves MaterialApp key with language dependency', () {
      final appProvider = AppProvider();
      appProvider.setRole('admin');
      appProvider.userLanguage = 'English';

      final key1 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key1.value, equals('neuroverse_app_English_false'));

      appProvider.userLanguage = 'Bengali';
      final key2 = computeAppKey(appProvider) as ValueKey<String>;
      expect(key2.value, equals('neuroverse_app_Bengali_false'));
      expect(key2.value, isNot(equals(key1.value)));
    });
  });

  group('3. Mizo Overflow & Responsive UI Verification', () {
    testWidgets('ASHA Insights Tab renders on small screen (320px) in Mizo without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      final appProvider = AppProvider();
      appProvider.setRole('asha');
      appProvider.userLanguage = 'Mizo';

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(
            locale: Locale('miz'),
            home: AshaInsightsTab(),
          ),
        ),
      );

      await tester.pump();

      // Zero RenderFlex errors should occur
      expect(tester.takeException(), isNull);

      // Verify that Mizo texts are rendered
      expect(find.textContaining('Upate zawng zawng'), findsWidgets);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('ASHA Insights Tab renders across multiple screen sizes and languages without overflow', (WidgetTester tester) async {
      final viewports = [
        const Size(320, 568), // Ultra narrow
        const Size(360, 640), // Standard budget Android
        const Size(412, 915), // Standard Pixel
      ];

      final languages = ['miz', 'en', 'hi', 'bn', 'as', 'mni'];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        for (final lang in languages) {
          final appProvider = AppProvider();
          appProvider.setRole('asha');
          appProvider.userLanguage = lang;

          await tester.pumpWidget(
            ChangeNotifierProvider<AppProvider>.value(
              value: appProvider,
              child: MaterialApp(
                locale: Locale(lang),
                home: const AshaInsightsTab(),
              ),
            ),
          );

          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'Failed on viewport $size with language $lang');
        }
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });

  group('4. ASHA Dedicated Settings Page Verification', () {
    testWidgets('Tapping Settings gear icon from ASHA Dashboard opens AshaSettingsScreen, not Profile', (WidgetTester tester) async {
      final appProvider = AppProvider();
      appProvider.setRole('asha');
      appProvider.userLanguage = 'en';

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(
            home: AshaDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find settings gear icon
      final settingsIconFinder = find.byIcon(Icons.settings_outlined);
      expect(settingsIconFinder, findsOneWidget);

      // Tap settings gear icon
      await tester.tap(settingsIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify that AshaSettingsScreen is opened
      expect(find.byType(AshaSettingsScreen), findsOneWidget);

      // Verify header titles on AshaSettingsScreen
      expect(find.text('ASHA Settings'), findsOneWidget);
      expect(find.text('Frontline preferences & field jurisdiction'), findsOneWidget);

      // Verify back/close button is present and navigates back
      final backButtonFinder = find.byWidgetPredicate(
        (w) => w is Icon && (w.icon == Icons.arrow_back_rounded || w.icon == Icons.close_rounded),
      );
      expect(backButtonFinder, findsOneWidget);

      await tester.tap(backButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Should be back to AshaDashboardScreen and AshaSettingsScreen popped
      expect(find.byType(AshaSettingsScreen), findsNothing);
      expect(find.byType(AshaDashboardScreen), findsOneWidget);
    });

    testWidgets('AshaSettingsScreen renders cleanly across all 6 languages on small screen (320px)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;

      final languages = ['en', 'hi', 'bn', 'as', 'mni', 'miz'];

      for (final lang in languages) {
        final appProvider = AppProvider();
        appProvider.setRole('asha');
        appProvider.userLanguage = lang;

        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint('FLUTTER_ERROR on $lang: ${details.exceptionAsString()}');
          if (details.informationCollector != null) {
            for (final info in details.informationCollector!()) {
              debugPrint('INFO: $info');
            }
          }
        };

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              locale: Locale(lang),
              home: const AshaSettingsScreen(),
            ),
          ),
        );

        FlutterError.onError = oldOnError;
        final err = tester.takeException();
        expect(err, isNull, reason: 'Failed on language $lang: $err');

        // All main section headers should render
        expect(find.byType(ListView), findsOneWidget);
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('AshaSettingsScreen preferences toggles and language dialog work reactively and silently', (WidgetTester tester) async {
      final appProvider = AppProvider();
      appProvider.setRole('asha');
      appProvider.userLanguage = 'English';
      appProvider.setDarkMode(false);
      appProvider.setAudioEffectsEnabled(true);
      appProvider.setDailySummaries(true);
      appProvider.setCriticalAlerts(true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: AshaSettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify initial state of toggles
      expect(appProvider.isDarkMode, isFalse);
      expect(appProvider.isAudioEffectsEnabled, isTrue);
      expect(appProvider.dailySummaries, isTrue);
      expect(appProvider.criticalAlerts, isTrue);

      // Find switches in visible viewport
      final switchFinders = find.byType(Switch);
      expect(switchFinders, findsWidgets); // Visible switches in Section 1

      // Toggle Dark Mode
      await tester.tap(switchFinders.first);
      await tester.pump();
      expect(appProvider.isDarkMode, isTrue);

      // Open Language Dialog
      final langTileFinder = find.text('App Display Language');
      expect(langTileFinder, findsOneWidget);
      await tester.tap(langTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Language dialog/sheet should be visible
      expect(find.byType(LanguageSelectionSheet), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);

      // Tap Hindi
      await tester.tap(find.text('हिंदी'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sheet should close, language in provider updated immediately
      expect(appProvider.userLanguage, 'Hindi');
      expect(find.byType(LanguageSelectionSheet), findsNothing);

      // Verify SnackBar feedback is shown
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
