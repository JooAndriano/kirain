import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dummy_puzzles.dart';
import '../data/puzzle.dart';
import '../data/puzzle_cache.dart';
import '../domain/stage.dart';
import 'firebase_providers.dart';

/// Asal daftar stage yang sedang dipakai.
enum StagesSource { remote, cache, dummy }

/// Daftar stage yang dipakai seluruh game.
class StagesState {
  const StagesState({
    required this.stages,
    this.source = StagesSource.remote,
    this.error,
  });

  /// Berurutan mulai stage 1 tanpa celah, masing-masing tepat 3 puzzle.
  final List<Stage> stages;
  final StagesSource source;

  /// Alasan tidak memakai data remote, untuk log/debug.
  final String? error;

  /// true jika Firestore gagal dan tidak ada cache, sehingga memakai dummy.
  bool get usingFallback => source == StagesSource.dummy;

  Stage? byNumber(int number) => stageByNumber(stages, number);
  int? nextAfter(int number) => nextStageNumber(stages, number);

  /// Puzzle untuk [stage]/[slot], atau null.
  Puzzle? puzzleAt(int stage, int slot) => byNumber(stage)?.puzzleAt(slot);
}

final stagesControllerProvider =
    AsyncNotifierProvider<StagesController, StagesState>(StagesController.new);

/// Di-override di main.dart dengan LocalPuzzleCache.
final puzzleCacheProvider = Provider<PuzzleCache>(
  (ref) => const NoPuzzleCache(),
);

/// Prefix URL gambar dari Remote Config.
final imageBaseUrlProvider = Provider<String>(
  (ref) => ref.watch(remoteSettingsProvider).imageBaseUrl,
);

void _log(String message) => debugPrint('Stages: $message');

/// Ambil puzzle dari [puzzleRepositoryProvider] lalu susun menjadi stage.
/// Berhasil -> simpan ke cache. Gagal (atau tidak ada stage lengkap) ->
/// pakai cache; tidak ada cache -> [dummyPuzzles] (StagesSource.dummy).
class StagesController extends AsyncNotifier<StagesState> {
  @override
  Future<StagesState> build() async {
    final repo = ref.watch(puzzleRepositoryProvider);
    final cache = ref.watch(puzzleCacheProvider);

    String reason;
    try {
      final puzzles = await repo.fetchPuzzles();
      final stages = buildStages(puzzles, log: _log);
      if (stages.isNotEmpty) {
        try {
          await cache.save(puzzles);
        } catch (e) {
          _log('Gagal menyimpan cache: $e');
        }
        return StagesState(stages: stages);
      }
      reason = 'Tidak ada stage lengkap di Firestore';
    } catch (e) {
      reason = '$e';
    }
    _log('Memakai cache/dummy: $reason');

    try {
      final cached = await cache.load();
      if (cached != null) {
        final stages = buildStages(cached, log: _log);
        if (stages.isNotEmpty) {
          return StagesState(
            stages: stages,
            source: StagesSource.cache,
            error: reason,
          );
        }
      }
    } catch (e) {
      _log('Gagal membaca cache: $e');
    }

    return StagesState(
      stages: buildStages(dummyPuzzles, log: _log),
      source: StagesSource.dummy,
      error: reason,
    );
  }

  /// Ambil ulang dari repository (mis. tombol "Muat ulang").
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
