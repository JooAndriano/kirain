import 'package:flutter/material.dart';

import '../../domain/game_engine.dart';
import '../theme.dart';

/// Papan huruf 2 baris x 7 kolom.
class LetterBoard extends StatelessWidget {
  const LetterBoard({super.key, required this.tiles, required this.onTap});

  static const columns = 7;

  final List<TileView> tiles;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = (tiles.length / columns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: r * columns + c < tiles.length
                      ? _Tile(tile: tiles[r * columns + c], onTap: onTap)
                      : const SizedBox(height: kMinTap),
                ),
            ],
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.onTap});

  final TileView tile;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final visible = tile.available;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: visible ? () => onTap(tile.id) : null,
      child: SizedBox(
        height: kMinTap + 4,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visible ? KirainColors.accent : KirainColors.tileUsed,
              borderRadius: BorderRadius.circular(kRadius / 2),
              boxShadow: visible ? kSoftShadow : null,
            ),
            child: visible
                ? Text(
                    tile.letter,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KirainColors.text,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
