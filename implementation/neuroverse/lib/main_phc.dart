import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'features/phc_network/presentation/phc_role_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const NeuroVersePhcApp(),
    ),
  );
}

class NeuroVersePhcApp extends StatelessWidget {
  const NeuroVersePhcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroVerse PHC Network',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const PhcRoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
