import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/level.dart';
import '../domain/economy.dart';
import '../domain/game_engine.dart';
import '../services/analytics.dart';
import '../state/levels_controller.dart';
import '../state/progress_providers.dart';

enum HintResult { used, notEnoughCoins, unavailable }

class GameState {
  const GameState({
    required this.level,
    required this.snapshot,
    required this.nextOrder,
    this.imageReady = false,
    this.firstClear,
  });

  final Level level;
  final GameSnapshot snapshot;

  /// Order level berikutnya, null jika ini level terakhir.
  final int? nextOrder;

  /// false sampai gambar soal berhasil dimuat. Zoom Out dan hint
  /// dinonaktifkan selama false supaya poin/koin tidak berkurang sia-sia.
  final bool imageReady;

  /// null selama level belum selesai disimpan; true jika baru pertama kali
  /// selesai (koin diberikan), false jika level diulang.
  final bool? firstClear;

  int get order => level.order;
  bool get isLastLevel => nextOrder == null;
  bool get saved => firstClear != null;

  bool get canZoomOut => imageReady && snapshot.canZoomOut;
  bool get canReveal => imageReady && snapshot.canReveal;
  bool get canRemoveWrong => imageReady && snapshot.canRemoveWrong;

  GameState copyWith({
    GameSnapshot? snapshot,
    bool? imageReady,
    bool? firstClear,
  }) => GameState(
    level: level,
    snapshot: snapshot ?? this.snapshot,
    nextOrder: nextOrder,
    imageReady: imageReady ?? this.imageReady,
    firstClear: firstClear ?? this.firstClear,
  );
}

/// Argumen family = Level.order. Level harus sudah ada di
/// [levelsControllerProvider] (GamePage memastikannya).
final gameControllerProvider = NotifierProvider.autoDispose
    .family<GameController, GameState, int>(GameController.new);

/// Menghubungkan GameEngine dan progress ke UI. Aturan game tetap di domain/.
class GameController extends Notifier<GameState> {
  GameController(this.order);

  final int order;
  late GameEngine _engine;
  bool _completing = false;
  bool _hintBusy = false;

  @override
  GameState build() {
    // read, bukan watch: muat ulang daftar level tidak mereset game berjalan.
    final levels = ref.read(levelsControllerProvider).value;
    final level = levels?.byOrder(order);
    if (levels == null || level == null) {
      throw StateError('Level dengan order $order tidak tersedia');
    }
    _engine = GameEngine(level.answer);
    _completing = false;
    ref.read(analyticsProvider).levelStart(level.id);
    return GameState(
      level: level,
      snapshot: _engine.snapshot,
      nextOrder: levels.nextOrderAfter(order),
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

  /// Simpan hasil level sekali saja saat jawaban benar.
  Future<void> _complete() async {
    if (_completing) return;
    _completing = true;
    final s = state.snapshot;
    final firstClear = await ref
        .read(progressProvider.notifier)
        .completeLevel(
          state.order,
          s.score,
          s.stars,
          coins: s.coins,
          nextOrder: state.nextOrder,
        );
    if (!ref.mounted) return;
    ref
        .read(analyticsProvider)
        .levelComplete(
          state.level.id,
          score: s.score,
          stars: s.stars,
          firstClear: firstClear,
        );
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
      ref.read(analyticsProvider).hintUsed(state.level.id, name, cost: cost);
      _emit();
      return HintResult.used;
    } finally {
      _hintBusy = false;
    }
  }
}
