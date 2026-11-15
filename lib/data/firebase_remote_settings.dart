import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../ads/ad_policy.dart';
import 'remote_settings.dart';

class FirebaseRemoteSettings implements RemoteSettings {
  FirebaseRemoteSettings(this._rc, {bool debug = kDebugMode})
    : _minimumFetchInterval = debug ? Duration.zero : const Duration(hours: 1);

  static const imageBaseUrlKey = 'imageBaseUrl';
  static const adsEnabledKey = 'adsEnabled';
  static const interstitialEveryNStagesKey = 'interstitialEveryNStages';
  static const interstitialStartAfterStageKey = 'interstitialStartAfterStage';
  static const interstitialMinIntervalSecondsKey =
      'interstitialMinIntervalSeconds';
  static const rewardedCoinsKey = 'rewardedCoins';
  static const rewardedDailyCapKey = 'rewardedDailyCap';

  static const _d = AdParams.defaults;
  static const Map<String, Object> defaults = {
    imageBaseUrlKey: kDefaultImageBaseUrl,
    adsEnabledKey: true,
    interstitialEveryNStagesKey: 2,
    interstitialStartAfterStageKey: 2,
    interstitialMinIntervalSecondsKey: 120,
    rewardedCoinsKey: 25,
    rewardedDailyCapKey: 10,
  };

  final FirebaseRemoteConfig _rc;
  final Duration _minimumFetchInterval;

  @override
  String get imageBaseUrl {
    try {
      final v = _rc.getString(imageBaseUrlKey).trim();
      return v.isEmpty ? kDefaultImageBaseUrl : v;
    } catch (_) {
      return kDefaultImageBaseUrl;
    }
  }

  @override
  AdParams get adParams {
    try {
      return AdParams(
        adsEnabled: _rc.getBool(adsEnabledKey),
        interstitialEveryNStages: _int(
          interstitialEveryNStagesKey,
          _d.interstitialEveryNStages,
          min: 1,
        ),
        interstitialStartAfterStage: _int(
          interstitialStartAfterStageKey,
          _d.interstitialStartAfterStage,
          min: 0,
        ),
        interstitialMinIntervalSeconds: _int(
          interstitialMinIntervalSecondsKey,
          _d.interstitialMinIntervalSeconds,
          min: 0,
        ),
        rewardedCoins: _int(rewardedCoinsKey, _d.rewardedCoins, min: 0),
        rewardedDailyCap: _int(
          rewardedDailyCapKey,
          _d.rewardedDailyCap,
          min: 0,
        ),
      );
    } catch (_) {
      return _d;
    }
  }

  /// Nilai negatif/di bawah [min] dari konsol dianggap salah ketik -> default.
  int _int(String key, int fallback, {required int min}) {
    final v = _rc.getInt(key);
    return v < min ? fallback : v;
  }

  @override
  Future<void> init() async {
    try {
      await _rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );
      await _rc.setDefaults(defaults);
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteSettings: fetch gagal, memakai default/terakhir: $e');
    }
  }
}
