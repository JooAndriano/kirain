import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Titik kait setelah sebuah stage tuntas (sebelum dialog). Interstitial
/// TIDAK dipasang di sini: iklan hanya tampil atas aksi pemain lewat
/// AdManager.maybeShowInterstitialAfterStage di dialog stage selesai.
abstract class StageCompletionHook {
  /// Dipanggil sekali setiap stage tuntas, sebelum dialog stage selesai
  /// ditampilkan. Tidak boleh melempar.
  Future<void> onStageCompleted(int stage);
}

class NoopStageCompletionHook implements StageCompletionHook {
  const NoopStageCompletionHook();

  @override
  Future<void> onStageCompleted(int stage) async {}
}

final stageCompletionHookProvider = Provider<StageCompletionHook>(
  (ref) => const NoopStageCompletionHook(),
);
