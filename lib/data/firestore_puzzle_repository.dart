import 'package:cloud_firestore/cloud_firestore.dart';

import 'puzzle.dart';
import 'puzzle_repository.dart';

/// Membaca koleksi `puzzles` dari Firestore (read-only).
///
/// Query hanya `active == true` tanpa orderBy, supaya tidak butuh composite
/// index; pengurutan stage lalu slot dilakukan di app.
class FirestorePuzzleRepository implements PuzzleRepository {
  FirestorePuzzleRepository(this._db);

  static const collection = 'puzzles';

  final FirebaseFirestore _db;

  @override
  Future<List<Puzzle>> fetchPuzzles() async {
    final QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection(collection)
          .where('active', isEqualTo: true)
          .get();
    } on FirebaseException catch (e) {
      throw PuzzleRepositoryException(_describe(e), e);
    } catch (e) {
      throw PuzzleRepositoryException('Gagal membaca Firestore', e);
    }

    // Offline tanpa cache: Firestore bisa mengembalikan hasil kosong dari
    // cache alih-alih error. Anggap gagal agar tidak dikira "0 puzzle".
    if (snap.docs.isEmpty && snap.metadata.isFromCache) {
      throw const PuzzleRepositoryException(
        'Offline dan belum ada cache puzzle. Sambungkan internet lalu coba lagi.',
      );
    }

    return sortPuzzles([
      for (final doc in snap.docs) Puzzle.fromFirestore(doc.id, doc.data()),
    ]);
  }

  static String _describe(FirebaseException e) => switch (e.code) {
    'unavailable' =>
      'Firestore tidak dapat dihubungi (offline?) dan belum ada cache puzzle.',
    'permission-denied' =>
      'Akses ke koleksi "$collection" ditolak. Periksa Firestore Security Rules.',
    _ => 'Gagal membaca Firestore [${e.code}]: ${e.message}',
  };
}
