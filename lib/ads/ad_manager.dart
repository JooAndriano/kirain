import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/firebase_providers.dart';
import 'ad_policy.dart';
import 'consent.dart';

export 'consent.dart' show PrivacyOptionsStatus;

/// Status muat satu jenis iklan layar penuh.
enum AdLoadState { idle, loading, ready, failed, showing }

/// Hasil menampilkan rewarded.
enum RewardedShowResult {
  /// Pemain menonton sampai selesai; onUserEarnedReward sudah dipanggil.
  earned,

  /// Iklan ditutup sebelum hadiah diberikan.
  dismissed,

  /// Belum ada iklan yang termuat.
  notReady,

  /// Iklan gagal ditampilkan.
  failed,
}

/// Ringkasan status iklan untuk UI (banner) dan halaman debug. Immutable.
@immutable
class AdStatus {
  const AdStatus({
    this.consent = 'belum dicek',
    this.canRequestAds = false,
    this.sdkInitialized = false,
    this.interstitial = AdLoadState.idle,
    this.rewarded = AdLoadState.idle,
    this.lastFullScreenAdAt,
    this.useTestAds = true,
    this.privacyOptions = PrivacyOptionsStatus.unknown,
    this.log = const [],
  });

  /// Status consent UMP (teks bebas untuk debug).
  final String consent;
  final bool canRequestAds;
  final bool sdkInitialized;
  final AdLoadState interstitial;
  final AdLoadState rewarded;
  final DateTime? lastFullScreenAdAt;
  final bool useTestAds;

  /// privacyOptionsRequirementStatus dari UMP.
  final PrivacyOptionsStatus privacyOptions;

  /// Log terbaru (hanya diisi di mode debug).
  final List<String> log;

  /// Banner boleh dimuat: consent mengizinkan dan SDK siap.
  bool get bannersAllowed => canRequestAds && sdkInitialized;

  AdStatus copyWith({
    String? consent,
    bool? canRequestAds,
    bool? sdkInitialized,
    AdLoadState? interstitial,
    AdLoadState? rewarded,
    DateTime? lastFullScreenAdAt,
    bool? useTestAds,
    PrivacyOptionsStatus? privacyOptions,
    List<String>? log,
  }) => AdStatus(
    consent: consent ?? this.consent,
    canRequestAds: canRequestAds ?? this.canRequestAds,
    sdkInitialized: sdkInitialized ?? this.sdkInitialized,
    interstitial: interstitial ?? this.interstitial,
    rewarded: rewarded ?? this.rewarded,
    lastFullScreenAdAt: lastFullScreenAdAt ?? this.lastFullScreenAdAt,
    useTestAds: useTestAds ?? this.useTestAds,
    privacyOptions: privacyOptions ?? this.privacyOptions,
    log: log ?? this.log,
  );
}

/// Satu-satunya pintu iklan bagi app. Widget/notifier tidak memanggil
/// google_mobile_ads langsung (kecuali AdaptiveBannerAd di lib/ads/).
abstract class AdManager {
  ValueListenable<AdStatus> get status;

  /// Consent (UMP) lalu inisialisasi SDK bila diizinkan. Tidak melempar;
  /// aman dipanggil berkali-kali.
  Future<void> init();

  /// Tampilkan interstitial setelah [stage] selesai bila AdPolicy
  /// mengizinkan dan iklan siap. Selesai SETELAH iklan ditutup, atau langsung
  /// jika tidak tampil. Tidak melempar.
  Future<void> maybeShowInterstitialAfterStage(int stage);

  bool get isRewardedReady;

  /// Tampilkan rewarded. [onUserEarnedReward] dipanggil HANYA dari callback
  /// onUserEarnedReward SDK. Selesai setelah iklan ditutup. Tidak melempar.
  Future<RewardedShowResult> showRewarded({
    required VoidCallback onUserEarnedReward,
  });

  /// Buka form "Pengaturan privasi" UMP, lalu muat ulang status consent dan
  /// jalankan lagi logika canRequestAds. Tidak melempar.
  Future<void> showPrivacyOptions();

  /// Debug: hapus status consent agar form muncul lagi saat init berikutnya.
  Future<void> resetConsent();

  void dispose();
}

/// Tanpa iklan sama sekali: default (dan di tes) sampai main.dart
/// meng-override dengan GoogleAdManager.
class DisabledAdManager implements AdManager {
  DisabledAdManager();

  final _status = ValueNotifier(
    const AdStatus(consent: 'iklan nonaktif', useTestAds: true),
  );

  @override
  ValueListenable<AdStatus> get status => _status;

  @override
  Future<void> init() async {}

  @override
  Future<void> maybeShowInterstitialAfterStage(int stage) async {}

  @override
  bool get isRewardedReady => false;

  @override
  Future<RewardedShowResult> showRewarded({
    required VoidCallback onUserEarnedReward,
  }) async => RewardedShowResult.notReady;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<void> resetConsent() async {}

  @override
  void dispose() => _status.dispose();
}

/// Di-override di main.dart dengan GoogleAdManager.
final adManagerProvider = Provider<AdManager>((ref) {
  final manager = DisabledAdManager();
  ref.onDispose(manager.dispose);
  return manager;
});

/// Parameter iklan terkini dari Remote Config.
final adParamsProvider = Provider<AdParams>(
  (ref) => ref.watch(remoteSettingsProvider).adParams,
);

/// privacyOptionsRequirementStatus UMP terkini; ikut berubah saat status
/// AdManager berubah (setelah consent dicek / form privasi ditutup).
final privacyOptionsStatusProvider = Provider<PrivacyOptionsStatus>((ref) {
  final status = ref.watch(adManagerProvider).status;
  void onChange() => ref.invalidateSelf();
  status.addListener(onChange);
  ref.onDispose(() => status.removeListener(onChange));
  return status.value.privacyOptions;
});
