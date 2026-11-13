import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_url_resolver.dart';
import '../data/level.dart';
import '../data/level_repository.dart';
import '../data/remote_settings.dart';

/// Hasil Firebase.initializeApp di main.dart.
class FirebaseStatus {
  const FirebaseStatus.ready() : ready = true, error = null;
  const FirebaseStatus.failed(this.error) : ready = false;

  final bool ready;
  final String? error;
}

/// Di-override di main.dart.
final firebaseStatusProvider = Provider<FirebaseStatus>(
  (ref) => const FirebaseStatus.failed('belum diinisialisasi'),
);

/// Di-override di main.dart dengan FirestoreLevelRepository bila Firebase siap.
final levelRepositoryProvider = Provider<LevelRepository>(
  (ref) => const UnavailableLevelRepository('Firebase belum diinisialisasi'),
);

/// Di-override di main.dart dengan FirebaseRemoteSettings bila Firebase siap.
final remoteSettingsProvider = Provider<RemoteSettings>(
  (ref) => const DefaultRemoteSettings(),
);

/// Level dari Firestore. Belum dipakai game (game masih dummy).
final remoteLevelsProvider = FutureProvider.autoDispose<List<Level>>(
  (ref) => ref.watch(levelRepositoryProvider).fetchLevels(),
);

/// Ringkasan untuk halaman debug FirebaseCheckPage.
class FirebaseCheckReport {
  const FirebaseCheckReport({
    required this.status,
    required this.imageBaseUrl,
    this.levels,
    this.levelError,
  });

  final FirebaseStatus status;
  final String imageBaseUrl;

  /// null jika pengambilan gagal (lihat [levelError]).
  final List<Level>? levels;
  final String? levelError;

  Level? get firstLevel =>
      levels == null || levels!.isEmpty ? null : levels!.first;

  /// Tautan pembuatan index Firestore, jika error-nya karena index belum ada.
  String? get indexUrl => levelError == null
      ? null
      : RegExp(
          r'https://console\.firebase\.google\.com/\S*indexes\S*',
        ).firstMatch(levelError!)?.group(0);

  String? get firstImageUrl => firstLevel == null
      ? null
      : ImageUrlResolver.resolve(imageBaseUrl, firstLevel!.imageFile);
}

/// Muat ulang Remote Config lalu ambil level. Tidak pernah error: kegagalan
/// dicatat di [FirebaseCheckReport.levelError]. Invalidate untuk "Muat ulang".
final firebaseCheckProvider = FutureProvider.autoDispose<FirebaseCheckReport>((
  ref,
) async {
  final status = ref.watch(firebaseStatusProvider);
  final settings = ref.watch(remoteSettingsProvider);
  final repo = ref.watch(levelRepositoryProvider);

  await settings.init();
  try {
    final levels = await repo.fetchLevels();
    return FirebaseCheckReport(
      status: status,
      imageBaseUrl: settings.imageBaseUrl,
      levels: levels,
    );
  } catch (e) {
    return FirebaseCheckReport(
      status: status,
      imageBaseUrl: settings.imageBaseUrl,
      levelError: '$e',
    );
  }
});
