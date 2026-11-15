import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_manager.dart';
import 'ads/google_ad_manager.dart';
import 'data/firebase_remote_settings.dart';
import 'data/firestore_puzzle_repository.dart';
import 'data/puzzle_cache.dart';
import 'data/puzzle_repository.dart';
import 'data/local_progress_repository.dart';
import 'data/local_settings_repository.dart';
import 'data/remote_settings.dart';
import 'services/analytics.dart';
import 'services/game_audio.dart';
import 'state/firebase_providers.dart';
import 'state/progress_providers.dart';
import 'state/settings_providers.dart';
import 'state/stages_controller.dart';
import 'ui/splash_page.dart';
import 'ui/theme.dart';
import 'ui/widgets/background_music.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase = await _initFirebase();
  RemoteSettings remoteSettings = const DefaultRemoteSettings();
  PuzzleRepository puzzleRepository = UnavailablePuzzleRepository(
    'Firebase gagal diinisialisasi: ${firebase.error}',
  );
  if (firebase.ready) {
    remoteSettings = FirebaseRemoteSettings(FirebaseRemoteConfig.instance);
    await remoteSettings.init(); // tidak melempar; gagal -> default
    puzzleRepository = FirestorePuzzleRepository(FirebaseFirestore.instance);
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
        puzzleRepositoryProvider.overrideWithValue(puzzleRepository),
        puzzleCacheProvider.overrideWithValue(LocalPuzzleCache(prefs)),
        // Tanpa Firebase, analytics tetap default (SilentAnalytics).
        if (firebase.ready)
          analyticsProvider.overrideWithValue(FirebaseGameAnalytics()),
        // Iklan (TES selama ID asli kosong). init() dipanggil di SplashPage.
        adManagerProvider.overrideWith((ref) {
          final manager = GoogleAdManager(
            params: () => ref.read(remoteSettingsProvider).adParams,
            clock: ref.read(clockProvider),
          );
          ref.onDispose(manager.dispose);
          return manager;
        }),
      ],
      child: const KirainApp(),
    ),
  );
}

/// Inisialisasi Firebase + Crashlytics. Jika gagal, app tetap jalan dengan
/// stage dummy dan tanpa fitur Firebase (tidak crash).
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
