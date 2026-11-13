import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/firebase_remote_settings.dart';
import 'data/firestore_level_repository.dart';
import 'data/level_repository.dart';
import 'data/local_progress_repository.dart';
import 'data/local_settings_repository.dart';
import 'data/remote_settings.dart';
import 'services/analytics.dart';
import 'services/game_audio.dart';
import 'state/firebase_providers.dart';
import 'state/progress_providers.dart';
import 'state/settings_providers.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';
import 'ui/widgets/background_music.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase = await _initFirebase();
  RemoteSettings remoteSettings = const DefaultRemoteSettings();
  LevelRepository levelRepository = UnavailableLevelRepository(
    'Firebase gagal diinisialisasi: ${firebase.error}',
  );
  if (firebase.ready) {
    remoteSettings = FirebaseRemoteSettings(FirebaseRemoteConfig.instance);
    await remoteSettings.init(); // tidak melempar; gagal -> default
    levelRepository = FirestoreLevelRepository(FirebaseFirestore.instance);
  }

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
        firebaseStatusProvider.overrideWithValue(firebase),
        remoteSettingsProvider.overrideWithValue(remoteSettings),
        levelRepositoryProvider.overrideWithValue(levelRepository),
        // Tanpa Firebase, analytics tetap default (SilentAnalytics).
        if (firebase.ready)
          analyticsProvider.overrideWithValue(FirebaseGameAnalytics()),
      ],
      child: const KirainApp(),
    ),
  );
}

/// Inisialisasi Firebase + Crashlytics. Jika gagal, app tetap jalan dengan
/// level dummy dan tanpa fitur Firebase (tidak crash).
Future<FirebaseStatus> _initFirebase() async {
  try {
    // Android-only: konfigurasi dibaca dari android/app/google-services.json.
    await Firebase.initializeApp();
  } catch (e, st) {
    debugPrint('Firebase gagal diinisialisasi, lanjut tanpa Firebase: $e');
    debugPrintStack(stackTrace: st);
    return FirebaseStatus.failed('$e');
  }

  try {
    // Crash hanya dikirim dari build release agar data tidak tercampur debug.
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Crashlytics gagal disiapkan: $e');
  }
  return const FirebaseStatus.ready();
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
