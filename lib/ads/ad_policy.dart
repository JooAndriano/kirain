import 'dart:math';

import '../domain/daily_bonus.dart' show formatDate;

/// Parameter iklan dari Remote Config. Immutable; nilai bawaan aman.
class AdParams {
  const AdParams({
    this.adsEnabled = true,
    this.interstitialEveryNStages = 1,
    this.interstitialStartAfterStage = 2,
    this.interstitialMinIntervalSeconds = 120,
    this.rewardedCoins = 25,
    this.rewardedDailyCap = 10,
  });

  static const defaults = AdParams();

  final bool adsEnabled;

  /// Interstitial hanya pada stage kelipatan N. Nilai < 1 dianggap 1.
  final int interstitialEveryNStages;

  /// Interstitial pertama paling cepat setelah stage ini selesai.
  final int interstitialStartAfterStage;

  /// Jarak minimum antar-iklan layar penuh (interstitial ATAU rewarded).
  final int interstitialMinIntervalSeconds;

  /// Koin per rewarded yang ditonton sampai selesai.
  final int rewardedCoins;

  /// Maksimum rewarded per hari (tanggal lokal). 0 = rewarded mati.
  final int rewardedDailyCap;

  @override
  bool operator ==(Object other) =>
      other is AdParams &&
      other.adsEnabled == adsEnabled &&
      other.interstitialEveryNStages == interstitialEveryNStages &&
      other.interstitialStartAfterStage == interstitialStartAfterStage &&
      other.interstitialMinIntervalSeconds == interstitialMinIntervalSeconds &&
      other.rewardedCoins == rewardedCoins &&
      other.rewardedDailyCap == rewardedDailyCap;

  @override
  int get hashCode => Object.hash(
    adsEnabled,
    interstitialEveryNStages,
    interstitialStartAfterStage,
    interstitialMinIntervalSeconds,
    rewardedCoins,
    rewardedDailyCap,
  );

  @override
  String toString() =>
      'AdParams(adsEnabled: $adsEnabled, everyN: $interstitialEveryNStages, '
      'startAfter: $interstitialStartAfterStage, '
      'minInterval: ${interstitialMinIntervalSeconds}s, '
      'rewardedCoins: $rewardedCoins, dailyCap: $rewardedDailyCap)';
}

/// Keputusan kapan iklan boleh tampil. Dart murni, tanpa Flutter/SDK.
abstract final class AdPolicy {
  /// Interstitial setelah [stageNumber] selesai (atas aksi pemain).
  ///
  /// [lastAdShownAt]: waktu iklan layar penuh terakhir (interstitial atau
  /// rewarded), null jika belum pernah. Jika jam mundur ([lastAdShownAt]
  /// setelah [now]), jarak dianggap tidak diketahui dan tidak menghalangi.
  static bool shouldShowInterstitial({
    required int stageNumber,
    required DateTime now,
    required DateTime? lastAdShownAt,
    required AdParams params,
  }) {
    if (!params.adsEnabled) return false;
    if (stageNumber < 1) return false;
    if (stageNumber < params.interstitialStartAfterStage) return false;
    final everyN = max(1, params.interstitialEveryNStages);
    if (stageNumber % everyN != 0) return false;
    if (lastAdShownAt != null) {
      final elapsed = now.difference(lastAdShownAt);
      final minInterval = Duration(
        seconds: max(0, params.interstitialMinIntervalSeconds),
      );
      if (!elapsed.isNegative && elapsed < minInterval) return false;
    }
    return true;
  }

  /// false jika iklan dimatikan atau batas harian sudah tercapai.
  static bool canShowRewarded({
    required int rewardedCountToday,
    required AdParams params,
  }) {
    if (!params.adsEnabled) return false;
    return rewardedCountToday < params.rewardedDailyCap;
  }

  /// Jumlah rewarded hari ini (tanggal lokal [now]). Otomatis 0 jika
  /// [storedDate] bukan hari ini (ganti hari, belum pernah, atau rusak).
  static int rewardedCountToday({
    required String? storedDate,
    required int storedCount,
    required DateTime now,
  }) {
    if (storedDate != formatDate(now)) return 0;
    return max(0, storedCount);
  }

  /// Jeda sebelum mencoba memuat ulang iklan setelah gagal ke-[attempt]
  /// (1, 2, ...): 5 dtk, 10, 20, ... maksimal 5 menit.
  static Duration retryDelay(int attempt) {
    if (attempt < 1) return Duration.zero;
    final seconds = 5 * pow(2, min(attempt - 1, 10)).toInt();
    return Duration(seconds: min(seconds, maxRetryDelaySeconds));
  }

  static const int maxRetryDelaySeconds = 300;
}
