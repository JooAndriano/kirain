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
///
/// Progress dikunci dengan [order] (Level.order). [nextOrder] = order level
/// berikutnya di daftar, null jika [order] level terakhir.
LevelCompleteResult applyLevelComplete(
  Progress p, {
  required int order,
  required int? nextOrder,
  required int score,
  required int stars,
  required int coins,
}) {
  final firstClear = !p.starsPerLevel.containsKey(order);
  final oldStars = p.starsPerLevel[order] ?? 0;
  final oldScore = p.bestScorePerLevel[order] ?? 0;
  final unlocked = max(p.highestUnlockedLevel, nextOrder ?? order);

  return LevelCompleteResult(
    p.copyWith(
      coins: firstClear ? p.coins + coins : p.coins,
      highestUnlockedLevel: unlocked,
      starsPerLevel: {...p.starsPerLevel, order: max(oldStars, stars)},
      bestScorePerLevel: {...p.bestScorePerLevel, order: max(oldScore, score)},
    ),
    firstClear: firstClear,
  );
}
