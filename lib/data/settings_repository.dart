import 'app_settings.dart';

/// Satu-satunya pintu akses data pengaturan.
abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings s);
}
