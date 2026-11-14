import 'package:flutter/material.dart';

import 'level_select_page.dart';
import 'theme.dart';

/// Ditampilkan setelah level terakhir selesai (tidak ada level berikutnya).
class AllLevelsDonePage extends StatelessWidget {
  const AllLevelsDonePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final navigator = Navigator.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.emoji_events_rounded,
                size: 96,
                color: KirainColors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'Semua level selesai!',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hebat! Level baru akan segera hadir.',
                textAlign: TextAlign.center,
                style: text.bodyLarge,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Pilih Level'),
                onPressed: () => navigator.pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const LevelSelectPage(),
                  ),
                  (route) => route.isFirst,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: const Text('Beranda'),
                onPressed: () => navigator.popUntil((route) => route.isFirst),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
