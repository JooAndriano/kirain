import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/local_progress_repository.dart';
import 'package:kirain/data/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalProgressRepository> repoWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LocalProgressRepository(await SharedPreferences.getInstance());
  }

  test('load tanpa data mengembalikan default (50 koin, level 1)', () async {
    final repo = await repoWith({});
    final p = await repo.load();
    expect(p.coins, 50);
    expect(p.highestUnlockedLevel, 1);
    expect(p.starsPerLevel, isEmpty);
    expect(p.bestScorePerLevel, isEmpty);
    expect(p.lastDailyBonusDate, isNull);
    expect(p.dailyStreak, 0);
  });

  test('save lalu load menghasilkan progress yang sama', () async {
    final repo = await repoWith({});
    final saved = Progress(
      coins: 123,
      highestUnlockedLevel: 3,
      starsPerLevel: {1: 3, 2: 1},
      bestScorePerLevel: {1: 90, 2: 30},
      lastDailyBonusDate: '2026-11-13',
      dailyStreak: 4,
    );
    await repo.save(saved);

    // Instance baru dari prefs yang sama, seolah app dibuka ulang.
    final reloaded = LocalProgressRepository(
      await SharedPreferences.getInstance(),
    );
    expect(await reloaded.load(), saved);
  });

  test('JSON rusak kembali ke default', () async {
    final repo = await repoWith({LocalProgressRepository.storageKey: '{oops'});
    expect(await repo.load(), Progress.initial());
  });
}
