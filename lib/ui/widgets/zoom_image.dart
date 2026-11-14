import 'package:flutter/material.dart';

import '../../data/image_url_resolver.dart';
import '../level_image.dart';
import '../theme.dart';

/// Gambar soal 1:1 dengan efek zoom ke titik fokus.
class ZoomImage extends StatelessWidget {
  const ZoomImage({
    super.key,
    required this.source,
    required this.scale,
    required this.focusX,
    required this.focusY,
    this.onStatusChanged,
  });

  final LevelImageSource source;
  final double scale;

  /// 0..1 dari kiri/atas gambar.
  final double focusX;
  final double focusY;
  final ValueChanged<LevelImageStatus>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final alignment = Alignment(focusX * 2 - 1, focusY * 2 - 1);
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: kBorderRadius,
          boxShadow: kSoftShadow,
        ),
        child: ClipRRect(
          borderRadius: kBorderRadius,
          child: LevelImage(
            source: source,
            onStatusChanged: onStatusChanged,
            // Hanya gambar yang sudah termuat yang di-zoom.
            wrapImage: (image) => TweenAnimationBuilder<double>(
              tween: Tween(end: scale),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) => Transform.scale(
                scale: value,
                alignment: alignment,
                child: child,
              ),
              child: SizedBox.expand(child: image),
            ),
          ),
        ),
      ),
    );
  }
}
