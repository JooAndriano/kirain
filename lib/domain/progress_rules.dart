import 'dart:math';

import '../data/progress.dart';

/// Hasil menerapkan penyelesaian level ke progress.
class LevelCompleteResult {
  const LevelCompleteResult(this.progress, {required this.firstClear});
  final Progress progress;

  /// true jika level ini baru pertama kali selesai (koin diberikan).
  final bool firstClear;
}

/// Simpan bintang/skor terbaik saja, buka level berikutnya, dan beri koin
/// hanya saat level pertama kali selesai.
LevelCompleteResult applyLevelComplete(
  Progress p, {
  required int levelId,
  required int score,
  required int stars,
  required int coins,
  required int levelCount,
}) {
  final firstClear = !p.starsPerLevel.containsKey(levelId);
  final oldStars = p.starsPerLevel[levelId] ?? 0;
  final oldScore = p.bestScorePerLevel[levelId] ?? 0;
  final unlocked = max(p.highestUnlockedLevel, min(levelId + 1, levelCount));

  return LevelCompleteResult(
    p.copyWith(
      coins: firstClear ? p.coins + coins : p.coins,
      highestUnlockedLevel: unlocked,
      starsPerLevel: {...p.starsPerLevel, levelId: max(oldStars, stars)},
      bestScorePerLevel: {
        ...p.bestScorePerLevel,
        levelId: max(oldScore, score),
      },
    ),
    firstClear: firstClear,
  );
}
