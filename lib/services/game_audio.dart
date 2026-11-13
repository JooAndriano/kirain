import 'package:audioplayers/audioplayers.dart';

/// Pemutar suara game. Default di provider adalah [SilentGameAudio];
/// main.dart meng-override dengan [AudioplayersGameAudio].
abstract class GameAudio {
  Future<void> startMusic();
  Future<void> stopMusic();
  Future<void> playCorrect();
  Future<void> playWrong();
  Future<void> dispose();
}

/// Tidak memutar apa pun (untuk tes).
class SilentGameAudio implements GameAudio {
  const SilentGameAudio();
  @override
  Future<void> startMusic() async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> playCorrect() async {}
  @override
  Future<void> playWrong() async {}
  @override
  Future<void> dispose() async {}
}

class AudioplayersGameAudio implements GameAudio {
  static const _music = 'sound/backsound-loop.mp3';
  static const _correct = 'sound/right-answer.mp3';
  static const _wrong = 'sound/wrong-answer.mp3';
  static const _musicVolume = 0.4;

  final _musicPlayer = AudioPlayer(playerId: 'kirain-music');
  final _sfxPlayer = AudioPlayer(playerId: 'kirain-sfx');
  bool _ready = false;
  bool _musicOn = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_musicVolume);
    // Efek suara tidak meminta audio focus agar backsound tidak terhenti.
    await _sfxPlayer.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  Future<void> startMusic() async {
    await _init();
    if (_musicOn) return;
    _musicOn = true;
    await _musicPlayer.play(AssetSource(_music));
  }

  @override
  Future<void> stopMusic() async {
    if (!_musicOn) return;
    _musicOn = false;
    await _musicPlayer.pause();
  }

  @override
  Future<void> playCorrect() => _playSfx(_correct);

  @override
  Future<void> playWrong() => _playSfx(_wrong);

  Future<void> _playSfx(String path) async {
    await _init();
    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource(path));
  }

  @override
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
