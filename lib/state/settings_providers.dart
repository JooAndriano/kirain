import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings.dart';
import '../data/settings_repository.dart';
import '../services/game_audio.dart';

/// Di-override di main.dart dengan LocalSettingsRepository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw UnimplementedError('settingsRepositoryProvider belum di-override'),
);

/// Di-override di main.dart dengan AudioplayersGameAudio.
final gameAudioProvider = Provider<GameAudio>((ref) => const SilentGameAudio());

/// Getaran; di-override di tes.
final hapticsProvider = Provider<Haptics>((ref) => const Haptics());

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> setMusic(bool on) => _update((s) => s.copyWith(music: on));
  Future<void> setSoundEffects(bool on) =>
      _update((s) => s.copyWith(soundEffects: on));
  Future<void> setVibration(bool on) =>
      _update((s) => s.copyWith(vibration: on));
  Future<void> markTutorialSeen() =>
      _update((s) => s.copyWith(tutorialSeen: true));

  /// Tutorial tampil lagi saat pemain mulai bermain berikutnya.
  Future<void> replayTutorial() =>
      _update((s) => s.copyWith(tutorialSeen: false));

  Future<void> _update(AppSettings Function(AppSettings) change) async {
    final next = change(await future);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

/// Getar kuat lewat Vibrator Android (MainActivity.kt). HapticFeedback bawaan
/// Flutter terlalu halus dan bergantung pada setelan sentuhan sistem.
class Haptics {
  const Haptics();

  static const _channel = MethodChannel('kirain/vibration');
  static const wrongMs = 400;

  Future<void> wrong() async {
    try {
      await _channel.invokeMethod<void>('vibrate', {'ms': wrongMs});
    } on MissingPluginException {
      // Tidak ada implementasi native (mis. di tes).
    } on PlatformException {
      // Perangkat tanpa vibrator atau getar diblokir sistem.
    }
  }
}

final gameFeedbackProvider = Provider<GameFeedback>(GameFeedback.new);

/// Suara saat jawaban benar/salah dan getar hanya saat salah, mengikuti
/// pengaturan pemain.
class GameFeedback {
  GameFeedback(this._ref);
  final Ref _ref;

  // Sebelum pengaturan termuat, pakai default (semua aktif).
  AppSettings get _s =>
      _ref.read(settingsProvider).value ?? const AppSettings();

  void correct() {
    if (_s.soundEffects) _ref.read(gameAudioProvider).playCorrect();
  }

  void wrong() {
    final s = _s;
    if (s.soundEffects) _ref.read(gameAudioProvider).playWrong();
    if (s.vibration) _ref.read(hapticsProvider).wrong();
  }
}
