import 'dart:math';

import '../data/progress.dart';
import 'economy.dart';
import 'stage.dart';

/// Hasil saat stage tuntas (ketiga gambar benar).
class StageClearResult {
  const StageClearResult({
    required this.stage,
    required this.totalScore,
    required this.stars,
    required this.firstClear,
    required this.bonusCoins,
  });

  final int stage;
  final int totalScore;

  /// Bintang dari skor kali ini (bukan bintang terbaik).
  final int stars;

  /// true jika stage ini baru pertama kali tuntas.
  final bool firstClear;

  /// [Economy.stageClearBonusCoins] saat [firstClear], selain itu 0.
  final int bonusCoins;
}

/// Hasil menerapkan satu gambar benar ke progress.
class PuzzleSolvedResult {
  const PuzzleSolvedResult(
    this.progress, {
    required this.puzzleCoins,
    required this.firstSolve,
    this.stageClear,
  });

  final Progress progress;

  /// Koin gambar yang diberikan (0 jika puzzle sudah pernah benar).
  final int puzzleCoins;

  /// true jika puzzle ini baru pertama kali benar.
  final bool firstSolve;

  /// Tidak null jika gambar ini menuntaskan stage.
  final StageClearResult? stageClear;

  /// Total koin yang masuk dari gambar ini (termasuk bonus stage).
  int get totalCoins => puzzleCoins + (stageClear?.bonusCoins ?? 0);
}

/// Memulai (atau melanjutkan) [stage]: jika [Progress.inProgress] milik
/// stage lain, diganti stage ini dengan daftar solved kosong.
Progress applyStartStage(Progress p, int stage) {
  if (p.inProgress?.stage == stage) return p;
  return p.copyWith(inProgress: StageRun(stage: stage));
}

/// Satu gambar ([slot] pada [stage]) dijawab benar.
///
/// - Koin gambar ([coins]) hanya jika [puzzleId] belum pernah benar.
/// - Skor dicatat di inProgress. Jika ketiga slot sudah terisi, stage tuntas:
///   skor stage = jumlah skor 3 gambar; skor dan bintang terbaik disimpan
///   (tidak pernah turun); bonus stage hanya saat pertama kali tuntas; stage
///   berikutnya ([nextStage], null jika terakhir) dibuka; inProgress dihapus.
PuzzleSolvedResult applyPuzzleSolved(
  Progress p, {
  required int stage,
  required int slot,
  required String puzzleId,
  required int score,
  required int coins,
  required int? nextStage,
}) {
  final firstSolve = !p.clearedPuzzleIds.contains(puzzleId);
  final puzzleCoins = firstSolve ? coins : 0;

  final run = applyStartStage(p, stage).inProgress!;
  final solved = {...run.solved, slot: score};

  var next = p.copyWith(
    coins: p.coins + puzzleCoins,
    clearedPuzzleIds: {...p.clearedPuzzleIds, puzzleId},
    inProgress: StageRun(stage: stage, solved: solved),
  );

  final complete = List.generate(
    Stage.puzzleCount,
    (i) => i + 1,
  ).every(solved.containsKey);
  if (!complete) {
    return PuzzleSolvedResult(
      next,
      puzzleCoins: puzzleCoins,
      firstSolve: firstSolve,
    );
  }

  final total = solved.values.fold(0, (a, b) => a + b);
  final stars = Economy.stageStars(total);
  final firstClear = !p.stageStars.containsKey(stage);
  final bonus = firstClear ? Economy.stageClearBonusCoins : 0;

  next = next.copyWith(
    coins: next.coins + bonus,
    highestUnlockedStage: max(p.highestUnlockedStage, nextStage ?? stage),
    stageStars: {...p.stageStars, stage: max(p.stageStars[stage] ?? 0, stars)},
    stageBestScore: {
      ...p.stageBestScore,
      stage: max(p.stageBestScore[stage] ?? 0, total),
    },
    clearInProgress: true,
  );

  return PuzzleSolvedResult(
    next,
    puzzleCoins: puzzleCoins,
    firstSolve: firstSolve,
    stageClear: StageClearResult(
      stage: stage,
      totalScore: total,
      stars: stars,
      firstClear: firstClear,
      bonusCoins: bonus,
    ),
  );
}
