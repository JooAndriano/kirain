import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_manager.dart';
import 'ad_policy.dart';
import 'ads_config.dart';
import 'consent.dart';
import 'ump_consent_gateway.dart';

/// AdManager dengan Google Mobile Ads + UMP (consent).
///
/// Urutan init: requestConsentInfoUpdate -> loadAndShowConsentFormIfRequired
/// -> MobileAds.initialize() hanya jika canRequestAds(). Semua kegagalan
/// ditelan: app tetap berjalan tanpa iklan.
class GoogleAdManager implements AdManager {
  GoogleAdManager({
    required this._params,
    this._clock = DateTime.now,
    ConsentGateway consent = const UmpConsentGateway(),
    Duration consentInfoTimeout = const Duration(seconds: 5),
    this.sdkInitTimeout = const Duration(seconds: 5),
  }) {
    _consent = ConsentFlow(
      consent,
      log: _log,
      infoUpdateTimeout: consentInfoTimeout,
    );
  }

  final AdParams Function() _params;
  final DateTime Function() _clock;
  late final ConsentFlow _consent;
  final Duration sdkInitTimeout;

  final _status = ValueNotifier(AdStatus(useTestAds: AdIds.useTestAds));

  Future<void>? _initFuture;
  bool _disposed = false;
  bool _showingFullScreen = false;

  InterstitialAd? _interstitial;
  bool _interstitialLoading = false;
  int _interstitialFailures = 0;
  Timer? _interstitialRetry;

  RewardedAd? _rewarded;
  bool _rewardedLoading = false;
  int _rewardedFailures = 0;
  Timer? _rewardedRetry;

  @override
  ValueListenable<AdStatus> get status => _status;

  bool get _ready =>
      !_disposed &&
      _status.value.sdkInitialized &&
      _status.value.canRequestAds &&
      _params().adsEnabled;

  void _set(AdStatus Function(AdStatus s) update) {
    if (_disposed) return;
    _status.value = update(_status.value);
  }

  void _log(String message) {
    if (!kDebugMode || _disposed) return;
    debugPrint('[Ads] $message');
    final time = _clock().toIso8601String().substring(11, 19);
    final log = ['$time $message', ..._status.value.log];
    _set((s) => s.copyWith(log: log.take(40).toList()));
  }

  // ------------------------------------------------------------- consent

  @override
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    _log('mode ${AdIds.useTestAds ? 'iklan TES' : 'iklan ASLI'}');
    if (!_params().adsEnabled) {
      _log('adsEnabled=false (Remote Config): iklan dilewati');
      _set((s) => s.copyWith(consent: 'dilewati (adsEnabled=false)'));
      return;
    }
    // Consent dari sesi sebelumnya: SDK boleh langsung disiapkan paralel.
    if (await _consent.cachedCanRequestAds()) {
      _set((s) => s.copyWith(canRequestAds: true));
      unawaited(_initSdk());
    }
    final debugEea = kDebugMode && AdIds.debugGeographyEea;
    if (debugEea) _log('consent debug geography: EEA');
    await _applyConsent(
      await _consent.gather(
        debugGeographyEea: debugEea,
        testDeviceIds: [if (AdIds.testDeviceId.isNotEmpty) AdIds.testDeviceId],
      ),
    );
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (_disposed) return;
    await _applyConsent(await _consent.showPrivacyOptions());
  }

  /// Simpan status consent lalu jalankan logika canRequestAds: siapkan SDK
  /// jika diizinkan; jika tidak, iklan berhenti (banner disembunyikan,
  /// layar penuh tidak tampil) dan app tetap normal.
  Future<void> _applyConsent(ConsentState consent) async {
    _set(
      (s) => s.copyWith(
        consent: consent.consent,
        canRequestAds: consent.canRequestAds,
        privacyOptions: consent.privacyOptions,
      ),
    );
    if (consent.canRequestAds) {
      if (!_params().adsEnabled) return;
      await _initSdk();
      // SDK mungkin sudah siap sebelumnya (mis. consent baru diizinkan lagi
      // lewat Pengaturan privasi): pastikan iklan dimuat.
      _loadInterstitial();
      _loadRewarded();
    } else {
      _log('canRequestAds=false: app berjalan tanpa iklan');
    }
  }

  Future<void>? _sdkFuture;

  Future<void> _initSdk() => _sdkFuture ??= _doInitSdk();

  Future<void> _doInitSdk() async {
    try {
      if (kDebugMode && AdIds.testDeviceId.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: [AdIds.testDeviceId]),
        );
      }
      await MobileAds.instance.initialize().timeout(sdkInitTimeout);
      _set((s) => s.copyWith(sdkInitialized: true));
      _log('MobileAds siap');
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      _sdkFuture = null; // boleh dicoba lagi pada init berikutnya
      _log('MobileAds.initialize gagal: $e');
    }
  }

  // -------------------------------------------------------- interstitial

  void _loadInterstitial() {
    if (!_ready || _interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    _interstitialRetry?.cancel();
    _set((s) => s.copyWith(interstitial: AdLoadState.loading));
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _interstitialFailures = 0;
          _interstitial = ad;
          _set((s) => s.copyWith(interstitial: AdLoadState.ready));
          _log('interstitial termuat');
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          _interstitialFailures++;
          final delay = AdPolicy.retryDelay(_interstitialFailures);
          _set((s) => s.copyWith(interstitial: AdLoadState.failed));
          _log(
            'interstitial gagal (${error.code} ${error.message}); '
            'coba lagi ${delay.inSeconds} dtk',
          );
          if (_disposed) return;
          _interstitialRetry = Timer(delay, _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<void> maybeShowInterstitialAfterStage(int stage) async {
    if (!_ready || _showingFullScreen) return;
    final allowed = AdPolicy.shouldShowInterstitial(
      stageNumber: stage,
      now: _clock(),
      lastAdShownAt: _status.value.lastFullScreenAdAt,
      params: _params(),
    );
    if (!allowed) {
      _log('interstitial stage $stage: tidak sesuai AdPolicy');
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _log('interstitial stage $stage: belum termuat');
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    await _showFullScreen(
      ad: ad,
      kind: 'interstitial',
      setState: (state) => _set((s) => s.copyWith(interstitial: state)),
      show: ad.show,
      setCallback: (cb) => ad.fullScreenContentCallback = cb,
    );
    _loadInterstitial();
  }

  // ------------------------------------------------------------ rewarded

  void _loadRewarded() {
    if (!_ready || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    _rewardedRetry?.cancel();
    _set((s) => s.copyWith(rewarded: AdLoadState.loading));
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _rewardedFailures = 0;
          _rewarded = ad;
          _set((s) => s.copyWith(rewarded: AdLoadState.ready));
          _log('rewarded termuat');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          _rewardedFailures++;
          final delay = AdPolicy.retryDelay(_rewardedFailures);
          _set((s) => s.copyWith(rewarded: AdLoadState.failed));
          _log(
            'rewarded gagal (${error.code} ${error.message}); '
            'coba lagi ${delay.inSeconds} dtk',
          );
          if (_disposed) return;
          _rewardedRetry = Timer(delay, _loadRewarded);
        },
      ),
    );
  }

  @override
  bool get isRewardedReady =>
      _ready && _rewarded != null && !_showingFullScreen;

  @override
  Future<RewardedShowResult> showRewarded({
    required VoidCallback onUserEarnedReward,
  }) async {
    final ad = _rewarded;
    if (!_ready || ad == null || _showingFullScreen) {
      _loadRewarded();
      return RewardedShowResult.notReady;
    }
    _rewarded = null;
    var earned = false;
    final shown = await _showFullScreen(
      ad: ad,
      kind: 'rewarded',
      setState: (state) => _set((s) => s.copyWith(rewarded: state)),
      show: () => ad.show(
        onUserEarnedReward: (_, reward) {
          if (earned) return;
          earned = true;
          _log('rewarded: hadiah diterima');
          onUserEarnedReward();
        },
      ),
      setCallback: (cb) => ad.fullScreenContentCallback = cb,
    );
    _loadRewarded();
    if (earned) return RewardedShowResult.earned;
    return shown ? RewardedShowResult.dismissed : RewardedShowResult.failed;
  }

  // -------------------------------------------------------------- shared

  /// Tampilkan iklan layar penuh dan tunggu sampai ditutup. Iklan selalu
  /// di-dispose. Mengembalikan false bila gagal ditampilkan.
  Future<bool> _showFullScreen<T extends Ad>({
    required T ad,
    required String kind,
    required void Function(AdLoadState) setState,
    required Future<void> Function() show,
    required void Function(FullScreenContentCallback<T>) setCallback,
  }) async {
    final closed = Completer<bool>();
    void finish(T ad, bool shown) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete(shown);
    }

    setCallback(
      FullScreenContentCallback<T>(
        onAdShowedFullScreenContent: (_) {
          // Dicatat untuk jarak minimum AdPolicy (interstitial ATAU rewarded).
          _set((s) => s.copyWith(lastFullScreenAdAt: _clock()));
          _log('$kind tampil');
        },
        onAdDismissedFullScreenContent: (ad) {
          _log('$kind ditutup');
          finish(ad, true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _log('$kind gagal tampil: ${error.message}');
          finish(ad, false);
        },
      ),
    );
    _showingFullScreen = true;
    setState(AdLoadState.showing);
    try {
      await show();
    } catch (e) {
      _log('$kind show() error: $e');
      finish(ad, false);
    }
    final shown = await closed.future;
    _showingFullScreen = false;
    setState(AdLoadState.idle);
    return shown;
  }

  @override
  Future<void> resetConsent() async {
    await _consent.reset();
    _log('consent di-reset; buka ulang app untuk melihat form');
    _set(
      (s) => s.copyWith(
        consent: 'di-reset',
        canRequestAds: false,
        privacyOptions: PrivacyOptionsStatus.unknown,
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
    _status.dispose();
  }
}
