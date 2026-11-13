import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/local_progress_repository.dart';
import 'data/local_settings_repository.dart';
import 'services/analytics.dart';
import 'services/game_audio.dart';
import 'state/progress_providers.dart';
import 'state/settings_providers.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';
import 'ui/widgets/background_music.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android-only: konfigurasi dibaca dari android/app/google-services.json.
  await Firebase.initializeApp();

  // Crash hanya dikirim dari build release agar data tidak tercampur debug.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          LocalProgressRepository(prefs),
        ),
        settingsRepositoryProvider.overrideWithValue(
          LocalSettingsRepository(prefs),
        ),
        gameAudioProvider.overrideWithValue(AudioplayersGameAudio()),
        analyticsProvider.overrideWithValue(FirebaseGameAnalytics()),
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
      builder: (context, child) =>
          BackgroundMusic(child: child ?? const SizedBox.shrink()),
    );
  }
}
