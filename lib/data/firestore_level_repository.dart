import 'package:cloud_firestore/cloud_firestore.dart';

import 'level.dart';
import 'level_repository.dart';

/// Membaca koleksi `levels` dari Firestore (read-only).
class FirestoreLevelRepository implements LevelRepository {
  FirestoreLevelRepository(this._db);

  static const collection = 'levels';

  final FirebaseFirestore _db;

  @override
  Future<List<Level>> fetchLevels() async {
    final QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection(collection)
          .where('active', isEqualTo: true)
          .orderBy('order')
          .get();
    } on FirebaseException catch (e) {
      throw LevelRepositoryException(_describe(e), e);
    } catch (e) {
      throw LevelRepositoryException('Gagal membaca Firestore', e);
    }

    // Offline tanpa cache: Firestore bisa mengembalikan hasil kosong dari
    // cache alih-alih error. Anggap gagal agar tidak dikira "0 level".
    if (snap.docs.isEmpty && snap.metadata.isFromCache) {
      throw const LevelRepositoryException(
        'Offline dan belum ada cache level. Sambungkan internet lalu coba lagi.',
      );
    }

    return [for (final doc in snap.docs) Level.fromFirestore(doc.data())];
  }

  static String _describe(FirebaseException e) => switch (e.code) {
    'unavailable' =>
      'Firestore tidak dapat dihubungi (offline?) dan belum ada cache level.',
    'permission-denied' =>
      'Akses ke koleksi "$collection" ditolak. Periksa Firestore Security Rules.',
    'failed-precondition' =>
      'Query butuh composite index (active ==, orderBy order). '
          'Buat index di: ${_firstUrl(e.message) ?? e.message}',
    _ => 'Gagal membaca Firestore [${e.code}]: ${e.message}',
  };

  static String? _firstUrl(String? text) =>
      text == null ? null : RegExp(r'https://\S+').firstMatch(text)?.group(0);
}
