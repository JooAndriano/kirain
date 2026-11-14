import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/levels_controller.dart';
import '../state/progress_providers.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets/coin_badge.dart';

class LevelSelectPage extends ConsumerWidget {
  const LevelSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(levelsControllerProvider);
    final progress = ref.watch(progressProvider);

    Widget grid(List<Widget> children) => GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: children,
    );

    final Widget body;
    if (levels.hasError && !levels.hasValue || progress.hasError) {
      body = _LoadError(
        onReload: () {
          ref.invalidate(progressProvider);
          ref.read(levelsControllerProvider.notifier).refresh();
        },
      );
    } else if (!levels.hasValue || !progress.hasValue) {
      body = grid([for (var i = 0; i < 9; i++) const _SkeletonTile()]);
    } else {
      final p = progress.requireValue;
      body = grid([
        for (final level in levels.requireValue.levels)
          LevelTile(
            number: level.order,
            locked: level.order > p.highestUnlockedLevel,
            stars: p.starsPerLevel[level.order],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GamePage(order: level.order),
              ),
            ),
          ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Level'),
        backgroundColor: KirainColors.background,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: CoinBadge()),
        ],
      ),
      body: body,
    );
  }
}

/// Kerangka tile selama daftar level dimuat.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('level-skeleton'),
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
              'Daftar level belum bisa dimuat',
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

class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.number,
    required this.locked,
    required this.stars,
    required this.onTap,
  });

  final int number;
  final bool locked;

  /// null jika level belum pernah selesai.
  final int? stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
            if (stars != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 0; s < 3; s++)
                    Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: s < stars!
                          ? KirainColors.accent
                          : KirainColors.starOff,
                    ),
                ],
              )
            else
              Text(
                locked ? 'Level $number' : '',
                style: text.bodySmall?.copyWith(color: KirainColors.lockedText),
              ),
          ],
        ),
      ),
    );
  }
}
