import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_url_resolver.dart';
import '../domain/economy.dart';
import '../domain/game_engine.dart';
import '../domain/progress_rules.dart';
import '../domain/stage.dart';
import '../state/settings_providers.dart';
import '../state/stages_controller.dart';
import 'all_stages_done_page.dart';
import 'game_controller.dart';
import 'level_image.dart';
import 'shop_page.dart';
import 'stage_select_page.dart';
import 'theme.dart';
import 'widgets/answer_boxes.dart';
import 'widgets/coin_badge.dart';
import 'widgets/letter_board.dart';
import 'widgets/stars_row.dart';
import 'widgets/zoom_image.dart';

/// Halaman main untuk gambar ke-[slot] (1..3) pada stage [stage].
class GamePage extends ConsumerWidget {
  const GamePage({super.key, required this.stage, this.slot = 1});

  final int stage;
  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(stagesControllerProvider);
    return switch (stages) {
      AsyncValue(:final value?) when value.puzzleAt(stage, slot) != null =>
        _GameView(puzzleRef: (stage: stage, slot: slot)),
      AsyncValue(hasValue: true) || AsyncError() => const _StageNotFound(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _StageNotFound extends StatelessWidget {
  const _StageNotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: KirainColors.background),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Stage tidak ditemukan'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameView extends ConsumerStatefulWidget {
  const _GameView({required this.puzzleRef});

  final PuzzleRef puzzleRef;

  @override
  ConsumerState<_GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<_GameView> {
  bool _prefetched = false;

  PuzzleRef get puzzleRef => widget.puzzleRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefetched) return;
    _prefetched = true;
    // Unduh gambar berikutnya (slot berikut, atau slot 1 stage berikutnya)
    // selagi pemain menebak gambar ini.
    final stages = ref.read(stagesControllerProvider).value;
    if (stages == null) return;
    final next = puzzleRef.slot < Stage.puzzleCount
        ? stages.puzzleAt(puzzleRef.stage, puzzleRef.slot + 1)
        : stages.puzzleAt(stages.nextAfter(puzzleRef.stage) ?? -1, 1);
    if (next != null) {
      precacheLevelImage(
        context,
        puzzleImageSource(next, ref.read(imageBaseUrlProvider)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = gameControllerProvider(puzzleRef);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider.select((s) => s.snapshot.wrongCount), (prev, next) {
      if (prev != null && next > prev) ref.read(gameFeedbackProvider).wrong();
    });
    ref.listen(provider.select((s) => s.snapshot.status), (prev, next) {
      if (prev != GameStatus.correct && next == GameStatus.correct) {
        ref.read(gameFeedbackProvider).correct();
      }
    });
    // Dialog muncul setelah hasil gambar tersimpan.
    ref.listen(provider.select((s) => s.saved), (prev, next) {
      if (prev != true && next) _showResult(context, ref);
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
              _TopBar(
                stage: state.stage,
                slot: state.slot,
                currentSolved: state.saved,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: ZoomImage(
                    source: puzzleImageSource(
                      state.puzzle,
                      ref.watch(imageBaseUrlProvider),
                    ),
                    scale: s.scale,
                    focusX: state.puzzle.focusX,
                    focusY: state.puzzle.focusY,
                    onStatusChanged: (status) => controller.setImageReady(
                      status == LevelImageStatus.loaded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PointInfo(snapshot: s),
              const SizedBox(height: 12),
              AnswerBoxes(
                key: ValueKey('answer-${state.puzzle.id}'),
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
                    onPressed: state.canZoomOut ? controller.zoomOut : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.lightbulb_outline,
                    label: 'Buka Huruf',
                    cost: Economy.revealLetterCost,
                    onPressed: state.canReveal
                        ? () => useHint(controller.revealLetter)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.backspace_outlined,
                    label: 'Hapus Huruf Salah',
                    cost: Economy.removeWrongCost,
                    onPressed: state.canRemoveWrong
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

  void _replaceWith(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showResult(BuildContext context, WidgetRef ref) {
    final state = ref.read(gameControllerProvider(puzzleRef));
    final result = state.result!;
    final clear = result.stageClear;
    if (clear == null) {
      _showPuzzleDialog(context, state, result);
    } else {
      _showStageDialog(context, state, result, clear);
    }
  }

  /// Hasil satu gambar (bukan gambar terakhir stage).
  void _showPuzzleDialog(
    BuildContext context,
    GameState state,
    PuzzleSolvedResult result,
  ) {
    _showBlockingDialog(
      context,
      title: 'Benar!',
      children: (text) => [
        Text(
          'Gambar ${state.slot}/${Stage.puzzleCount}',
          style: text.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text('${state.snapshot.score} poin', style: text.titleLarge),
        Text(_coinLine(result), style: text.titleMedium),
      ],
      actions: (dialogContext) => [
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _replaceWith(
              context,
              GamePage(stage: state.stage, slot: state.slot + 1),
            );
          },
          child: const Text('Lanjut'),
        ),
      ],
    );
  }

  /// Gambar terakhir benar: stage tuntas.
  void _showStageDialog(
    BuildContext context,
    GameState state,
    PuzzleSolvedResult result,
    StageClearResult clear,
  ) {
    final nextStage = state.nextStage;
    _showBlockingDialog(
      context,
      title: 'Stage ${clear.stage} selesai!',
      children: (text) => [
        StarsRow(stars: clear.stars, size: 48),
        const SizedBox(height: 8),
        Text('Total ${clear.totalScore} poin', style: text.titleLarge),
        Text(_coinLine(result), style: text.titleMedium),
        Text(
          clear.firstClear
              ? '+${clear.bonusCoins} koin bonus stage'
              : 'Stage diulang, tanpa bonus',
          style: text.titleMedium,
        ),
      ],
      actions: (dialogContext) => [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _replaceWith(context, const StageSelectPage());
          },
          child: const Text('Pilih Stage'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _replaceWith(
              context,
              nextStage == null
                  ? const AllStagesDonePage()
                  : GamePage(stage: nextStage),
            );
          },
          child: Text(nextStage == null ? 'Selesai' : 'Stage berikutnya'),
        ),
      ],
    );
  }

  String _coinLine(PuzzleSolvedResult result) => result.firstSolve
      ? '+${result.puzzleCoins} koin'
      : 'Gambar sudah pernah benar, tanpa koin';

  void _showBlockingDialog(
    BuildContext context, {
    required String title,
    required List<Widget> Function(TextTheme text) children,
    required List<Widget> Function(BuildContext dialogContext) actions,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: children(text),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: actions(dialogContext),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.stage,
    required this.slot,
    required this.currentSolved,
  });

  final int stage;
  final int slot;
  final bool currentSolved;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stage $stage · Gambar $slot/${Stage.puzzleCount}',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              StageProgressDots(current: slot, currentSolved: currentSolved),
            ],
          ),
        ),
        const CoinBadge(),
      ],
    );
  }
}

/// Tiga titik progres stage: selesai (penuh), aktif (cincin), belum (pudar).
class StageProgressDots extends StatelessWidget {
  const StageProgressDots({
    super.key,
    required this.current,
    this.currentSolved = false,
  });

  /// Slot yang sedang dimainkan (1..3).
  final int current;
  final bool currentSolved;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var slot = 1; slot <= Stage.puzzleCount; slot++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: StageDot(
              key: ValueKey('stage-dot-$slot'),
              done: slot < current || (slot == current && currentSolved),
              active: slot == current,
            ),
          ),
      ],
    );
  }
}

class StageDot extends StatelessWidget {
  const StageDot({super.key, required this.done, required this.active});

  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? KirainColors.primary : KirainColors.starOff,
        border: active && !done
            ? Border.all(color: KirainColors.primary, width: 2)
            : null,
      ),
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
