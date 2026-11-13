import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/progress_rules.dart';

void main() {
  LevelCompleteResult apply(Progress p, int id, int score, int stars) =>
      applyLevelComplete(
        p,
        levelId: id,
        score: score,
        stars: stars,
        coins: score ~/ 10,
        levelCount: 5,
      );

  test(
    'selesai pertama: simpan bintang/skor, buka level berikutnya, +koin',
    () {
      final r = apply(Progress.initial(), 1, 80, 3);
      expect(r.firstClear, isTrue);
      expect(r.progress.starsPerLevel[1], 3);
      expect(r.progress.bestScorePerLevel[1], 80);
      expect(r.progress.highestUnlockedLevel, 2);
      expect(r.progress.coins, 58);
    },
  );

  test('tidak menimpa bintang/skor lebih tinggi, tanpa koin saat ulang', () {
    final first = apply(Progress.initial(), 1, 80, 3).progress;
    final r = apply(first, 1, 30, 1);
    expect(r.firstClear, isFalse);
    expect(r.progress.starsPerLevel[1], 3);
    expect(r.progress.bestScorePerLevel[1], 80);
    expect(r.progress.coins, first.coins);
  });

  test('skor lebih baik saat ulang tetap tersimpan', () {
    final first = apply(Progress.initial(), 1, 30, 1).progress;
    final r = apply(first, 1, 90, 3);
    expect(r.progress.starsPerLevel[1], 3);
    expect(r.progress.bestScorePerLevel[1], 90);
  });

  test('level terakhir tidak membuka level di luar jumlah level', () {
    final p = Progress(coins: 0, highestUnlockedLevel: 5);
    expect(apply(p, 5, 50, 2).progress.highestUnlockedLevel, 5);
  });

  test('mengulang level awal tidak menurunkan level terbuka', () {
    final p = Progress(coins: 0, highestUnlockedLevel: 4);
    expect(apply(p, 1, 50, 2).progress.highestUnlockedLevel, 4);
  });
}
