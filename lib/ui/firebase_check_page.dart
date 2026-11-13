import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final first = r.firstLevel;
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
          label: 'Level Firestore',
          value: r.levels == null ? 'GAGAL' : '${r.levels!.length} level',
          ok: r.levels != null && r.levels!.isNotEmpty,
          detail: r.levelError,
        ),
        if (r.indexUrl != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Salin tautan index'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: r.indexUrl!));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tautan disalin. Buka di browser.'),
                ),
              );
            },
          ),
        if (first != null) ...[
          const Divider(height: 32),
          Text('Level pertama', style: Theme.of(context).textTheme.titleMedium),
          for (final e in first.toMap().entries)
            _Row(label: e.key, value: '${e.value}'),
          _Row(label: 'URL gambar', value: r.firstImageUrl ?? '-'),
        ],
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
