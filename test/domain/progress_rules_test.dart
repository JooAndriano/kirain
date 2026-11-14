import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/progress_rules.dart';

void main() {
  LevelCompleteResult apply(
    Progress p,
    int order,
    int score,
    int stars, {
    int? next,
  }) => applyLevelComplete(
    p,
    order: order,
    nextOrder: next,
    score: score,
    stars: stars,
    coins: score ~/ 10,
  );

  test(
    'selesai pertama: simpan bintang/skor, buka level berikutnya, +koin',
    () {
      final r = apply(Progress.initial(), 1, 80, 3, next: 2);
      expect(r.firstClear, isTrue);
      expect(r.progress.starsPerLevel[1], 3);
      expect(r.progress.bestScorePerLevel[1], 80);
      expect(r.progress.highestUnlockedLevel, 2);
      expect(r.progress.coins, 58);
    },
  );

  test('tidak menimpa bintang/skor lebih tinggi, tanpa koin saat ulang', () {
    final first = apply(Progress.initial(), 1, 80, 3, next: 2).progress;
    final r = apply(first, 1, 30, 1, next: 2);
    expect(r.firstClear, isFalse);
    expect(r.progress.starsPerLevel[1], 3);
    expect(r.progress.bestScorePerLevel[1], 80);
    expect(r.progress.coins, first.coins);
  });

  test('skor lebih baik saat ulang tetap tersimpan', () {
    final first = apply(Progress.initial(), 1, 30, 1, next: 2).progress;
    final r = apply(first, 1, 90, 3, next: 2);
    expect(r.progress.starsPerLevel[1], 3);
    expect(r.progress.bestScorePerLevel[1], 90);
  });

  test('level terakhir (nextOrder null) tidak membuka level baru', () {
    final p = Progress(coins: 0, highestUnlockedLevel: 5);
    expect(apply(p, 5, 50, 2).progress.highestUnlockedLevel, 5);
  });

  test('mengulang level awal tidak menurunkan level terbuka', () {
    final p = Progress(coins: 0, highestUnlockedLevel: 4);
    expect(apply(p, 1, 50, 2, next: 2).progress.highestUnlockedLevel, 4);
  });

  test('progress dikunci order, order bercelah membuka order berikutnya', () {
    final p = Progress(coins: 0, highestUnlockedLevel: 10);
    final r = apply(p, 10, 70, 3, next: 25);
    expect(r.progress.highestUnlockedLevel, 25);
    expect(r.progress.starsPerLevel.keys, [10]);
    expect(r.progress.bestScorePerLevel[10], 70);
  });
}
