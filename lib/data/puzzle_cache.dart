import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle.dart';

/// Salinan lokal daftar puzzle terakhir yang berhasil diambil dari Firestore.
/// Dipakai saat Firestore gagal, sebelum jatuh ke dummy.
abstract class PuzzleCache {
  /// null jika belum ada cache, formatnya lama, atau rusak.
  Future<List<Puzzle>?> load();
  Future<void> save(List<Puzzle> puzzles);
}

/// Tidak menyimpan apa pun (default bila tidak di-override, mis. di tes).
class NoPuzzleCache implements PuzzleCache {
  const NoPuzzleCache();

  @override
  Future<List<Puzzle>?> load() async => null;

  @override
  Future<void> save(List<Puzzle> puzzles) async {}
}

/// Cache JSON pada satu key shared_preferences:
/// `{schemaVersion: 2, savedAt, puzzles: [...]}`. Versi lain diabaikan.
class LocalPuzzleCache implements PuzzleCache {
  LocalPuzzleCache(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'kirain.puzzleCache';
  static const int schemaVersion = 2;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  @override
  Future<List<Puzzle>?> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        return null;
      }
      final list = decoded['puzzles'];
      if (list is! List) return null;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) Puzzle.fromMap(item),
      ];
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(List<Puzzle> puzzles) async {
    await _prefs.setString(
      storageKey,
      jsonEncode({
        'schemaVersion': schemaVersion,
        'savedAt': _clock().toIso8601String(),
        'puzzles': [for (final p in puzzles) p.toMap()],
      }),
    );
  }
}
