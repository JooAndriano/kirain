import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_url_resolver.dart';
import '../data/puzzle.dart';
import '../data/puzzle_repository.dart';
import '../data/remote_settings.dart';
import '../domain/stage.dart';

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

/// Di-override di main.dart dengan FirestorePuzzleRepository bila Firebase siap.
final puzzleRepositoryProvider = Provider<PuzzleRepository>(
  (ref) => const UnavailablePuzzleRepository('Firebase belum diinisialisasi'),
);

/// Di-override di main.dart dengan FirebaseRemoteSettings bila Firebase siap.
final remoteSettingsProvider = Provider<RemoteSettings>(
  (ref) => const DefaultRemoteSettings(),
);

/// Ringkasan untuk halaman debug FirebaseCheckPage.
class FirebaseCheckReport {
  const FirebaseCheckReport({
    required this.status,
    required this.imageBaseUrl,
    this.puzzles,
    this.puzzleError,
  });

  final FirebaseStatus status;
  final String imageBaseUrl;

  /// null jika pengambilan gagal (lihat [puzzleError]).
  final List<Puzzle>? puzzles;
  final String? puzzleError;

  /// Jumlah stage lengkap yang bisa dimainkan dari [puzzles].
  int get stageCount => puzzles == null ? 0 : buildStages(puzzles!).length;

  Puzzle? get firstPuzzle =>
      puzzles == null || puzzles!.isEmpty ? null : puzzles!.first;

  String? get firstImageUrl => firstPuzzle == null
      ? null
      : ImageUrlResolver.resolve(imageBaseUrl, firstPuzzle!.imageFile);
}

/// Muat ulang Remote Config lalu ambil puzzle. Tidak pernah error: kegagalan
/// dicatat di [FirebaseCheckReport.puzzleError]. Invalidate untuk "Muat ulang".
final firebaseCheckProvider = FutureProvider.autoDispose<FirebaseCheckReport>((
  ref,
) async {
  final status = ref.watch(firebaseStatusProvider);
  final settings = ref.watch(remoteSettingsProvider);
  final repo = ref.watch(puzzleRepositoryProvider);

  await settings.init();
  try {
    final puzzles = await repo.fetchPuzzles();
    return FirebaseCheckReport(
      status: status,
      imageBaseUrl: settings.imageBaseUrl,
      puzzles: puzzles,
    );
  } catch (e) {
    return FirebaseCheckReport(
      status: status,
      imageBaseUrl: settings.imageBaseUrl,
      puzzleError: '$e',
    );
  }
});
