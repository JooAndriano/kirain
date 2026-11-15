import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/adaptive_banner_ad.dart';
import '../domain/stage.dart';
import '../state/progress_providers.dart';
import '../state/stages_controller.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets/coin_badge.dart';
import 'widgets/stars_row.dart';

class StageSelectPage extends ConsumerWidget {
  const StageSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(stagesControllerProvider);
    final progress = ref.watch(progressProvider);

    Widget grid(List<Widget> children) => GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: children,
    );

    final Widget body;
    if (stages.hasError && !stages.hasValue || progress.hasError) {
      body = _LoadError(
        onReload: () {
          ref.invalidate(progressProvider);
          ref.read(stagesControllerProvider.notifier).refresh();
        },
      );
    } else if (!stages.hasValue || !progress.hasValue) {
      body = grid([for (var i = 0; i < 9; i++) const _SkeletonTile()]);
    } else {
      final p = progress.requireValue;
      final run = p.inProgress;
      body = grid([
        for (final stage in stages.requireValue.stages)
          StageTile(
            number: stage.number,
            locked: stage.number > p.highestUnlockedStage,
            stars: p.stageStars[stage.number],
            solvedInRun: run != null && run.stage == stage.number
                ? run.solved.length
                : 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GamePage(
                  stage: stage.number,
                  slot: resumeSlot(p, stage.number),
                ),
              ),
            ),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Stage'),
        backgroundColor: KirainColors.background,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: CoinBadge()),
        ],
      ),
      body: body,
      bottomNavigationBar: const AdaptiveBannerAd(),
    );
  }
}

/// Kerangka tile selama daftar stage dimuat.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('stage-skeleton'),
      decoration: BoxDecoration(
        color: KirainColors.skeleton,
        borderRadius: kBorderRadius,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: KirainColors.lockedText,
            ),
            const SizedBox(height: 8),
            Text(
              'Daftar stage belum bisa dimuat',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang'),
              onPressed: onReload,
            ),
          ],
        ),
      ),
    );
  }
}

class StageTile extends StatelessWidget {
  const StageTile({
    super.key,
    required this.number,
    required this.locked,
    required this.stars,
    required this.onTap,
    this.solvedInRun = 0,
  });

  final int number;
  final bool locked;

  /// Bintang terbaik, null jika stage belum pernah tuntas.
  final int? stars;

  /// Jumlah gambar yang sudah benar pada stage yang sedang dimainkan.
  final int solvedInRun;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: KirainColors.lockedText);
    return Material(
      color: locked ? KirainColors.lockedTile : KirainColors.surface,
      borderRadius: kBorderRadius,
      elevation: locked ? 0 : 2,
      shadowColor: KirainColors.shadow,
      child: InkWell(
        borderRadius: kBorderRadius,
        onTap: locked ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (locked)
              const Icon(
                Icons.lock_rounded,
                size: 32,
                color: KirainColors.lockedText,
                semanticLabel: 'Terkunci',
              )
            else
              Text(
                '$number',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KirainColors.text,
                ),
              ),
            const SizedBox(height: 4),
            if (locked)
              Text('Stage $number', style: small)
            else if (solvedInRun > 0)
              Text('Lanjut $solvedInRun/${Stage.puzzleCount}', style: small)
            else if (stars != null)
              StarsRow(stars: stars!)
            else
              Text('', style: small),
          ],
        ),
      ),
    );
  }
}
