import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Titik kait setelah sebuah stage tuntas. Nanti dipakai untuk iklan
/// interstitial; sekarang belum ada iklan sungguhan.
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
