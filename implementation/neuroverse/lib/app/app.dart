import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/onboarding/splash_screen.dart';

import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../core/localization/app_translations.dart';

class NeuroVerseApp extends StatelessWidget {
  const NeuroVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        final langCode = AppTranslations.normalizeLangCode(appProvider.userLanguage);
        return MaterialApp(
          title: 'NeuroVerse',
          locale: Locale(langCode),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
          routes: AppRoutes.routes,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
