import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/dummy_levels.dart';
import 'package:kirain/data/level.dart';
import 'package:kirain/data/level_repository.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/levels_controller.dart';

/// Repository palsu; tidak pernah memanggil Firebase.
class FakeLevelRepository implements LevelRepository {
  FakeLevelRepository(this.levels);

  List<Level> levels;
  Object? error;
  int calls = 0;

  @override
  Future<List<Level>> fetchLevels() async {
    calls++;
    if (error != null) throw error!;
    return levels;
  }
}

Level remote(int order, String answer) => Level(
  id: order,
  order: order,
  imageFile: '${answer.toLowerCase()}.webp',
  answer: answer,
  focusX: 0.5,
  focusY: 0.5,
);

void main() {
  late FakeLevelRepository repo;

  setUp(() {
    repo = FakeLevelRepository([remote(20, 'GAJAH'), remote(10, 'KUCING')]);
  });

  ProviderContainer container() => ProviderContainer.test(
    overrides: [levelRepositoryProvider.overrideWithValue(repo)],
  );

  test('sukses: level Firestore terurut, bukan fallback', () async {
    final s = await container().read(levelsControllerProvider.future);
    expect(s.usingFallback, isFalse);
    expect(s.error, isNull);
    expect(s.levels.map((l) => l.order), [10, 20]);
    expect(s.levels.every((l) => !l.isLocal), isTrue);
    expect(s.nextOrderAfter(10), 20);
  });

  test('gagal tanpa cache -> dummy, usingFallback = true', () async {
    repo.error = const LevelRepositoryException('offline tanpa cache');
    final s = await container().read(levelsControllerProvider.future);
    expect(s.usingFallback, isTrue);
    expect(s.error, contains('offline tanpa cache'));
    expect(s.levels.map((l) => l.order), dummyLevels.map((l) => l.order));
    expect(s.levels.every((l) => l.isLocal), isTrue);
  });

  test('Firebase tidak tersedia (repo default) -> dummy', () async {
    final s = await ProviderContainer.test().read(
      levelsControllerProvider.future,
    );
    expect(s.usingFallback, isTrue);
  });

  test('daftar kosong / tidak valid -> dummy', () async {
    repo.levels = [remote(0, 'KUCING')];
    final s = await container().read(levelsControllerProvider.future);
    expect(s.usingFallback, isTrue);
  });

  test('tidak ada level berikutnya setelah level terakhir', () async {
    final s = await container().read(levelsControllerProvider.future);
    expect(s.nextOrderAfter(20), isNull);
    expect(s.byOrder(99), isNull);
  });

  test('refresh: pulih dari fallback setelah online', () async {
    repo.error = const LevelRepositoryException('offline');
    final c = container();
    c.listen(levelsControllerProvider, (_, _) {});
    expect((await c.read(levelsControllerProvider.future)).usingFallback, true);

    repo.error = null;
    await c.read(levelsControllerProvider.notifier).refresh();
    final s = c.read(levelsControllerProvider).requireValue;
    expect(s.usingFallback, isFalse);
    expect(s.levels.first.answer, 'KUCING');
    expect(repo.calls, 2);
  });
}
