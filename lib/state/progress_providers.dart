import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dummy_levels.dart';
import '../data/level.dart';
import '../data/progress.dart';
import '../data/progress_repository.dart';
import '../domain/daily_bonus.dart';
import '../domain/progress_rules.dart';
import '../services/analytics.dart';

final levelsProvider = Provider<List<Level>>((ref) => dummyLevels);

/// Di-override di main.dart dengan LocalProgressRepository.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) =>
      throw UnimplementedError('progressRepositoryProvider belum di-override'),
);

/// Sumber waktu; di-override di tes.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final progressProvider = AsyncNotifierProvider<ProgressNotifier, Progress>(
  ProgressNotifier.new,
);

/// Bonus harian yang tersedia hari ini, null jika sudah diklaim / belum dimuat.
final dailyBonusOfferProvider = Provider<DailyBonusOffer?>((ref) {
  final p = ref.watch(progressProvider).value;
  if (p == null) return null;
  return DailyBonus.check(
    lastDate: p.lastDailyBonusDate,
    streak: p.dailyStreak,
    today: ref.watch(clockProvider)(),
  );
});

class ProgressNotifier extends AsyncNotifier<Progress> {
  ProgressRepository get _repo => ref.read(progressRepositoryProvider);

  @override
  Future<Progress> build() => ref.watch(progressRepositoryProvider).load();

  /// Ubah state lalu langsung simpan.
  Future<void> _update(Progress next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> addCoins(int amount) async {
    final p = await future;
    await _update(p.copyWith(coins: p.coins + amount));
  }

  /// Mengembalikan false (tanpa perubahan) jika koin kurang.
  Future<bool> spendCoins(int amount) async {
    final p = await future;
    if (p.coins < amount) return false;
    await _update(p.copyWith(coins: p.coins - amount));
    return true;
  }

  /// Simpan bintang/skor terbaik, buka level berikutnya, dan beri koin jika
  /// level baru pertama kali selesai. Mengembalikan true jika pertama kali.
  Future<bool> completeLevel(
    int levelId,
    int score,
    int stars, {
    required int coins,
  }) async {
    final p = await future;
    final result = applyLevelComplete(
      p,
      levelId: levelId,
      score: score,
      stars: stars,
      coins: coins,
      levelCount: ref.read(levelsProvider).length,
    );
    await _update(result.progress);
    return result.firstClear;
  }

  /// Klaim bonus harian. Mengembalikan jumlah koin, atau 0 jika sudah diklaim.
  Future<int> claimDailyBonus() async {
    final p = await future;
    final offer = DailyBonus.check(
      lastDate: p.lastDailyBonusDate,
      streak: p.dailyStreak,
      today: ref.read(clockProvider)(),
    );
    if (offer == null) return 0;
    await _update(
      p.copyWith(
        coins: p.coins + offer.amount,
        lastDailyBonusDate: offer.todayKey,
        dailyStreak: offer.newStreak,
      ),
    );
    ref
        .read(analyticsProvider)
        .dailyBonusClaimed(amount: offer.amount, streak: offer.newStreak);
    return offer.amount;
  }
}
