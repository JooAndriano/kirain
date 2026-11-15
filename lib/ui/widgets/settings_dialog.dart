import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/ad_manager.dart';
import '../../state/settings_providers.dart';
import '../theme.dart';

Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).value;
    final notifier = ref.read(settingsProvider.notifier);
    final privacyRequired =
        ref.watch(privacyOptionsStatusProvider) == PrivacyOptionsStatus.required;

    Widget tile(
      String label,
      IconData icon,
      bool? value,
      void Function(bool) set,
    ) => SwitchListTile(
      secondary: Icon(icon, color: KirainColors.primary),
      title: Text(label),
      value: value ?? true,
      activeThumbColor: KirainColors.onPrimary,
      activeTrackColor: KirainColors.primary,
      onChanged: s == null ? null : set,
    );

    return AlertDialog(
      title: const Text('Pengaturan', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile(
            'Backsound',
            Icons.music_note_rounded,
            s?.music,
            notifier.setMusic,
          ),
          tile(
            'Efek suara',
            Icons.volume_up_rounded,
            s?.soundEffects,
            notifier.setSoundEffects,
          ),
          tile(
            'Getar',
            Icons.vibration_rounded,
            s?.vibration,
            notifier.setVibration,
          ),
          // Wajib bagi pengguna yang diminta consent (mis. EEA/UK): entri
          // untuk mengubah pilihan privasi iklan.
          if (privacyRequired)
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: KirainColors.primary,
              ),
              title: const Text('Pengaturan privasi'),
              onTap: () {
                final ads = ref.read(adManagerProvider);
                Navigator.of(context).pop();
                ads.showPrivacyOptions();
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
