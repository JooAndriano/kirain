import 'progress.dart';

/// Satu-satunya pintu akses data progress.
abstract class ProgressRepository {
  Future<Progress> load();
  Future<void> save(Progress p);
}
