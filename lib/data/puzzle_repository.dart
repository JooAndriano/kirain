import 'puzzle.dart';

/// Sumber daftar puzzle. Hanya membaca, tidak pernah menulis.
abstract class PuzzleRepository {
  /// Puzzle aktif, terurut berdasarkan stage lalu slot.
  /// Melempar [PuzzleRepositoryException] jika data tidak bisa diambil.
  Future<List<Puzzle>> fetchPuzzles();
}

class PuzzleRepositoryException implements Exception {
  const PuzzleRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  /// Hanya [message]; detail asli tetap tersedia di [cause].
  @override
  String toString() => message;
}

/// Dipakai saat Firebase gagal diinisialisasi: selalu melempar dengan alasan
/// yang jelas, sehingga game tetap jalan memakai cache/dummy.
class UnavailablePuzzleRepository implements PuzzleRepository {
  const UnavailablePuzzleRepository(this.reason);

  final String reason;

  @override
  Future<List<Puzzle>> fetchPuzzles() async =>
      throw PuzzleRepositoryException('Sumber puzzle tidak tersedia: $reason');
}

/// Urutkan stage lalu slot (lalu id, agar deterministik).
List<Puzzle> sortPuzzles(Iterable<Puzzle> puzzles) =>
    [...puzzles]..sort((a, b) {
      final s = a.stage.compareTo(b.stage);
      if (s != 0) return s;
      final t = a.slot.compareTo(b.slot);
      return t != 0 ? t : a.id.compareTo(b.id);
    });
