import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/game_engine.dart';
import 'game_controller.dart';
import 'theme.dart';
import 'widgets/answer_boxes.dart';
import 'widgets/letter_board.dart';
import 'widgets/zoom_image.dart';

class GamePage extends ConsumerWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    ref.listen(gameControllerProvider.select((s) => s.snapshot.wrongCount), (
      prev,
      next,
    ) {
      if (prev != null && next > prev) HapticFeedback.mediumImpact();
    });
    ref.listen(gameControllerProvider.select((s) => s.snapshot.status), (
      prev,
      next,
    ) {
      if (prev != GameStatus.correct && next == GameStatus.correct) {
        HapticFeedback.lightImpact();
        _showCorrectDialog(context, ref);
      }
    });

    if (state.finished) {
      return _FinishView(
        totalCoins: state.totalCoins,
        onRestart: controller.restart,
      );
    }

    final s = state.snapshot;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              _TopBar(level: state.levelIndex + 1, coins: state.totalCoins),
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
                    onPressed: s.canZoomOut ? controller.zoomOut : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.lightbulb_outline,
                    label: 'Buka Huruf',
                    onPressed: s.canReveal ? controller.revealLetter : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.backspace_outlined,
                    label: 'Hapus Huruf Salah',
                    onPressed: s.canRemoveWrong
                        ? controller.removeWrongLetters
                        : null,
                  ),
                ],
              ),
              Text('Buka huruf / hapus huruf: -10 poin', style: text.bodySmall),
              // Ruang untuk banner iklan (tahap berikutnya).
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  void _showCorrectDialog(BuildContext context, WidgetRef ref) {
    final s = ref.read(gameControllerProvider).snapshot;
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
                Text('+${s.coins} koin', style: text.titleMedium),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ref.read(gameControllerProvider.notifier).nextLevel();
                },
                child: const Text('Lanjut'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.level, required this.coins});

  final int level;
  final int coins;

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
        Container(
          constraints: const BoxConstraints(minHeight: kMinTap),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: KirainColors.surface,
            borderRadius: kBorderRadius,
            boxShadow: kSoftShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: KirainColors.accent,
              ),
              const SizedBox(width: 4),
              Text('$coins', style: text.titleMedium),
            ],
          ),
        ),
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
    required this.onPressed,
  });

  final IconData icon;
  final String label;
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
          ],
        ),
      ),
    );
  }
}

class _FinishView extends StatelessWidget {
  const _FinishView({required this.totalCoins, required this.onRestart});

  final int totalCoins;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 96,
                  color: KirainColors.accent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Semua level selesai!',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Total koin: $totalCoins', style: text.titleLarge),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRestart,
                  child: const Text('Main Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
