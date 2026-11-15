import 'package:flutter/foundation.dart';

/// ID iklan AdMob (Android).
///
/// Selama pengembangan SELALU memakai ID tes Google. ID asli diisi hanya saat
/// siap rilis, bersama App ID di AndroidManifest.xml. Selama salah satu ID
/// asli masih kosong, build rilis pun tetap memakai iklan tes, sehingga iklan
/// asli tidak pernah dimuat secara tidak sengaja.
abstract final class AdIds {
  // ID tes resmi Google: https://developers.google.com/admob/android/test-ads
  static const testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // ID asli: biarkan kosong sampai siap rilis.
  static const prodBanner = '';
  static const prodInterstitial = '';
  static const prodRewarded = '';

  static bool get useTestAds => resolveUseTestAds(
    debug: kDebugMode,
    prodIds: const [prodBanner, prodInterstitial, prodRewarded],
  );

  /// Iklan tes dipakai bila debug ATAU ada ID asli yang masih kosong.
  @visibleForTesting
  static bool resolveUseTestAds({
    required bool debug,
    required List<String> prodIds,
  }) => debug || prodIds.any((id) => id.trim().isEmpty);

  static String get banner => useTestAds ? testBanner : prodBanner;
  static String get interstitial =>
      useTestAds ? testInterstitial : prodInterstitial;
  static String get rewarded => useTestAds ? testRewarded : prodRewarded;

  /// Uji form consent EEA di perangkat nyata:
  /// `flutter run --dart-define=ADS_DEBUG_EEA=true
  ///  --dart-define=ADS_TEST_DEVICE_ID=HASH_DARI_LOGCAT`.
  /// Hanya berlaku di build debug.
  static const debugGeographyEea = bool.fromEnvironment('ADS_DEBUG_EEA');
  static const testDeviceId = String.fromEnvironment('ADS_TEST_DEVICE_ID');
}
