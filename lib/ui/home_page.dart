import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progress_providers.dart';
import 'game_page.dart';
import 'level_select_page.dart';
import 'shop_page.dart';
import 'splash_page.dart';
import 'widgets/coin_badge.dart';
import 'widgets/daily_bonus_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    ref.read(progressProvider.future).then((_) {
      if (!mounted) return;
      final offer = ref.read(dailyBonusOfferProvider);
      if (offer != null) showDailyBonusDialog(context, ref, offer);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final levels = ref.watch(levelsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: progress.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat progress: $e')),
          data: (p) {
            final idx = levels.indexWhere(
              (l) => l.id == p.highestUnlockedLevel,
            );
            final continueIndex = idx < 0 ? levels.length - 1 : idx;
            final label = p.starsPerLevel.isEmpty ? 'Main' : 'Lanjutkan';

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.topRight,
                    child: CoinBadge(),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(kLogoAsset, height: 140),
                  ),
                  const SizedBox(height: 16),
                  Hero(
                    tag: kWordmarkHeroTag,
                    child: Image.asset(kWordmarkAsset, height: 96),
                  ),
                  Text(
                    'Tebak gambarnya!',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('$label (Level ${continueIndex + 1})'),
                    onPressed: () => _push(GamePage(levelIndex: continueIndex)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Pilih Level'),
                    onPressed: () => _push(const LevelSelectPage()),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.storefront_rounded),
                    label: const Text('Toko'),
                    onPressed: () => _push(const ShopPage()),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
