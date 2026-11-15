import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ad_policy.dart';
import '../data/progress.dart';
import '../data/progress_repository.dart';
import '../domain/daily_bonus.dart';
import '../domain/progress_rules.dart';
import '../services/analytics.dart';

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

/// Jumlah rewarded yang sudah ditonton hari ini (reset otomatis saat ganti
/// hari), null jika progress belum dimuat.
final rewardedCountTodayProvider = Provider<int?>((ref) {
  final p = ref.watch(progressProvider).value;
  if (p == null) return null;
  return AdPolicy.rewardedCountToday(
    storedDate: p.rewardedAdDate,
    storedCount: p.rewardedAdCount,
    now: ref.watch(clockProvider)(),
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

  /// Hadiah rewarded: HANYA dipanggil dari onUserEarnedReward. Menambah koin
  /// dan hitungan rewarded hari ini, lalu langsung disimpan.
  Future<void> grantRewardedAd(int coins) async {
    final p = await future;
    await _update(
      applyRewardedAd(p, coins: coins, now: ref.read(clockProvider)()),
    );
  }

  /// Simpan satu gambar benar: koin gambar jika pertama kali, catat skor di
  /// inProgress (stage lain di inProgress diganti), dan tuntaskan stage bila
  /// ketiga gambar sudah benar.
  /// [nextStage] null jika [stage] stage terakhir.
  Future<PuzzleSolvedResult> solvePuzzle({
    required int stage,
    required int slot,
    required String puzzleId,
    required int score,
    required int coins,
    required int? nextStage,
  }) async {
    final p = await future;
    final result = applyPuzzleSolved(
      p,
      stage: stage,
      slot: slot,
      puzzleId: puzzleId,
      score: score,
      coins: coins,
      nextStage: nextStage,
    );
    await _update(result.progress);
    return result;
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
