import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/dummy_puzzles.dart';
import 'package:kirain/data/puzzle_cache.dart';
import 'package:kirain/data/puzzle_repository.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/stages_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  late FakePuzzleRepo repo;
  late MemPuzzleCache cache;

  setUp(() {
    repo = FakePuzzleRepo(fullStages(2).reversed.toList());
    cache = MemPuzzleCache();
  });

  ProviderContainer container({PuzzleCache? withCache}) =>
      ProviderContainer.test(
        overrides: [
          puzzleRepositoryProvider.overrideWithValue(repo),
          puzzleCacheProvider.overrideWithValue(withCache ?? cache),
        ],
      );

  test('Firestore sukses: stage tersusun dan cache disimpan', () async {
    final s = await container().read(stagesControllerProvider.future);
    expect(s.source, StagesSource.remote);
    expect(s.usingFallback, isFalse);
    expect(s.stages.map((x) => x.number), [1, 2]);
    expect(s.puzzleAt(2, 3)?.id, 'stage_002_3');
    expect(s.nextAfter(1), 2);
    expect(s.nextAfter(2), isNull);
    expect(cache.stored, hasLength(6));
  });

  test('stage tidak lengkap dari Firestore disembunyikan', () async {
    repo.puzzles = [...fullStages(1), puzzle(2, 1)];
    final s = await container().read(stagesControllerProvider.future);
    expect(s.stages.map((x) => x.number), [1]);
  });

  test('Firestore gagal + ada cache -> pakai cache, bukan dummy', () async {
    cache.stored = fullStages(3);
    repo.error = const PuzzleRepositoryException('offline');
    final s = await container().read(stagesControllerProvider.future);
    expect(s.source, StagesSource.cache);
    expect(s.usingFallback, isFalse);
    expect(s.stages, hasLength(3));
    expect(s.error, 'offline');
  });

  test('Firestore gagal tanpa cache -> dummy', () async {
    repo.error = const PuzzleRepositoryException('offline');
    final s = await container().read(stagesControllerProvider.future);
    expect(s.source, StagesSource.dummy);
    expect(s.usingFallback, isTrue);
    expect(s.stages.length, greaterThanOrEqualTo(2));
    expect(s.stages.first.puzzles.first.id, dummyPuzzles.first.id);
  });

  test('Firestore tanpa stage lengkap -> cache/dummy', () async {
    repo.puzzles = [puzzle(1, 1)];
    final s = await container().read(stagesControllerProvider.future);
    expect(s.usingFallback, isTrue);
    expect(cache.stored, isNull); // data tidak lengkap tidak di-cache
  });

  test('refresh mengambil ulang', () async {
    final c = container();
    c.listen(stagesControllerProvider, (_, _) {});
    await c.read(stagesControllerProvider.future);
    await c.read(stagesControllerProvider.notifier).refresh();
    expect(repo.calls, 2);
  });

  group('LocalPuzzleCache', () {
    Future<LocalPuzzleCache> local(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return LocalPuzzleCache(await SharedPreferences.getInstance());
    }

    test('save lalu load (schemaVersion 2)', () async {
      final c = await local({});
      await c.save(fullStages(1));
      final raw = (await SharedPreferences.getInstance()).getString(
        LocalPuzzleCache.storageKey,
      );
      expect(jsonDecode(raw!)['schemaVersion'], 2);
      final loaded = await c.load();
      expect(loaded!.map((p) => p.id), fullStages(1).map((p) => p.id));
      expect(loaded.first.toMap(), fullStages(1).first.toMap());
    });

    test(
      'cache format lama (tanpa/selain schemaVersion 2) diabaikan',
      () async {
        final oldFormat = jsonEncode({
          'levels': [
            {'id': 1, 'order': 1, 'answer': 'KUCING'},
          ],
        });
        expect(
          await (await local({LocalPuzzleCache.storageKey: oldFormat})).load(),
          isNull,
        );
        final v1 = jsonEncode({'schemaVersion': 1, 'puzzles': []});
        expect(
          await (await local({LocalPuzzleCache.storageKey: v1})).load(),
          isNull,
        );
        expect(
          await (await local({LocalPuzzleCache.storageKey: '{rusak'})).load(),
          isNull,
        );
      },
    );

    test('cache lama diabaikan -> controller jatuh ke dummy', () async {
      final v1 = jsonEncode({
        'schemaVersion': 1,
        'puzzles': [for (final p in fullStages(3)) p.toMap()],
      });
      repo.error = const PuzzleRepositoryException('offline');
      final c = container(
        withCache: await local({LocalPuzzleCache.storageKey: v1}),
      );
      final s = await c.read(stagesControllerProvider.future);
      expect(s.source, StagesSource.dummy);
    });
  });
}
