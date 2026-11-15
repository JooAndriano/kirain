import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/ads/ads_config.dart';
import 'package:kirain/data/firebase_remote_settings.dart';
import 'package:kirain/ads/ad_policy.dart';

void main() {
  group('AdIds.resolveUseTestAds', () {
    const full = ['b', 'i', 'r'];

    test('debug selalu tes, walau ID asli lengkap', () {
      expect(AdIds.resolveUseTestAds(debug: true, prodIds: full), isTrue);
    });

    test('rilis dengan ID asli kosong -> tetap tes', () {
      expect(
        AdIds.resolveUseTestAds(debug: false, prodIds: const ['', '', '']),
        isTrue,
      );
    });

    test('rilis dengan salah satu ID asli kosong -> tetap tes', () {
      expect(
        AdIds.resolveUseTestAds(debug: false, prodIds: const ['b', ' ', 'r']),
        isTrue,
      );
    });

    test('rilis dengan semua ID asli -> iklan asli', () {
      expect(AdIds.resolveUseTestAds(debug: false, prodIds: full), isFalse);
    });

    test('build debug (termasuk tes) memakai ID tes Google', () {
      expect(AdIds.useTestAds, isTrue);
      for (final id in [AdIds.banner, AdIds.interstitial, AdIds.rewarded]) {
        expect(id, startsWith('ca-app-pub-3940256099942544/'));
      }
    });
  });

  test('default Remote Config sama dengan AdParams.defaults', () {
    const d = FirebaseRemoteSettings.defaults;
    const p = AdParams.defaults;
    expect(d[FirebaseRemoteSettings.adsEnabledKey], p.adsEnabled);
    expect(
      d[FirebaseRemoteSettings.interstitialEveryNStagesKey],
      p.interstitialEveryNStages,
    );
    expect(
      d[FirebaseRemoteSettings.interstitialStartAfterStageKey],
      p.interstitialStartAfterStage,
    );
    expect(
      d[FirebaseRemoteSettings.interstitialMinIntervalSecondsKey],
      p.interstitialMinIntervalSeconds,
    );
    expect(d[FirebaseRemoteSettings.rewardedCoinsKey], p.rewardedCoins);
    expect(d[FirebaseRemoteSettings.rewardedDailyCapKey], p.rewardedDailyCap);
  });
}
