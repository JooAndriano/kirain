import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../data/image_url_resolver.dart';
import 'theme.dart';

/// Cache disk gambar soal: disimpan 60 hari, maksimal 500 file.
final CacheManager levelImageCacheManager = CacheManager(
  Config(
    'kirainLevelImages',
    stalePeriod: const Duration(days: 60),
    maxNrOfCacheObjects: 500,
  ),
);

enum LevelImageStatus { loading, loaded, error }

/// Membungkus gambar yang sudah berhasil dimuat (mis. efek zoom).
typedef LevelImageWrapper = Widget Function(Widget image);

/// Satu-satunya widget untuk gambar soal: aset lokal (dummy) atau
/// [CachedNetworkImage] (R2). Hanya gambar yang berhasil dimuat yang
/// dilewatkan ke [wrapImage]; placeholder dan pesan error tidak ikut di-zoom.
class LevelImage extends StatefulWidget {
  const LevelImage({
    super.key,
    required this.source,
    this.wrapImage,
    this.onStatusChanged,
  });

  final LevelImageSource source;
  final LevelImageWrapper? wrapImage;

  /// Dipanggil setelah frame selesai, hanya saat status berubah.
  final ValueChanged<LevelImageStatus>? onStatusChanged;

  @override
  State<LevelImage> createState() => _LevelImageState();
}

/// Status gambar untuk satu percobaan muat.
///
/// CachedNetworkImage (OctoImage) membangun gambar DAN placeholder bersamaan
/// selama animasi fade, dengan placeholder dibangun terakhir. Karena itu
/// "loaded" tidak boleh diturunkan lagi menjadi "loading"; hanya [reset]
/// (Coba lagi / ganti gambar) yang memulai ulang.
class LevelImageStatusTracker {
  LevelImageStatus? _status;
  LevelImageStatus? get status => _status;

  /// true jika status berubah (perlu dilaporkan).
  bool update(LevelImageStatus next) {
    if (_status == next) return false;
    if (_status == LevelImageStatus.loaded &&
        next == LevelImageStatus.loading) {
      return false;
    }
    _status = next;
    return true;
  }

  void reset() => _status = null;
}

class _LevelImageState extends State<LevelImage> {
  int _attempt = 0;
  final _tracker = LevelImageStatusTracker();

  @override
  void didUpdateWidget(LevelImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _attempt = 0;
      _tracker.reset();
    }
  }

  void _report(LevelImageStatus status) {
    if (!_tracker.update(status)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tracker.status == status) {
        widget.onStatusChanged?.call(status);
      }
    });
  }

  Future<void> _retry() async {
    final source = widget.source;
    if (source is RemoteLevelImage) {
      await CachedNetworkImage.evictFromCache(
        source.url,
        cacheManager: levelImageCacheManager,
      );
    }
    if (!mounted) return;
    setState(() {
      _attempt++;
      _tracker.reset();
    });
  }

  Widget _wrap(Widget image) => widget.wrapImage?.call(image) ?? image;

  Widget _loading() {
    _report(LevelImageStatus.loading);
    return const LevelImagePlaceholder();
  }

  Widget _error(Object error) {
    if (_tracker.status != LevelImageStatus.error) {
      // Satu kali per kegagalan: tampilkan URL dan penyebab asli di log.
      debugPrint('LevelImage gagal dimuat: ${widget.source} -> $error');
    }
    _report(LevelImageStatus.error);
    return LevelImageError(onRetry: _retry);
  }

  Widget _loaded(Widget image) {
    _report(LevelImageStatus.loaded);
    return _wrap(image);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.source) {
      LocalLevelImage(:final assetPath) => Image.asset(
        assetPath,
        key: ValueKey('$assetPath#$_attempt'),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        frameBuilder: (context, child, frame, sync) =>
            frame == null && !sync ? _loading() : _loaded(child),
        errorBuilder: (context, error, stack) => _error(error),
      ),
      RemoteLevelImage(:final url) => CachedNetworkImage(
        key: ValueKey('$url#$_attempt'),
        imageUrl: url,
        cacheManager: levelImageCacheManager,
        fadeInDuration: const Duration(milliseconds: 200),
        imageBuilder: (context, provider) => _loaded(
          Image(
            image: provider,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
        placeholder: (context, url) => _loading(),
        errorWidget: (context, url, error) => _error(error),
      ),
    };
  }
}

class LevelImagePlaceholder extends StatelessWidget {
  const LevelImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: KirainColors.boxEmpty,
      child: SizedBox.expand(child: Center(child: CircularProgressIndicator())),
    );
  }
}

/// Pesan ramah saat gambar gagal dimuat, dengan tombol "Coba lagi".
class LevelImageError extends StatelessWidget {
  const LevelImageError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: KirainColors.boxEmpty,
      child: SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: KirainColors.lockedText,
                  ),
                  const SizedBox(height: 8),
                  Text('Gambar belum bisa dimuat', style: text.titleMedium),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba lagi'),
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unduh gambar ke cache lebih awal (mis. level berikutnya). Gagal = diam.
Future<void> precacheLevelImage(BuildContext context, LevelImageSource source) {
  final ImageProvider provider = switch (source) {
    LocalLevelImage(:final assetPath) => AssetImage(assetPath),
    RemoteLevelImage(:final url) => CachedNetworkImageProvider(
      url,
      cacheManager: levelImageCacheManager,
    ),
  };
  return precacheImage(provider, context, onError: (_, _) {});
}
