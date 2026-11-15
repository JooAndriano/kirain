import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/local_progress_repository.dart';
import 'package:kirain/data/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalProgressRepository> repoWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LocalProgressRepository(await SharedPreferences.getInstance());
  }

  test('load tanpa data mengembalikan default (50 koin, stage 1)', () async {
    final repo = await repoWith({});
    final p = await repo.load();
    expect(p.coins, 50);
    expect(p.highestUnlockedStage, 1);
    expect(p.stageStars, isEmpty);
    expect(p.stageBestScore, isEmpty);
    expect(p.clearedPuzzleIds, isEmpty);
    expect(p.inProgress, isNull);
    expect(p.lastDailyBonusDate, isNull);
    expect(p.dailyStreak, 0);
  });

  test('save lalu load menghasilkan progress yang sama', () async {
    final repo = await repoWith({});
    final saved = Progress(
      coins: 123,
      highestUnlockedStage: 3,
      stageStars: {1: 3, 2: 1},
      stageBestScore: {1: 240, 2: 90},
      clearedPuzzleIds: {'stage_001_1', 'stage_001_2'},
      inProgress: StageRun(stage: 3, solved: {1: 80}),
      lastDailyBonusDate: '2026-11-13',
      dailyStreak: 4,
      rewardedAdDate: '2026-11-13',
      rewardedAdCount: 3,
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

  test(
    'format lama (tanpa schemaVersion, berbasis level) -> default',
    () async {
      final old = jsonEncode({
        'coins': 999,
        'highestUnlockedLevel': 7,
        'starsPerLevel': {'1': 3},
        'bestScorePerLevel': {'1': 90},
        'dailyStreak': 2,
      });
      final repo = await repoWith({LocalProgressRepository.storageKey: old});
      expect(await repo.load(), Progress.initial());
    },
  );

  test('schemaVersion lain -> default', () async {
    final other = jsonEncode({
      ...Progress(coins: 999, highestUnlockedStage: 4).toJson(),
      'schemaVersion': 1,
    });
    final repo = await repoWith({LocalProgressRepository.storageKey: other});
    expect(await repo.load(), Progress.initial());
  });

  test('data schemaVersion 2 (sebelum iklan) dimigrasi tanpa kehilangan '
      'progress', () async {
    final v2 = jsonEncode({
      'schemaVersion': 2,
      'coins': 321,
      'highestUnlockedStage': 5,
      'stageStars': {'1': 3, '2': 2},
      'stageBestScore': {'1': 250},
      'clearedPuzzleIds': ['stage_001_1'],
      'inProgress': {
        'stage': 5,
        'solved': {'1': 90},
      },
      'lastDailyBonusDate': '2026-11-12',
      'dailyStreak': 3,
    });
    final repo = await repoWith({LocalProgressRepository.storageKey: v2});
    final p = await repo.load();
    expect(p.coins, 321);
    expect(p.highestUnlockedStage, 5);
    expect(p.stageStars, {1: 3, 2: 2});
    expect(p.inProgress, StageRun(stage: 5, solved: const {1: 90}));
    expect(p.dailyStreak, 3);
    expect(p.rewardedAdDate, isNull);
    expect(p.rewardedAdCount, 0);

    // Save berikutnya menulis format terbaru.
    await repo.save(p);
    final raw = (await SharedPreferences.getInstance()).getString(
      LocalProgressRepository.storageKey,
    );
    expect(jsonDecode(raw!)['schemaVersion'], Progress.schemaVersion);
    expect(Progress.schemaVersion, 3);
  });
}
