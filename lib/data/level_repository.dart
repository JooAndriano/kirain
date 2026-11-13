import 'level.dart';

/// Sumber daftar level. Hanya membaca, tidak pernah menulis.
abstract class LevelRepository {
  /// Level aktif, terurut berdasarkan [Level.order].
  /// Melempar [LevelRepositoryException] jika data tidak bisa diambil.
  Future<List<Level>> fetchLevels();
}

class LevelRepositoryException implements Exception {
  const LevelRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  /// Hanya [message]; detail asli tetap tersedia di [cause].
  @override
  String toString() => message;
}

/// Dipakai saat Firebase gagal diinisialisasi: selalu melempar dengan alasan
/// yang jelas, sehingga game tetap jalan memakai dummy.
class UnavailableLevelRepository implements LevelRepository {
  const UnavailableLevelRepository(this.reason);

  final String reason;

  @override
  Future<List<Level>> fetchLevels() async =>
      throw LevelRepositoryException('Sumber level tidak tersedia: $reason');
}
