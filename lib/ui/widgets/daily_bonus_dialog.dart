import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/daily_bonus.dart';
import '../../state/progress_providers.dart';
import '../theme.dart';

/// Dialog klaim bonus harian.
Future<void> showDailyBonusDialog(
  BuildContext context,
  WidgetRef ref,
  DailyBonusOffer offer,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final text = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        title: Text(
          'Bonus Harian',
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 64,
              color: KirainColors.primary,
            ),
            const SizedBox(height: 8),
            Text('Hari ke-${offer.newStreak}', style: text.titleMedium),
            Text('+${offer.amount} koin', style: text.titleLarge),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(progressProvider.notifier).claimDailyBonus();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Klaim'),
          ),
        ],
      );
    },
  );
}
