import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/ads/ad_manager.dart';
import 'package:kirain/ads/ad_policy.dart';
import 'package:kirain/ads/rewarded_ad_controller.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/progress_providers.dart';

import '../support/fakes.dart';

void main() {
  late MemProgressRepo repo;
  late FakeAdManager ads;
  late FixedRemoteSettings settings;
  late DateTime now;

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [
      progressRepositoryProvider.overrideWithValue(repo),
      adManagerProvider.overrideWithValue(ads),
      remoteSettingsProvider.overrideWithValue(settings),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  setUp(() {
    repo = MemProgressRepo(Progress(coins: 10, highestUnlockedStage: 1));
    ads = FakeAdManager();
    settings = FixedRemoteSettings();
    now = DateTime(2026, 11, 15, 9);
  });

  Future<RewardedResult> watch(ProviderContainer c) =>
      c.read(rewardedAdControllerProvider).watchForCoins();

  test('reward diterima -> koin bertambah, tersimpan, hitungan naik', () async {
    final c = makeContainer();
    final r = await watch(c);
    expect(r.outcome, RewardedOutcome.rewarded);
    expect(r.coins, 25);
    expect(r.message, '+25 koin!');
    expect(repo.saved.coins, 35);
    expect(repo.saved.rewardedAdDate, '2026-11-15');
    expect(repo.saved.rewardedAdCount, 1);
    expect(c.read(rewardedCountTodayProvider), 1);
  });

  test('jumlah koin mengikuti Remote Config rewardedCoins', () async {
    settings.adParams = const AdParams(rewardedCoins: 40);
    final r = await watch(makeContainer());
    expect(r.coins, 40);
    expect(repo.saved.coins, 50);
  });

  test('iklan ditutup sebelum selesai -> TANPA koin', () async {
    ads.earnReward = false;
    final r = await watch(makeContainer());
    expect(ads.rewardedShows, 1);
    expect(r.outcome, RewardedOutcome.notRewarded);
    expect(repo.saved.coins, 10);
    expect(repo.saved.rewardedAdCount, 0);
  });

  test('gagal tampil -> belum tersedia, tanpa koin', () async {
    ads
      ..earnReward = false
      ..notEarnedResult = RewardedShowResult.failed;
    final r = await watch(makeContainer());
    expect(r.outcome, RewardedOutcome.unavailable);
    expect(repo.saved.coins, 10);
  });

  test('iklan belum termuat -> pesan ramah, tanpa koin', () async {
    ads.rewardedReady = false;
    final r = await watch(makeContainer());
    expect(r.outcome, RewardedOutcome.unavailable);
    expect(r.message, 'Iklan belum tersedia, coba lagi sebentar lagi');
    expect(ads.rewardedShows, 0);
    expect(repo.saved.coins, 10);
  });

  test('adsEnabled false -> tidak menampilkan iklan', () async {
    settings.adParams = const AdParams(adsEnabled: false);
    final r = await watch(makeContainer());
    expect(r.outcome, RewardedOutcome.unavailable);
    expect(ads.rewardedShows, 0);
  });

  test('batas harian tercapai -> iklan tidak ditampilkan', () async {
    repo.saved = repo.saved.copyWith(
      rewardedAdDate: '2026-11-15',
      rewardedAdCount: 10,
    );
    final r = await watch(makeContainer());
    expect(r.outcome, RewardedOutcome.dailyCapReached);
    expect(r.message, 'Batas iklan hari ini tercapai');
    expect(ads.rewardedShows, 0);
    expect(repo.saved.coins, 10);
  });

  test('batas harian dihitung dari tontonan berturut-turut', () async {
    settings.adParams = const AdParams(rewardedDailyCap: 2);
    final c = makeContainer();
    expect((await watch(c)).outcome, RewardedOutcome.rewarded);
    expect((await watch(c)).outcome, RewardedOutcome.rewarded);
    expect((await watch(c)).outcome, RewardedOutcome.dailyCapReached);
    expect(repo.saved.coins, 60);
    expect(ads.rewardedShows, 2);
  });

  test('ganti hari (tanggal lokal) -> hitungan reset otomatis', () async {
    repo.saved = repo.saved.copyWith(
      rewardedAdDate: '2026-11-14',
      rewardedAdCount: 10,
    );
    final c = makeContainer();
    expect(c.read(rewardedCountTodayProvider), isNull); // belum dimuat
    await c.read(progressProvider.future);
    expect(c.read(rewardedCountTodayProvider), 0);

    final r = await watch(c);
    expect(r.outcome, RewardedOutcome.rewarded);
    expect(repo.saved.rewardedAdDate, '2026-11-15');
    expect(repo.saved.rewardedAdCount, 1);
  });

  test('tengah malam saat app terbuka: batas kemarin tidak berlaku', () async {
    settings.adParams = const AdParams(rewardedDailyCap: 1);
    now = DateTime(2026, 11, 15, 23, 59);
    final c = makeContainer();
    expect((await watch(c)).outcome, RewardedOutcome.rewarded);
    expect((await watch(c)).outcome, RewardedOutcome.dailyCapReached);

    now = DateTime(2026, 11, 16, 0, 1);
    expect((await watch(c)).outcome, RewardedOutcome.rewarded);
    expect(repo.saved.rewardedAdDate, '2026-11-16');
    expect(repo.saved.rewardedAdCount, 1);
  });
}
