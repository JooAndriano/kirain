import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/level.dart';
import '../domain/economy.dart';
import '../domain/game_engine.dart';
import '../state/progress_providers.dart';

enum HintResult { used, notEnoughCoins, unavailable }

class GameState {
  const GameState({
    required this.levelIndex,
    required this.level,
    required this.snapshot,
    required this.levelCount,
    this.firstClear,
  });

  final int levelIndex;
  final Level level;
  final GameSnapshot snapshot;
  final int levelCount;

  /// null selama level belum selesai disimpan; true jika baru pertama kali
  /// selesai (koin diberikan), false jika level diulang.
  final bool? firstClear;

  bool get isLastLevel => levelIndex >= levelCount - 1;
  bool get saved => firstClear != null;

  GameState copyWith({GameSnapshot? snapshot, bool? firstClear}) => GameState(
    levelIndex: levelIndex,
    level: level,
    snapshot: snapshot ?? this.snapshot,
    levelCount: levelCount,
    firstClear: firstClear ?? this.firstClear,
  );
}

/// Argumen family = indeks level di levelsProvider.
final gameControllerProvider = NotifierProvider.autoDispose
    .family<GameController, GameState, int>(GameController.new);

/// Menghubungkan GameEngine dan progress ke UI. Aturan game tetap di domain/.
class GameController extends Notifier<GameState> {
  GameController(this.levelIndex);

  final int levelIndex;
  late GameEngine _engine;
  bool _completing = false;
  bool _hintBusy = false;

  @override
  GameState build() {
    final levels = ref.watch(levelsProvider);
    final level = levels[levelIndex];
    _engine = GameEngine(level.answer);
    _completing = false;
    return GameState(
      levelIndex: levelIndex,
      level: level,
      snapshot: _engine.snapshot,
      levelCount: levels.length,
    );
  }

  void _emit() {
    state = state.copyWith(snapshot: _engine.snapshot);
    if (_engine.status == GameStatus.correct) _complete();
  }

  /// Simpan hasil level sekali saja saat jawaban benar.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    final s = state.snapshot;
    final firstClear = await ref
        .read(progressProvider.notifier)
        .completeLevel(state.level.id, s.score, s.stars, coins: s.coins);
    if (!ref.mounted) return;
    state = state.copyWith(firstClear: firstClear);
  }

  void tapTile(int id) {
    _engine.tapTile(id);
    _emit();
  }

  void tapSlot(int index) {
    _engine.tapSlot(index);
    _emit();
  }

  /// Gratis, hanya mengurangi poin.
  void zoomOut() {
    if (_engine.zoomOut()) _emit();
  }

  Future<HintResult> revealLetter() => _paidHint(
    available: state.snapshot.canReveal,
    cost: Economy.revealLetterCost,
    apply: _engine.revealLetter,
  );

  Future<HintResult> removeWrongLetters() => _paidHint(
    available: state.snapshot.canRemoveWrong,
    cost: Economy.removeWrongCost,
    apply: _engine.removeWrongLetters,
  );

  Future<HintResult> _paidHint({
    required bool available,
    required int cost,
    required bool Function() apply,
  }) async {
    if (!available || _hintBusy) return HintResult.unavailable;
    _hintBusy = true;
    try {
      final paid = await ref.read(progressProvider.notifier).spendCoins(cost);
      if (!paid) return HintResult.notEnoughCoins;
      if (!ref.mounted) return HintResult.unavailable;
      apply();
      _emit();
      return HintResult.used;
    } finally {
      _hintBusy = false;
    }
  }
}
