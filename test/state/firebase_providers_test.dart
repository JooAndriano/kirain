import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/puzzle.dart';
import 'package:kirain/data/puzzle_repository.dart';
import 'package:kirain/data/remote_settings.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/ui/firebase_check_page.dart';

class FakePuzzleRepository implements PuzzleRepository {
  FakePuzzleRepository(this.levels);

  List<Puzzle> levels;
  Object? error;
  int calls = 0;

  @override
  Future<List<Puzzle>> fetchPuzzles() async {
    calls++;
    if (error != null) throw error!;
    return levels;
  }
}

class FakeRemoteSettings implements RemoteSettings {
  FakeRemoteSettings(this.imageBaseUrl);

  @override
  String imageBaseUrl;
  int initCalls = 0;

  @override
  Future<void> init() async => initCalls++;
}

const _kucing = Puzzle(
  id: 'stage_001_1',
  stage: 1,
  slot: 1,
  imageFile: 'kucing.webp',
  answer: 'KUCING',
  focusX: 0.5,
  focusY: 0.5,
  packId: 'hewan',
);

void main() {
  late FakePuzzleRepository repo;
  late FakeRemoteSettings settings;

  setUp(() {
    repo = FakePuzzleRepository([_kucing]);
    settings = FakeRemoteSettings('https://cdn.test/img/');
  });

  ProviderContainer container({FirebaseStatus? status}) =>
      ProviderContainer.test(
        overrides: [
          puzzleRepositoryProvider.overrideWithValue(repo),
          remoteSettingsProvider.overrideWithValue(settings),
          firebaseStatusProvider.overrideWithValue(
            status ?? const FirebaseStatus.ready(),
          ),
        ],
      );

  test(
    'default tanpa override: repo melempar pesan jelas, base URL default',
    () async {
      final c = ProviderContainer.test();
      expect(c.read(remoteSettingsProvider).imageBaseUrl, kDefaultImageBaseUrl);
      await expectLater(
        c.read(puzzleRepositoryProvider).fetchPuzzles(),
        throwsA(isA<PuzzleRepositoryException>()),
      );
    },
  );

  group('firebaseCheckProvider', () {
    test('sukses: jumlah puzzle, puzzle pertama, dan URL gambar', () async {
      final c = container();
      final r = await c.read(firebaseCheckProvider.future);

      expect(settings.initCalls, 1);
      expect(r.status.ready, isTrue);
      expect(r.imageBaseUrl, 'https://cdn.test/img/');
      expect(r.puzzles, hasLength(1));
      expect(r.puzzleError, isNull);
      expect(r.firstPuzzle?.answer, 'KUCING');
      expect(r.firstImageUrl, 'https://cdn.test/img/kucing.webp');
    });

    test('repo gagal -> report berisi error, provider tidak error', () async {
      repo.error = const PuzzleRepositoryException('offline tanpa cache');
      final c = container();
      final r = await c.read(firebaseCheckProvider.future);

      expect(r.puzzles, isNull);
      expect(r.puzzleError, contains('offline tanpa cache'));
      expect(r.firstPuzzle, isNull);
      expect(r.firstImageUrl, isNull);
    });

    test('daftar kosong -> tidak ada puzzle pertama', () async {
      repo.levels = [];
      final r = await container().read(firebaseCheckProvider.future);
      expect(r.puzzles, isEmpty);
      expect(r.firstPuzzle, isNull);
    });

    test('Firebase gagal init -> status diteruskan', () async {
      final c = container(status: const FirebaseStatus.failed('no config'));
      final r = await c.read(firebaseCheckProvider.future);
      expect(r.status.ready, isFalse);
      expect(r.status.error, 'no config');
    });

    test('invalidate -> init Remote Config dan fetch diulang', () async {
      final c = container();
      final sub = c.listen(firebaseCheckProvider, (_, _) {});
      await c.read(firebaseCheckProvider.future);

      settings.imageBaseUrl = 'https://baru.test/';
      c.invalidate(firebaseCheckProvider);
      final r = await c.read(firebaseCheckProvider.future);

      expect(settings.initCalls, 2);
      expect(repo.calls, 2);
      expect(r.imageBaseUrl, 'https://baru.test/');
      sub.close();
    });
  });

  testWidgets('FirebaseCheckPage menampilkan hasil dan bisa muat ulang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          puzzleRepositoryProvider.overrideWithValue(repo),
          remoteSettingsProvider.overrideWithValue(settings),
          firebaseStatusProvider.overrideWithValue(
            const FirebaseStatus.ready(),
          ),
        ],
        child: const MaterialApp(home: FirebaseCheckPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OK (terinisialisasi)'), findsOneWidget);
    expect(find.text('https://cdn.test/img/'), findsOneWidget);
    expect(find.text('1 puzzle · 0 stage lengkap'), findsOneWidget);
    expect(find.text('KUCING'), findsOneWidget);
    expect(find.text('https://cdn.test/img/kucing.webp'), findsOneWidget);

    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });
}
