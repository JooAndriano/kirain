import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/puzzle.dart';
import '../domain/economy.dart';
import '../domain/game_engine.dart';
import '../domain/progress_rules.dart';
import '../domain/stage.dart';
import '../services/analytics.dart';
import '../services/stage_hooks.dart';
import '../state/progress_providers.dart';
import '../state/stages_controller.dart';

enum HintResult { used, notEnoughCoins, unavailable }

/// Kunci game: gambar ke-[slot] (1..3) pada stage [stage].
typedef PuzzleRef = ({int stage, int slot});

class GameState {
  const GameState({
    required this.puzzle,
    required this.snapshot,
    required this.nextStage,
    this.imageReady = false,
    this.result,
  });

  final Puzzle puzzle;
  final GameSnapshot snapshot;

  /// Nomor stage berikutnya, null jika ini stage terakhir.
  final int? nextStage;

  /// false sampai gambar soal berhasil dimuat. Zoom Out dan hint
  /// dinonaktifkan selama false supaya poin/koin tidak berkurang sia-sia.
  final bool imageReady;

  /// null selama gambar belum benar dan tersimpan.
  final PuzzleSolvedResult? result;

  int get stage => puzzle.stage;
  int get slot => puzzle.slot;
  bool get isLastSlot => slot >= Stage.puzzleCount;
  bool get isLastStage => nextStage == null;
  bool get saved => result != null;

  bool get canZoomOut => imageReady && snapshot.canZoomOut;
  bool get canReveal => imageReady && snapshot.canReveal;
  bool get canRemoveWrong => imageReady && snapshot.canRemoveWrong;

  GameState copyWith({
    GameSnapshot? snapshot,
    bool? imageReady,
    PuzzleSolvedResult? result,
  }) => GameState(
    puzzle: puzzle,
    snapshot: snapshot ?? this.snapshot,
    nextStage: nextStage,
    imageReady: imageReady ?? this.imageReady,
    result: result ?? this.result,
  );
}

/// Puzzle harus sudah ada di [stagesControllerProvider] (GamePage
/// memastikannya).
final gameControllerProvider = NotifierProvider.autoDispose
    .family<GameController, GameState, PuzzleRef>(GameController.new);

/// Menghubungkan GameEngine dan progress ke UI. Aturan game tetap di domain/.
class GameController extends Notifier<GameState> {
  GameController(this.key);

  final PuzzleRef key;
  late GameEngine _engine;
  bool _completing = false;
  bool _hintBusy = false;

  @override
  GameState build() {
    // read, bukan watch: muat ulang daftar stage tidak mereset game berjalan.
    final stages = ref.read(stagesControllerProvider).value;
    final puzzle = stages?.puzzleAt(key.stage, key.slot);
    if (stages == null || puzzle == null) {
      throw StateError('Stage ${key.stage} gambar ${key.slot} tidak tersedia');
    }
    _engine = GameEngine(puzzle.answer);
    _completing = false;
    ref.read(analyticsProvider).puzzleStart(puzzle.id);
    return GameState(
      puzzle: puzzle,
      snapshot: _engine.snapshot,
      nextStage: stages.nextAfter(key.stage),
    );
  }

  /// Dipanggil UI saat status gambar soal berubah.
  void setImageReady(bool ready) {
    if (state.imageReady != ready) {
      state = state.copyWith(imageReady: ready);
    }
  }

  void _emit() {
    state = state.copyWith(snapshot: _engine.snapshot);
    if (_engine.status == GameStatus.correct) _complete();
  }

  /// Simpan hasil gambar sekali saja saat jawaban benar. Jika stage tuntas,
  /// panggil [StageCompletionHook] sebelum UI menampilkan dialog stage.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    final s = state.snapshot;
    final puzzle = state.puzzle;
    final result = await ref
        .read(progressProvider.notifier)
        .solvePuzzle(
          stage: puzzle.stage,
          slot: puzzle.slot,
          puzzleId: puzzle.id,
          score: s.score,
          coins: s.coins,
          nextStage: state.nextStage,
        );
    if (!ref.mounted) return;
    final analytics = ref.read(
      analyticsProvider,
    )..puzzleComplete(puzzle.id, score: s.score, firstSolve: result.firstSolve);
    final clear = result.stageClear;
    if (clear != null) {
      analytics.stageComplete(
        clear.stage,
        score: clear.totalScore,
        stars: clear.stars,
        firstClear: clear.firstClear,
      );
      try {
        await ref
            .read(stageCompletionHookProvider)
            .onStageCompleted(clear.stage);
      } catch (_) {
        // Hook (nanti iklan) tidak boleh menghentikan alur game.
      }
      if (!ref.mounted) return;
    }
    state = state.copyWith(result: result);
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
  /// Ditolak selama gambar belum termuat.
  void zoomOut() {
    if (!state.canZoomOut) return;
    if (_engine.zoomOut()) _emit();
  }

  Future<HintResult> revealLetter() => _paidHint(
    name: 'reveal_letter',
    available: state.canReveal,
    cost: Economy.revealLetterCost,
    apply: _engine.revealLetter,
  );

  Future<HintResult> removeWrongLetters() => _paidHint(
    name: 'remove_wrong_letters',
    available: state.canRemoveWrong,
    cost: Economy.removeWrongCost,
    apply: _engine.removeWrongLetters,
  );

  Future<HintResult> _paidHint({
    required String name,
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
      ref.read(analyticsProvider).hintUsed(state.puzzle.id, name, cost: cost);
      _emit();
      return HintResult.used;
    } finally {
      _hintBusy = false;
    }
  }
}
