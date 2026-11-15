import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/ad_manager.dart';
import '../state/firebase_providers.dart';

/// Halaman debug (hanya dibuka saat kDebugMode) untuk memeriksa koneksi
/// Firebase, Remote Config, dan data Firestore.
class FirebaseCheckPage extends ConsumerWidget {
  const FirebaseCheckPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(firebaseCheckProvider);
    final loading = report.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Cek Firebase')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Muat ulang'),
        onPressed: loading ? null : () => ref.invalidate(firebaseCheckProvider),
      ),
      body: report.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error tak terduga: $e')),
        data: (r) => _ReportView(report: r),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});

  final FirebaseCheckReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final first = r.firstPuzzle;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _Row(
          label: 'Firebase',
          value: r.status.ready ? 'OK (terinisialisasi)' : 'GAGAL',
          ok: r.status.ready,
          detail: r.status.error,
        ),
        _Row(label: 'imageBaseUrl', value: r.imageBaseUrl),
        _Row(
          label: 'Puzzle Firestore',
          value: r.puzzles == null
              ? 'GAGAL'
              : '${r.puzzles!.length} puzzle · ${r.stageCount} stage lengkap',
          ok: r.stageCount > 0,
          detail: r.puzzleError,
        ),
        if (first != null) ...[
          const Divider(height: 32),
          Text(
            'Puzzle pertama',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final e in first.toMap().entries)
            _Row(label: e.key, value: '${e.value}'),
          _Row(label: 'URL gambar', value: r.firstImageUrl ?? '-'),
        ],
        const Divider(height: 32),
        const AdsDebugSection(),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.ok, this.detail});

  final String label;
  final String value;
  final bool? ok;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: ok == null
          ? null
          : Icon(
              ok! ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok! ? scheme.primary : scheme.error,
            ),
      title: Text(label),
      subtitle: SelectableText(detail == null ? value : '$value\n$detail'),
    );
  }
}

/// Bagian "Ads": status consent, SDK, muat iklan, dan log (mode debug).
class AdsDebugSection extends ConsumerWidget {
  const AdsDebugSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(adManagerProvider);
    final params = ref.watch(adParamsProvider);
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<AdStatus>(
      valueListenable: manager.status,
      builder: (context, s, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ads', style: text.titleMedium),
          _Row(
            label: 'Mode',
            value: s.useTestAds ? 'Iklan TES' : 'Iklan ASLI',
            ok: s.useTestAds,
          ),
          _Row(label: 'Consent', value: s.consent),
          _Row(label: 'Privacy options', value: s.privacyOptions.name),
          _Row(
            label: 'canRequestAds',
            value: '${s.canRequestAds}',
            ok: s.canRequestAds,
          ),
          _Row(
            label: 'MobileAds',
            value: s.sdkInitialized ? 'siap' : 'belum diinisialisasi',
            ok: s.sdkInitialized,
          ),
          _Row(label: 'Interstitial', value: s.interstitial.name),
          _Row(label: 'Rewarded', value: s.rewarded.name),
          _Row(
            label: 'Iklan layar penuh terakhir',
            value: s.lastFullScreenAdAt?.toIso8601String() ?? '-',
          ),
          _Row(label: 'Remote Config', value: '$params'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Reset consent'),
              onPressed: manager.resetConsent,
            ),
          ),
          if (s.log.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Log', style: text.titleSmall),
            for (final line in s.log) Text(line, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
