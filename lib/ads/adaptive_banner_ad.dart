import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_manager.dart';
import 'ads_config.dart';

/// Banner adaptif selebar layar di ruang tetap [slotHeight] (bawah halaman).
///
/// Ruang selalu dicadangkan (selama iklan aktif di Remote Config) agar
/// layout tidak melompat saat banner muncul; jika gagal dimuat, ruang
/// dibiarkan kosong. Sudah memakai SafeArea; pasang di
/// Scaffold.bottomNavigationBar.
class AdaptiveBannerAd extends ConsumerStatefulWidget {
  const AdaptiveBannerAd({super.key});

  static const double slotHeight = 60;

  /// Jarak aman dari tombol di atasnya.
  static const double topGap = 8;

  @override
  ConsumerState<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends ConsumerState<AdaptiveBannerAd> {
  BannerAd? _ad;

  /// Ukuran nyata setelah termuat (inline adaptive baru tahu tingginya
  /// setelah load). null = belum siap tampil.
  AdSize? _size;
  bool _failed = false;
  int? _requestedWidth;

  Future<void> _load(int width) async {
    _requestedWidth = width;
    final maxHeight = AdaptiveBannerAd.slotHeight.toInt();
    AdSize size;
    try {
      final anchored = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      // Anchored adaptive bisa lebih tinggi dari slot di layar besar:
      // pakai inline adaptive dengan batas tinggi slot.
      size = anchored != null && anchored.height <= maxHeight
          ? anchored
          : AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight);
    } catch (_) {
      size = AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight);
    }
    if (!mounted || _requestedWidth != width) return;

    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => _onLoaded(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('[Ads] banner gagal: ${error.code} ${error.message}');
          if (!mounted || _ad != ad) return;
          setState(() {
            _ad = null;
            _size = null;
            _failed = true; // sembunyikan; ruang tetap dicadangkan
          });
        },
      ),
    );
    _ad?.dispose();
    setState(() {
      _ad = ad;
      _size = null;
      _failed = false;
    });
    await ad.load();
  }

  Future<void> _onLoaded(BannerAd ad) async {
    if (!mounted || _ad != ad) {
      ad.dispose();
      return;
    }
    AdSize? size;
    try {
      size = await ad.getPlatformAdSize();
    } catch (_) {}
    if (!mounted || _ad != ad) return;
    setState(() => _size = size ?? ad.size);
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _maybeLoad(AdStatus status, int width) {
    if (!status.bannersAllowed || _failed || width <= 0) return;
    if (_requestedWidth == width) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _requestedWidth != width) _load(width);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adParamsProvider).adsEnabled) {
      return const SizedBox.shrink();
    }
    final manager = ref.watch(adManagerProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: AdaptiveBannerAd.topGap),
        child: SizedBox(
          key: const ValueKey('banner-slot'),
          height: AdaptiveBannerAd.slotHeight,
          width: double.infinity,
          child: ValueListenableBuilder<AdStatus>(
            valueListenable: manager.status,
            builder: (context, status, _) => LayoutBuilder(
              builder: (context, constraints) {
                _maybeLoad(status, constraints.maxWidth.truncate());
                final ad = _ad;
                final size = _size;
                if (!status.bannersAllowed || ad == null || size == null) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: SizedBox(
                    width: size.width.toDouble(),
                    height: size.height.toDouble().clamp(
                      0,
                      AdaptiveBannerAd.slotHeight,
                    ),
                    child: AdWidget(ad: ad),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
