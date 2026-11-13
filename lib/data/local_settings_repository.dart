import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

/// Menyimpan pengaturan sebagai JSON pada satu key shared_preferences.
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._prefs);

  static const storageKey = 'kirain.settings';

  final SharedPreferences _prefs;

  @override
  Future<AppSettings> load() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } on FormatException {
      return const AppSettings();
    } on TypeError {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings s) async {
    await _prefs.setString(storageKey, jsonEncode(s.toJson()));
  }
}
