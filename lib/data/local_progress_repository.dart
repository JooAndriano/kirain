import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';
import 'progress_repository.dart';

/// Menyimpan progress sebagai JSON pada satu key shared_preferences.
///
/// Data versi lama (tanpa/selain [Progress.schemaVersion]) atau rusak
/// diabaikan: load mengembalikan default dan save berikutnya menimpanya.
class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._prefs);

  static const storageKey = 'kirain.progress';

  final SharedPreferences _prefs;

  @override
  Future<Progress> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return Progress.initial();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return Progress.initial();
      return Progress.fromJson(decoded);
    } on FormatException {
      return Progress.initial();
    } on TypeError {
      return Progress.initial();
    }
  }

  @override
  Future<void> save(Progress p) async {
    await _prefs.setString(storageKey, jsonEncode(p.toJson()));
  }
}
