import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/domain/progress_rules.dart';

void main() {
  String id(int stage, int slot) => 'stage_00${stage}_$slot';

  PuzzleSolvedResult solve(
    Progress p,
    int stage,
    int slot,
    int score, {
    int? next,
  }) => applyPuzzleSolved(
    p,
    stage: stage,
    slot: slot,
    puzzleId: id(stage, slot),
    score: score,
    coins: score ~/ 10,
    nextStage: next,
  );

  /// Selesaikan satu stage penuh dengan skor per gambar [scores].
  PuzzleSolvedResult clearStage(
    Progress p,
    int stage,
    List<int> scores, {
    int? next,
  }) {
    late PuzzleSolvedResult r;
    for (var slot = 1; slot <= 3; slot++) {
      r = solve(p, stage, slot, scores[slot - 1], next: next);
      p = r.progress;
    }
    return r;
  }

  final start = Progress(coins: 0, highestUnlockedStage: 1);

  test('gambar pertama: koin gambar, tercatat di inProgress', () {
    final r = solve(start, 1, 1, 80, next: 2);
    expect(r.firstSolve, isTrue);
    expect(r.puzzleCoins, 8);
    expect(r.stageClear, isNull);
    expect(r.progress.coins, 8);
    expect(r.progress.clearedPuzzleIds, {id(1, 1)});
    expect(r.progress.inProgress, StageRun(stage: 1, solved: {1: 80}));
    // Stage belum tuntas: stage berikutnya belum terbuka.
    expect(r.progress.highestUnlockedStage, 1);
  });

  test('stage tuntas: skor = jumlah, bintang, bonus, buka stage berikut', () {
    final r = clearStage(start, 1, [100, 80, 60], next: 2);
    final clear = r.stageClear!;
    expect(clear.totalScore, 240);
    expect(clear.stars, 3);
    expect(clear.firstClear, isTrue);
    expect(clear.bonusCoins, Economy.stageClearBonusCoins);
    final p = r.progress;
    expect(p.coins, 10 + 8 + 6 + Economy.stageClearBonusCoins);
    expect(p.highestUnlockedStage, 2);
    expect(p.stageStars, {1: 3});
    expect(p.stageBestScore, {1: 240});
    expect(p.inProgress, isNull);
  });

  test('koin hanya sekali: mengulang stage tidak memberi koin lagi', () {
    final first = clearStage(start, 1, [100, 80, 60], next: 2).progress;
    final again = clearStage(first, 1, [100, 100, 100], next: 2);
    expect(again.progress.coins, first.coins);
    expect(again.puzzleCoins, 0);
    expect(again.firstSolve, isFalse);
    expect(again.stageClear!.firstClear, isFalse);
    expect(again.stageClear!.bonusCoins, 0);
    expect(again.totalCoins, 0);
  });

  test('bintang dan skor terbaik tidak turun saat ulang lebih buruk', () {
    final best = clearStage(start, 1, [100, 80, 60], next: 2).progress;
    final worse = clearStage(best, 1, [20, 20, 20], next: 2);
    expect(worse.stageClear!.stars, 1); // bintang kali ini
    expect(worse.progress.stageStars[1], 3);
    expect(worse.progress.stageBestScore[1], 240);
  });

  test('ulang lebih baik menaikkan bintang dan skor', () {
    final low = clearStage(start, 1, [40, 40, 40], next: 2).progress;
    expect(low.stageStars[1], 2);
    final high = clearStage(low, 1, [100, 100, 100], next: 2).progress;
    expect(high.stageStars[1], 3);
    expect(high.stageBestScore[1], 300);
  });

  test('stage terakhir (next null) tidak menurunkan unlock', () {
    final p = Progress(coins: 0, highestUnlockedStage: 5);
    final r = clearStage(p, 2, [50, 50, 50]);
    expect(r.progress.highestUnlockedStage, 5);
  });

  test('resume: keluar setelah 2 gambar, lalu gambar 3 menuntaskan stage', () {
    var p = solve(start, 1, 1, 90, next: 2).progress;
    p = solve(p, 1, 2, 70, next: 2).progress;
    // Disimpan lalu dimuat ulang (mis. app ditutup).
    p = Progress.fromJson(p.toJson());
    expect(p.inProgress!.solved, {1: 90, 2: 70});
    final r = solve(p, 1, 3, 50, next: 2);
    expect(r.stageClear!.totalScore, 210);
    expect(r.progress.inProgress, isNull);
  });

  test('main stage lain di tengah: inProgress diganti stage baru', () {
    var p = solve(start, 1, 1, 90, next: 2).progress;
    p = solve(p, 2, 1, 60, next: 3).progress;
    expect(p.inProgress, StageRun(stage: 2, solved: {1: 60}));
    // Kembali ke stage 1: gambar 1 harus diulang, tanpa koin lagi.
    final r = solve(p, 1, 1, 90, next: 2);
    expect(r.puzzleCoins, 0);
    expect(r.progress.inProgress, StageRun(stage: 1, solved: {1: 90}));
  });

  test('applyStartStage: stage sama tidak mengubah, stage lain direset', () {
    final p = solve(start, 1, 1, 90).progress;
    expect(identical(applyStartStage(p, 1), p), isTrue);
    expect(applyStartStage(p, 2).inProgress, StageRun(stage: 2));
  });
}
