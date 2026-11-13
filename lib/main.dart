import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_progress_repository.dart';
import 'state/progress_providers.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          LocalProgressRepository(prefs),
        ),
      ],
      child: const KirainApp(),
    ),
  );
}

class KirainApp extends StatelessWidget {
  const KirainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kirain',
      debugShowCheckedModeBanner: false,
      theme: buildKirainTheme(),
      home: const SplashPage(),
    );
  }
}
