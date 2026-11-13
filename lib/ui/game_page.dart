import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/economy.dart';
import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'level_select_page.dart';
import 'shop_page.dart';
import 'theme.dart';
import 'widgets/answer_boxes.dart';
import 'widgets/coin_badge.dart';
import 'widgets/letter_board.dart';
import 'widgets/zoom_image.dart';

class GamePage extends ConsumerWidget {
  const GamePage({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = gameControllerProvider(levelIndex);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider.select((s) => s.snapshot.wrongCount), (prev, next) {
      if (prev != null && next > prev) HapticFeedback.mediumImpact();
    });
    ref.listen(provider.select((s) => s.snapshot.status), (prev, next) {
      if (prev != GameStatus.correct && next == GameStatus.correct) {
        HapticFeedback.lightImpact();
      }
    });
    // Dialog muncul setelah hasil level tersimpan.
    ref.listen(provider.select((s) => s.saved), (prev, next) {
      if (prev != true && next) _showCorrectDialog(context, ref);
    });

    final s = state.snapshot;
    final text = Theme.of(context).textTheme;

    Future<void> useHint(Future<HintResult> Function() hint) async {
      final result = await hint();
      if (result == HintResult.notEnoughCoins && context.mounted) {
        _showNotEnoughCoins(context);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _TopBar(level: state.levelIndex + 1),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: ZoomImage(
                    imagePath: state.level.imagePath,
                    scale: s.scale,
                    focusX: state.level.focusX,
                    focusY: state.level.focusY,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PointInfo(snapshot: s),
              const SizedBox(height: 12),
              AnswerBoxes(
                key: ValueKey('answer-${state.levelIndex}'),
                slots: s.slots,
                onTap: controller.tapSlot,
                shakeTrigger: s.wrongCount,
              ),
              const SizedBox(height: 12),
              LetterBoard(tiles: s.tiles, onTap: controller.tapTile),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.zoom_out_map,
                    label: 'Zoom Out',
                    cost: null,
                    onPressed: s.canZoomOut ? controller.zoomOut : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.lightbulb_outline,
                    label: 'Buka Huruf',
                    cost: Economy.revealLetterCost,
                    onPressed: s.canReveal
                        ? () => useHint(controller.revealLetter)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.backspace_outlined,
                    label: 'Hapus Huruf Salah',
                    cost: Economy.removeWrongCost,
                    onPressed: s.canRemoveWrong
                        ? () => useHint(controller.removeWrongLetters)
                        : null,
                  ),
                ],
              ),
              Text('Zoom Out gratis · hint: -10 poin', style: text.bodySmall),
              // Ruang untuk banner iklan (tahap berikutnya).
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotEnoughCoins(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Koin tidak cukup'),
        content: const Text('Dapatkan koin tambahan di Toko.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const ShopPage()));
            },
            child: const Text('Ke Toko'),
          ),
        ],
      ),
    );
  }

  void _goNext(BuildContext context, bool isLastLevel) {
    final navigator = Navigator.of(context);
    if (isLastLevel) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LevelSelectPage()),
        (route) => route.isFirst,
      );
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GamePage(levelIndex: levelIndex + 1),
        ),
      );
    }
  }

  void _showCorrectDialog(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameControllerProvider(levelIndex));
    final s = state.snapshot;
    final firstClear = state.firstClear ?? false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              'Benar!',
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: i < s.stars
                            ? KirainColors.accent
                            : KirainColors.starOff,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${s.score} poin', style: text.titleLarge),
                Text(
                  firstClear ? '+${s.coins} koin' : 'Level diulang, tanpa koin',
                  style: text.titleMedium,
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _goNext(context, state.isLastLevel);
                },
                child: Text(state.isLastLevel ? 'Pilih Level' : 'Lanjut'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            'Level $level',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const CoinBadge(),
      ],
    );
  }
}

class _PointInfo extends StatelessWidget {
  const _PointInfo({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final after = snapshot.scoreAfterZoomOut;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Poin: ${snapshot.score}',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        Text(
          after == null
              ? 'Zoom maksimal'
              : 'Zoom out: ${snapshot.score} → $after',
          style: text.bodyMedium,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// Harga koin, null jika gratis.
  final int? cost;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cost != null) ...[
                  const Icon(
                    Icons.monetization_on_rounded,
                    size: 14,
                    color: KirainColors.accent,
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  cost == null ? 'Gratis' : '$cost',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
