import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progress_providers.dart';
import 'game_page.dart';
import 'theme.dart';
import 'widgets/coin_badge.dart';

class LevelSelectPage extends ConsumerWidget {
  const LevelSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(levelsProvider);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Level'),
        backgroundColor: KirainColors.background,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: CoinBadge()),
        ],
      ),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat progress: $e')),
        data: (p) => GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (var i = 0; i < levels.length; i++)
              LevelTile(
                number: i + 1,
                locked: levels[i].id > p.highestUnlockedLevel,
                stars: p.starsPerLevel[levels[i].id],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GamePage(levelIndex: i),
                  ),
                ),
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
