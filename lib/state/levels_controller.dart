import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dummy_levels.dart';
import '../data/level.dart';
import '../domain/level_sequence.dart';
import 'firebase_providers.dart';

/// Daftar level yang dipakai seluruh game.
class LevelsState {
  const LevelsState({
    required this.levels,
    this.usingFallback = false,
    this.error,
  });

  /// Terurut berdasarkan [Level.order], order unik.
  final List<Level> levels;

  /// true jika Firestore gagal (dan tidak ada cache) sehingga memakai dummy.
  final bool usingFallback;

  /// Alasan fallback, untuk log/debug.
  final String? error;

  Level? byOrder(int order) => levelByOrder(levels, order);
  int? nextOrderAfter(int order) => nextOrder(levels, order);
}

final levelsControllerProvider =
    AsyncNotifierProvider<LevelsController, LevelsState>(LevelsController.new);

/// Prefix URL gambar dari Remote Config.
final imageBaseUrlProvider = Provider<String>(
  (ref) => ref.watch(remoteSettingsProvider).imageBaseUrl,
);

/// Ambil level dari [levelRepositoryProvider]. Jika gagal (offline tanpa
/// cache, Firebase tidak tersedia, dsb.) atau tidak ada level yang bisa
/// dimainkan, pakai [dummyLevels] dengan [LevelsState.usingFallback] = true.
class LevelsController extends AsyncNotifier<LevelsState> {
  @override
  Future<LevelsState> build() async {
    final repo = ref.watch(levelRepositoryProvider);
    try {
      final levels = playableLevels(await repo.fetchLevels());
      if (levels.isNotEmpty) return LevelsState(levels: levels);
      return _fallback('Tidak ada level aktif yang valid di Firestore');
    } catch (e) {
      return _fallback('$e');
    }
  }

  LevelsState _fallback(String reason) => LevelsState(
    levels: playableLevels(dummyLevels),
    usingFallback: true,
    error: reason,
  );

  /// Ambil ulang dari repository (mis. tombol "Muat ulang").
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
