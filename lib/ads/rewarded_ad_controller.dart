import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/firebase_providers.dart';
import '../state/progress_providers.dart';
import 'ad_manager.dart';
import 'ad_policy.dart';

enum RewardedOutcome {
  /// Hadiah diberikan dan tersimpan.
  rewarded,

  /// Iklan ditutup sebelum selesai: tanpa hadiah.
  notRewarded,

  /// Iklan belum termuat / iklan nonaktif / gagal tampil.
  unavailable,

  /// Batas rewarded harian (tanggal lokal) sudah tercapai.
  dailyCapReached,
}

class RewardedResult {
  const RewardedResult(this.outcome, {this.coins = 0});

  final RewardedOutcome outcome;

  /// Koin yang ditambahkan (hanya > 0 untuk [RewardedOutcome.rewarded]).
  final int coins;

  /// Pesan ramah untuk pemain.
  String get message => switch (outcome) {
    RewardedOutcome.rewarded => '+$coins koin!',
    RewardedOutcome.notRewarded =>
      'Tonton iklan sampai selesai untuk mendapat koin',
    RewardedOutcome.unavailable =>
      'Iklan belum tersedia, coba lagi sebentar lagi',
    RewardedOutcome.dailyCapReached => 'Batas iklan hari ini tercapai',
  };
}

/// Alur "tonton iklan untuk koin" dipakai Toko dan dialog "Koin tidak
/// cukup". Koin ditambahkan HANYA di dalam callback onUserEarnedReward.
class RewardedAdController {
  RewardedAdController(this._ref);

  final Ref _ref;
  bool _busy = false;

  Future<RewardedResult> watchForCoins() async {
    if (_busy) return const RewardedResult(RewardedOutcome.unavailable);
    _busy = true;
    try {
      return await _watch();
    } finally {
      _busy = false;
    }
  }

  Future<RewardedResult> _watch() async {
    final params = _ref.read(remoteSettingsProvider).adParams;
    if (!params.adsEnabled) {
      return const RewardedResult(RewardedOutcome.unavailable);
    }
    final p = await _ref.read(progressProvider.future);
    final countToday = AdPolicy.rewardedCountToday(
      storedDate: p.rewardedAdDate,
      storedCount: p.rewardedAdCount,
      now: _ref.read(clockProvider)(),
    );
    if (!AdPolicy.canShowRewarded(
      rewardedCountToday: countToday,
      params: params,
    )) {
      return const RewardedResult(RewardedOutcome.dailyCapReached);
    }

    final ads = _ref.read(adManagerProvider);
    if (!ads.isRewardedReady) {
      return const RewardedResult(RewardedOutcome.unavailable);
    }

    final notifier = _ref.read(progressProvider.notifier);
    Future<void>? grant;
    final shown = await ads.showRewarded(
      onUserEarnedReward: () {
        grant ??= notifier.grantRewardedAd(params.rewardedCoins);
      },
    );
    if (grant != null) {
      await grant;
      return RewardedResult(
        RewardedOutcome.rewarded,
        coins: params.rewardedCoins,
      );
    }
    return switch (shown) {
      RewardedShowResult.dismissed || RewardedShowResult.earned =>
        const RewardedResult(RewardedOutcome.notRewarded),
      RewardedShowResult.notReady || RewardedShowResult.failed =>
        const RewardedResult(RewardedOutcome.unavailable),
    };
  }
}

final rewardedAdControllerProvider = Provider<RewardedAdController>(
  RewardedAdController.new,
);
