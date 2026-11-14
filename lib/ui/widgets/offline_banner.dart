import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/connectivity_providers.dart';
import '../../state/levels_controller.dart';
import '../theme.dart';

/// Banner kecil "Mode offline". Tidak tampil apa pun saat online dan level
/// berasal dari Firestore.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showOfflineBannerProvider)) return const SizedBox.shrink();
    final usingFallback =
        ref.watch(levelsControllerProvider).value?.usingFallback ?? false;
    final loading = ref.watch(levelsControllerProvider).isLoading;
    final text = Theme.of(context).textTheme;

    return Material(
      color: KirainColors.offlineBanner,
      borderRadius: kBorderRadius,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: KirainColors.onOfflineBanner,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                usingFallback ? 'Mode offline · level contoh' : 'Mode offline',
                style: text.bodyMedium?.copyWith(
                  color: KirainColors.onOfflineBanner,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (usingFallback)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: KirainColors.accent,
                ),
                onPressed: loading
                    ? null
                    : () =>
                          ref.read(levelsControllerProvider.notifier).refresh(),
                child: const Text('Coba lagi'),
              )
            else
              const SizedBox(height: kMinTap),
          ],
        ),
      ),
    );
  }
}
