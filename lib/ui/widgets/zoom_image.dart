import 'package:flutter/material.dart';

import '../theme.dart';

/// Gambar soal 1:1 dengan efek zoom ke titik fokus.
class ZoomImage extends StatelessWidget {
  const ZoomImage({
    super.key,
    required this.imagePath,
    required this.scale,
    required this.focusX,
    required this.focusY,
  });

  final String imagePath;
  final double scale;
  final double focusX;
  final double focusY;

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
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: scale),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              alignment: alignment,
              child: child,
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
