import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/economy.dart';
import '../state/progress_providers.dart';
import 'theme.dart';
import 'widgets/coin_badge.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  bool _watching = false;

  Future<void> _watchAd() async {
    final notifier = ref.read(progressProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _watching = true);
    // TODO: ganti dengan rewarded ad di tahap 4. Sementara simulasi delay.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await notifier.addCoins(Economy.adReward);
    messenger.showSnackBar(
      const SnackBar(content: Text('+${Economy.adReward} koin!')),
    );
    if (mounted) setState(() => _watching = false);
  }

  Future<void> _claimDaily() async {
    final messenger = ScaffoldMessenger.of(context);
    final amount = await ref.read(progressProvider.notifier).claimDailyBonus();
    if (amount > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('Bonus harian +$amount koin!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(dailyBonusOfferProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toko'),
        backgroundColor: KirainColors.background,
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: CoinBadge()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offer != null) ...[
            _ShopCard(
              icon: Icons.card_giftcard_rounded,
              title: 'Bonus Harian (hari ke-${offer.newStreak})',
              subtitle: '+${offer.amount} koin',
              action: FilledButton(
                onPressed: _claimDaily,
                child: const Text('Klaim'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _ShopCard(
            icon: Icons.ondemand_video_rounded,
            title: 'Tonton Iklan',
            subtitle: 'Dapatkan +${Economy.adReward} koin',
            action: FilledButton(
              onPressed: _watching ? null : _watchAd,
              child: _watching
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tonton Iklan (+${Economy.adReward} koin)'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Harga hint', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Buka huruf: ${Economy.revealLetterCost} koin'),
          Text('Hapus huruf salah: ${Economy.removeWrongCost} koin'),
          const Text('Zoom Out: gratis (mengurangi poin)'),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KirainColors.surface,
        borderRadius: kBorderRadius,
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 40, color: KirainColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(subtitle, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}
