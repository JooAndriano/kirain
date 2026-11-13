import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dummy_levels.dart';
import '../data/level.dart';
import '../domain/game_engine.dart';

class GameState {
  const GameState({
    required this.levelIndex,
    required this.level,
    required this.snapshot,
    required this.totalCoins,
    required this.finished,
    required this.levelCount,
  });

  final int levelIndex;
  final Level level;
  final GameSnapshot snapshot;
  final int totalCoins;
  final bool finished;
  final int levelCount;
}

final levelsProvider = Provider<List<Level>>((ref) => dummyLevels);

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

/// Menghubungkan GameEngine ke UI. Aturan game tetap di domain/.
class GameController extends Notifier<GameState> {
  late GameEngine _engine;
  late List<Level> _levels;

  @override
  GameState build() {
    _levels = ref.watch(levelsProvider);
    return _startLevel(0, totalCoins: 0);
  }

  GameState _startLevel(int index, {required int totalCoins}) {
    final level = _levels[index];
    _engine = GameEngine(level.answer);
    return GameState(
      levelIndex: index,
      level: level,
      snapshot: _engine.snapshot,
      totalCoins: totalCoins,
      finished: false,
      levelCount: _levels.length,
    );
  }

  void _emit() {
    state = GameState(
      levelIndex: state.levelIndex,
      level: state.level,
      snapshot: _engine.snapshot,
      totalCoins: state.totalCoins,
      finished: state.finished,
      levelCount: state.levelCount,
    );
  }

  void tapTile(int id) {
    _engine.tapTile(id);
    _emit();
  }

  void tapSlot(int index) {
    _engine.tapSlot(index);
    _emit();
  }

  void zoomOut() {
    if (_engine.zoomOut()) _emit();
  }

  void revealLetter() {
    if (_engine.revealLetter()) _emit();
  }

  void removeWrongLetters() {
    if (_engine.removeWrongLetters()) _emit();
  }

  /// Simpan koin level ini lalu pindah ke level berikutnya / layar selesai.
  void nextLevel() {
    if (_engine.status != GameStatus.correct) return;
    final coins = state.totalCoins + _engine.score.coins;
    final next = state.levelIndex + 1;
    if (next >= _levels.length) {
      state = GameState(
        levelIndex: state.levelIndex,
        level: state.level,
        snapshot: _engine.snapshot,
        totalCoins: coins,
        finished: true,
        levelCount: state.levelCount,
      );
    } else {
      state = _startLevel(next, totalCoins: coins);
    }
  }

  void restart() {
    state = _startLevel(0, totalCoins: 0);
  }
}
