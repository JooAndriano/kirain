import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/progress_providers.dart';
import '../shop_page.dart';
import '../theme.dart';

/// Jumlah koin pemain, dibaca dari progressProvider. Diketuk membuka Toko
/// kecuali [opensShop] false (mis. di halaman Toko sendiri).
class CoinBadge extends ConsumerWidget {
  const CoinBadge({super.key, this.opensShop = true});

  final bool opensShop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(progressProvider).value?.coins;
    final text = Theme.of(context).textTheme;
    final content = Container(
      constraints: const BoxConstraints(minHeight: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded, color: KirainColors.accent),
          const SizedBox(width: 4),
          Text(coins == null ? '…' : '$coins', style: text.titleMedium),
          if (opensShop) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.add_circle_rounded,
              size: 18,
              color: KirainColors.primary,
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: kBorderRadius,
        boxShadow: kSoftShadow,
      ),
      child: Material(
        color: KirainColors.surface,
        borderRadius: kBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: opensShop
            ? Tooltip(
                message: 'Toko',
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ShopPage()),
                  ),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}
