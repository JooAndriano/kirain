import 'dart:math';

import 'score_engine.dart';

enum GameStatus { playing, correct }

class LetterTile {
  const LetterTile(this.id, this.letter);
  final int id;
  final String letter;
}

/// Tampilan satu huruf di papan.
class TileView {
  const TileView({
    required this.id,
    required this.letter,
    required this.hidden,
    required this.used,
  });
  final int id;
  final String letter;
  final bool hidden;
  final bool used;

  bool get available => !hidden && !used;
}

/// Tampilan satu kotak jawaban.
class SlotView {
  const SlotView({this.letter, this.locked = false});
  final String? letter;
  final bool locked;

  bool get isEmpty => letter == null;
}

/// Potret immutable dari kondisi game, untuk dikonsumsi UI.
class GameSnapshot {
  const GameSnapshot({
    required this.tiles,
    required this.slots,
    required this.status,
    required this.scale,
    required this.score,
    required this.basePoint,
    required this.nextBasePoint,
    required this.scoreAfterZoomOut,
    required this.wrongCount,
    required this.stars,
    required this.coins,
    required this.canRemoveWrong,
    required this.canReveal,
  });

  final List<TileView> tiles;
  final List<SlotView> slots;
  final GameStatus status;
  final double scale;
  final int score;
  final int basePoint;
  final int? nextBasePoint;
  final int? scoreAfterZoomOut;
  final int wrongCount;
  final int stars;
  final int coins;
  final bool canRemoveWrong;
  final bool canReveal;

  bool get canZoomOut => nextBasePoint != null && status == GameStatus.playing;
}

/// Aturan papan huruf dan kotak jawaban untuk satu level.
class GameEngine {
  GameEngine(String answer, {Random? random, this.tileCount = defaultTileCount})
    : answer = answer.toUpperCase() {
    if (this.answer.isEmpty || this.answer.length > tileCount) {
      throw ArgumentError.value(
        answer,
        'answer',
        'panjang harus 1..$tileCount',
      );
    }
    final rnd = random ?? Random();
    final answerLetters = this.answer.split('');
    final decoyPool = _alphabet
        .split('')
        .where((c) => !answerLetters.contains(c))
        .toList();
    final letters = <String>[
      ...answerLetters,
      for (var i = answerLetters.length; i < tileCount; i++)
        decoyPool[rnd.nextInt(decoyPool.length)],
    ];
    // Indeks < answer.length adalah huruf jawaban, sisanya pengecoh.
    _decoyIds = {for (var i = answerLetters.length; i < tileCount; i++) i};
    final shuffled = List.generate(tileCount, (i) => LetterTile(i, letters[i]))
      ..shuffle(rnd);
    tiles = List.unmodifiable(shuffled);
    _tileById = {for (final t in tiles) t.id: t};
    _slots = List<int?>.filled(this.answer.length, null);
  }

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Jumlah huruf di papan = panjang jawaban maksimum.
  static const int defaultTileCount = 14;
  static const int hideCount = 3;

  final String answer;
  final int tileCount;
  final ScoreEngine score = ScoreEngine();

  late final List<LetterTile> tiles;
  late final Map<int, LetterTile> _tileById;
  late final Set<int> _decoyIds;
  late final List<int?> _slots;
  final Set<int> _hidden = {};
  final Set<int> _locked = {};
  GameStatus _status = GameStatus.playing;

  GameStatus get status => _status;
  bool get _playing => _status == GameStatus.playing;

  String? letterAt(int slot) {
    final id = _slots[slot];
    return id == null ? null : _tileById[id]!.letter;
  }

  bool _isUsed(int tileId) => _slots.contains(tileId);

  /// Tap huruf di papan: isi kotak kosong pertama.
  void tapTile(int tileId) {
    if (!_playing || _hidden.contains(tileId) || _isUsed(tileId)) return;
    if (!_tileById.containsKey(tileId)) return;
    final empty = _slots.indexOf(null);
    if (empty < 0) return;
    _slots[empty] = tileId;
    _evaluate();
  }

  /// Tap kotak terisi: kembalikan hurufnya ke papan.
  void tapSlot(int index) {
    if (!_playing || index < 0 || index >= _slots.length) return;
    if (_locked.contains(index)) return;
    _slots[index] = null;
  }

  bool zoomOut() => _playing && score.zoomOut();

  /// Hint: isi satu kotak dengan huruf yang benar dan kunci kotak itu.
  bool revealLetter() {
    if (!_playing) return false;
    final target = _revealTarget();
    if (target < 0) return false;
    final needed = answer[target];

    int? source;
    // Utamakan huruf yang belum dipakai.
    for (final t in tiles) {
      if (t.letter == needed && !_hidden.contains(t.id) && !_isUsed(t.id)) {
        source = t.id;
        break;
      }
    }
    // Kalau tidak ada, ambil dari kotak lain yang salah tempat.
    if (source == null) {
      for (var j = 0; j < _slots.length; j++) {
        if (j == target || _locked.contains(j)) continue;
        if (letterAt(j) == needed && answer[j] != needed) {
          source = _slots[j];
          _slots[j] = null;
          break;
        }
      }
    }
    if (source == null) return false;

    _slots[target] = source;
    _locked.add(target);
    score.addHint();
    _evaluate();
    return true;
  }

  int _revealTarget() {
    for (var i = 0; i < _slots.length; i++) {
      if (_locked.contains(i)) continue;
      if (letterAt(i) != answer[i]) return i;
    }
    return -1;
  }

  List<int> get _visibleDecoys => tiles
      .map((t) => t.id)
      .where((id) => _decoyIds.contains(id) && !_hidden.contains(id))
      .toList();

  /// Hint: sembunyikan hingga 3 huruf pengecoh dari papan.
  bool removeWrongLetters() {
    if (!_playing) return false;
    final candidates = _visibleDecoys;
    if (candidates.isEmpty) return false;
    for (final id in candidates.take(hideCount)) {
      _hidden.add(id);
      final slot = _slots.indexOf(id);
      if (slot >= 0) _slots[slot] = null;
    }
    score.addHint();
    return true;
  }

  void _evaluate() {
    if (_slots.contains(null)) return;
    final guess = List.generate(_slots.length, letterAt).join();
    if (guess == answer) {
      _status = GameStatus.correct;
    } else {
      score.addWrong();
      for (var i = 0; i < _slots.length; i++) {
        if (!_locked.contains(i)) _slots[i] = null;
      }
    }
  }

  GameSnapshot get snapshot => GameSnapshot(
    tiles: List.unmodifiable([
      for (final t in tiles)
        TileView(
          id: t.id,
          letter: t.letter,
          hidden: _hidden.contains(t.id),
          used: _isUsed(t.id),
        ),
    ]),
    slots: List.unmodifiable([
      for (var i = 0; i < _slots.length; i++)
        SlotView(letter: letterAt(i), locked: _locked.contains(i)),
    ]),
    status: _status,
    scale: score.scale,
    score: score.score,
    basePoint: score.basePoint,
    nextBasePoint: score.nextBasePoint,
    scoreAfterZoomOut: score.scoreAfterZoomOut,
    wrongCount: score.wrongCount,
    stars: score.stars,
    coins: score.coins,
    canRemoveWrong: _playing && _visibleDecoys.isNotEmpty,
    canReveal: _playing && _revealTarget() >= 0,
  );
}
