import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/ads/ad_policy.dart';

void main() {
  final now = DateTime(2026, 11, 15, 10);
  const p = AdParams.defaults;

  group('AdParams.defaults', () {
    test('nilai bawaan aman', () {
      expect(p.adsEnabled, isTrue);
      expect(p.interstitialEveryNStages, 2);
      expect(p.interstitialStartAfterStage, 2);
      expect(p.interstitialMinIntervalSeconds, 120);
      expect(p.rewardedCoins, 25);
      expect(p.rewardedDailyCap, 10);
    });
  });

  group('shouldShowInterstitial', () {
    bool show(int stage, {DateTime? last, AdParams params = p, DateTime? at}) =>
        AdPolicy.shouldShowInterstitial(
          stageNumber: stage,
          now: at ?? now,
          lastAdShownAt: last,
          params: params,
        );

    test('adsEnabled false -> tidak pernah', () {
      const off = AdParams(adsEnabled: false);
      for (var s = 1; s <= 10; s++) {
        expect(show(s, params: off), isFalse);
      }
    });

    test('sebelum interstitialStartAfterStage -> tidak', () {
      expect(show(1), isFalse);
      expect(show(2), isTrue); // tepat di batas
      expect(show(4), isTrue);
    });

    test('bawaan: hanya setiap 2 stage (2, 4, 6, ...)', () {
      expect(
        [for (var s = 1; s <= 8; s++) show(s)],
        [false, true, false, true, false, true, false, true],
      );
    });

    test('startAfterStage 0 atau 1: mulai stage 1', () {
      expect(
        show(
          1,
          params: const AdParams(
            interstitialEveryNStages: 1,
            interstitialStartAfterStage: 0,
          ),
        ),
        isTrue,
      );
      expect(
        show(
          1,
          params: const AdParams(
            interstitialEveryNStages: 1,
            interstitialStartAfterStage: 1,
          ),
        ),
        isTrue,
      );
    });

    test('stage tidak valid (0 / negatif) -> tidak', () {
      const fromZero = AdParams(
        interstitialEveryNStages: 1,
        interstitialStartAfterStage: 0,
      );
      expect(show(0, params: fromZero), isFalse);
      expect(show(-3, params: fromZero), isFalse);
    });

    test('hanya kelipatan interstitialEveryNStages', () {
      const every3 = AdParams(
        interstitialEveryNStages: 3,
        interstitialStartAfterStage: 1,
      );
      expect(
        [for (var s = 1; s <= 9; s++) show(s, params: every3)],
        [
          false, false, true, false, false, true, false, false, true, //
        ],
      );
    });

    test('kelipatan N dan startAfter digabung (N=2, mulai 3)', () {
      const params = AdParams(
        interstitialEveryNStages: 2,
        interstitialStartAfterStage: 3,
      );
      expect(show(2, params: params), isFalse); // kelipatan tapi terlalu awal
      expect(show(3, params: params), isFalse); // bukan kelipatan
      expect(show(4, params: params), isTrue);
    });

    test('everyN 0 atau negatif dianggap 1 (tidak crash bagi 0)', () {
      expect(
        show(6, params: const AdParams(interstitialEveryNStages: 0)),
        isTrue,
      );
      expect(
        show(6, params: const AdParams(interstitialEveryNStages: -2)),
        isTrue,
      );
    });

    test('belum pernah ada iklan layar penuh -> boleh', () {
      expect(show(6, last: null), isTrue);
    });

    test('jarak minimum: kurang 1 detik tidak, tepat batas boleh', () {
      expect(
        show(6, last: now.subtract(const Duration(seconds: 119))),
        isFalse,
      );
      expect(show(6, last: now.subtract(const Duration(seconds: 120))), isTrue);
      expect(show(6, last: now.subtract(const Duration(hours: 1))), isTrue);
    });

    test('iklan baru saja tampil (jarak 0) -> tidak', () {
      expect(show(6, last: now), isFalse);
    });

    test('minInterval 0 atau negatif -> tidak ada batas jarak', () {
      expect(
        show(
          6,
          last: now,
          params: const AdParams(interstitialMinIntervalSeconds: 0),
        ),
        isTrue,
      );
      expect(
        show(
          6,
          last: now,
          params: const AdParams(interstitialMinIntervalSeconds: -10),
        ),
        isTrue,
      );
    });

    test('jam mundur (iklan terakhir di masa depan) tidak mengunci iklan', () {
      expect(show(6, last: now.add(const Duration(days: 1))), isTrue);
    });
  });

  group('canShowRewarded', () {
    bool can(int count, [AdParams params = p]) =>
        AdPolicy.canShowRewarded(rewardedCountToday: count, params: params);

    test('di bawah batas -> boleh', () {
      expect(can(0), isTrue);
      expect(can(9), isTrue);
    });

    test('tepat / melewati batas -> tidak', () {
      expect(can(10), isFalse);
      expect(can(11), isFalse);
    });

    test('dailyCap 0 atau negatif -> rewarded mati', () {
      expect(can(0, const AdParams(rewardedDailyCap: 0)), isFalse);
      expect(can(0, const AdParams(rewardedDailyCap: -1)), isFalse);
    });

    test('adsEnabled false -> tidak', () {
      expect(can(0, const AdParams(adsEnabled: false)), isFalse);
    });

    test('dailyCap 1: satu kali saja', () {
      const once = AdParams(rewardedDailyCap: 1);
      expect(can(0, once), isTrue);
      expect(can(1, once), isFalse);
    });
  });

  group('rewardedCountToday (reset harian, tanggal lokal)', () {
    int count(String? date, int stored, DateTime at) =>
        AdPolicy.rewardedCountToday(
          storedDate: date,
          storedCount: stored,
          now: at,
        );

    test('hari yang sama -> jumlah tersimpan', () {
      expect(count('2026-11-15', 4, now), 4);
    });

    test('ganti hari -> 0', () {
      expect(count('2026-11-14', 10, now), 0);
    });

    test('tepat lewat tengah malam lokal -> reset', () {
      expect(count('2026-11-15', 7, DateTime(2026, 11, 15, 23, 59, 59)), 7);
      expect(count('2026-11-15', 7, DateTime(2026, 11, 16)), 0);
    });

    test('ganti bulan dan tahun', () {
      expect(count('2026-11-30', 3, DateTime(2026, 12, 1)), 0);
      expect(count('2026-12-31', 3, DateTime(2027, 1, 1)), 0);
    });

    test('jam mundur ke hari kemarin -> 0 (tanggal beda)', () {
      expect(count('2026-11-15', 5, DateTime(2026, 11, 14, 23)), 0);
    });

    test('belum pernah / tanggal rusak -> 0', () {
      expect(count(null, 5, now), 0);
      expect(count('kemarin', 5, now), 0);
      expect(count('', 5, now), 0);
    });

    test('jumlah negatif (data rusak) -> 0', () {
      expect(count('2026-11-15', -3, now), 0);
    });

    test('memakai tanggal lokal, bukan UTC', () {
      final local = DateTime(2026, 11, 16, 0, 30);
      expect(count('2026-11-16', 2, local), 2);
    });
  });

  group('retryDelay (backoff)', () {
    test('naik dua kali lipat lalu dibatasi 5 menit', () {
      expect(AdPolicy.retryDelay(1), const Duration(seconds: 5));
      expect(AdPolicy.retryDelay(2), const Duration(seconds: 10));
      expect(AdPolicy.retryDelay(3), const Duration(seconds: 20));
      expect(AdPolicy.retryDelay(6), const Duration(seconds: 160));
      expect(AdPolicy.retryDelay(7), const Duration(minutes: 5));
      expect(AdPolicy.retryDelay(1000), const Duration(minutes: 5));
    });

    test('attempt 0 / negatif -> tanpa jeda', () {
      expect(AdPolicy.retryDelay(0), Duration.zero);
      expect(AdPolicy.retryDelay(-1), Duration.zero);
    });
  });
}
