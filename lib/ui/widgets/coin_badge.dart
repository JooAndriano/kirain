import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/progress_providers.dart';
import '../theme.dart';

/// Jumlah koin pemain, dibaca dari progressProvider.
class CoinBadge extends ConsumerWidget {
  const CoinBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(progressProvider).value?.coins;
    final text = Theme.of(context).textTheme;
    return Container(
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
          const Icon(Icons.monetization_on_rounded, color: KirainColors.accent),
          const SizedBox(width: 4),
          Text(coins == null ? '…' : '$coins', style: text.titleMedium),
        ],
      ),
    );
  }
}
