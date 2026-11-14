import 'package:flutter/material.dart';

import '../theme.dart';

/// Tiga bintang; [stars] pertama menyala.
class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.stars, this.size = 18});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            Icons.star_rounded,
            size: size,
            color: i < stars ? KirainColors.accent : KirainColors.starOff,
          ),
      ],
    );
  }
}
