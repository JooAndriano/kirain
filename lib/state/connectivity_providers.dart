import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'levels_controller.dart';

/// true jika ada koneksi jaringan (Wi-Fi/seluler/dll). Di-override di tes.
/// Jika plugin gagal, dianggap online agar banner tidak muncul keliru.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  try {
    yield isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true;
  }
  yield* connectivity.onConnectivityChanged
      .map(isOnline)
      .handleError((Object _) {});
});

/// Banner "Mode offline": level memakai fallback dummy, atau tidak ada koneksi.
final showOfflineBannerProvider = Provider<bool>((ref) {
  final fallback =
      ref.watch(levelsControllerProvider).value?.usingFallback ?? false;
  final online = ref.watch(onlineProvider).value ?? true;
  return fallback || !online;
});
