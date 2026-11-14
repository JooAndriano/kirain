import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/image_url_resolver.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/puzzle_repository.dart';
import 'package:kirain/services/stage_hooks.dart';
import 'package:kirain/state/connectivity_providers.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/ui/all_stages_done_page.dart';
import 'package:kirain/ui/game_page.dart';
import 'package:kirain/ui/home_page.dart';
import 'package:kirain/ui/level_image.dart';
import 'package:kirain/ui/stage_select_page.dart';
import 'package:kirain/ui/widgets/offline_banner.dart';
import 'package:kirain/ui/widgets/zoom_image.dart';

import '../support/fakes.dart';

class _SpyHook implements StageCompletionHook {
  final stages = <int>[];
  @override
  Future<void> onStageCompleted(int stage) async => stages.add(stage);
}

void main() {
  late FakePuzzleRepo puzzles;
  late MemProgressRepo progress;

  setUp(() {
    puzzles = FakePuzzleRepo(fullStages(2));
    progress = MemProgressRepo(Progress(coins: 50, highestUnlockedStage: 1));
  });

  Widget app(
    Widget home, {
    bool online = true,
    bool useDummy = false,
    StageCompletionHook? hook,
  }) => ProviderScope(
    overrides: [
      // Tanpa override repo: selalu gagal -> stage dummy (aset lokal).
      if (!useDummy) puzzleRepositoryProvider.overrideWithValue(puzzles),
      progressRepositoryProvider.overrideWithValue(progress),
      onlineProvider.overrideWithValue(AsyncData(online)),
      if (hook != null) stageCompletionHookProvider.overrideWithValue(hook),
    ],
    child: MaterialApp(home: home),
  );

  group('StageSelectPage', () {
    testWidgets('skeleton saat memuat, lalu tile stage', (tester) async {
      puzzles.gate = Completer();
      await tester.pumpWidget(app(const StageSelectPage()));
      await tester.pump();
      expect(find.byKey(const ValueKey('stage-skeleton')), findsWidgets);

      puzzles.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stage-skeleton')), findsNothing);
      expect(find.text('Pilih Stage'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // terbuka
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget); // stage 2
      expect(find.text('Stage 2'), findsOneWidget);
    });

    testWidgets('bintang terbaik dan label Lanjut k/3', (tester) async {
      progress.saved = Progress(
        coins: 0,
        highestUnlockedStage: 2,
        stageStars: const {1: 2},
        inProgress: StageRun(stage: 2, solved: const {1: 80}),
      );
      await tester.pumpWidget(app(const StageSelectPage()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.text('Lanjut 1/3'), findsOneWidget);

      // Tap stage 2 -> lanjut di gambar 2.
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Stage 2 · Gambar 2/3'), findsOneWidget);
    });

    testWidgets('error -> tombol Muat ulang memuat ulang', (tester) async {
      progress.error = Exception('rusak');
      await tester.pumpWidget(app(const StageSelectPage()));
      await tester.pumpAndSettle();
      expect(find.text('Daftar stage belum bisa dimuat'), findsOneWidget);

      progress.error = null;
      await tester.tap(find.text('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('stage tidak lengkap / setelah celah tidak tampil', (
      tester,
    ) async {
      puzzles.puzzles = [
        ...fullStages(1),
        puzzle(2, 1), // stage 2 tidak lengkap
        for (var slot = 1; slot <= 3; slot++) puzzle(3, slot),
      ];
      progress.saved = Progress(coins: 0, highestUnlockedStage: 99);
      await tester.pumpWidget(app(const StageSelectPage()));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  group('HomePage', () {
    testWidgets('Main (Stage 1) untuk pemain baru', (tester) async {
      progress.saved = Progress(
        coins: 50,
        highestUnlockedStage: 1,
        lastDailyBonusDate: '2099-01-01',
      );
      await tester.pumpWidget(app(const HomePage()));
      await tester.pumpAndSettle();
      expect(find.text('Main (Stage 1)'), findsOneWidget);
      expect(find.text('Pilih Stage'), findsOneWidget);
    });

    testWidgets('Lanjutkan menunjuk inProgress', (tester) async {
      progress.saved = Progress(
        coins: 50,
        highestUnlockedStage: 2,
        stageStars: const {1: 3},
        inProgress: StageRun(stage: 2, solved: const {1: 80, 2: 70}),
        lastDailyBonusDate: '2099-01-01',
      );
      await tester.pumpWidget(app(const HomePage()));
      await tester.pumpAndSettle();
      expect(find.text('Lanjutkan (Stage 2 · Gambar 3/3)'), findsOneWidget);
    });
  });

  group('OfflineBanner', () {
    Widget banner({bool online = true}) =>
        app(const Scaffold(body: OfflineBanner()), online: online);

    testWidgets('online + Firestore sukses: tidak tampil', (tester) async {
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(find.textContaining('Mode offline'), findsNothing);
    });

    testWidgets('fallback dummy: tampil dengan Coba lagi', (tester) async {
      puzzles.error = const PuzzleRepositoryException('offline');
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(find.text('Mode offline · stage contoh'), findsOneWidget);

      puzzles.error = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mode offline'), findsNothing);
    });

    testWidgets('tanpa koneksi: tampil', (tester) async {
      await tester.pumpWidget(banner(online: false));
      await tester.pumpAndSettle();
      expect(find.text('Mode offline'), findsOneWidget);
    });
  });

  group('GamePage', () {
    testWidgets('stage tidak ada -> pesan, tidak crash', (tester) async {
      await tester.pumpWidget(app(const GamePage(stage: 99)));
      await tester.pumpAndSettle();
      expect(find.text('Stage tidak ditemukan'), findsOneWidget);
    });

    /// Tunggu transisi halaman tanpa pumpAndSettle (spinner gambar
    /// berputar terus sampai aset benar-benar dimuat lewat runAsync).
    Future<void> settleRoute(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Muat gambar aset lokal (dummy) lalu buka huruf sampai benar.
    Future<void> solveCurrent(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      final reveal = find.text('Buka Huruf');
      for (var i = 0; i < 20; i++) {
        final button = tester.widget<ElevatedButton>(
          find.ancestor(of: reveal, matching: find.byType(ElevatedButton)),
        );
        if (button.onPressed == null) break;
        await tester.tap(reveal);
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
      'header k/3, dialog gambar -> Lanjut, gambar 3 -> dialog stage selesai',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 3200);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final hook = _SpyHook();
        progress.saved = Progress(coins: 5000, highestUnlockedStage: 1);
        await tester.pumpWidget(
          app(const GamePage(stage: 1), useDummy: true, hook: hook),
        );
        await settleRoute(tester);
        expect(find.text('Stage 1 · Gambar 1/3'), findsOneWidget);
        expect(find.byType(StageDot), findsNWidgets(3));

        await solveCurrent(tester);
        expect(find.text('Benar!'), findsOneWidget);
        expect(find.textContaining('koin'), findsOneWidget);
        await tester.tap(find.text('Lanjut'));
        await settleRoute(tester);
        expect(find.text('Stage 1 · Gambar 2/3'), findsOneWidget);

        await solveCurrent(tester);
        await tester.tap(find.text('Lanjut'));
        await settleRoute(tester);
        expect(find.text('Stage 1 · Gambar 3/3'), findsOneWidget);

        await solveCurrent(tester);
        expect(find.text('Stage 1 selesai!'), findsOneWidget);
        expect(find.text('+15 koin bonus stage'), findsOneWidget);
        expect(hook.stages, [1]);
        expect(progress.saved.highestUnlockedStage, 2);

        await tester.tap(find.text('Stage berikutnya'));
        await settleRoute(tester);
        expect(find.text('Stage 2 · Gambar 1/3'), findsOneWidget);
      },
    );

    testWidgets('stage terakhir selesai -> layar semua stage selesai', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Gambar 1 dan 2 stage 2 (terakhir di dummy) sudah benar sebelumnya.
      progress.saved = Progress(
        coins: 5000,
        highestUnlockedStage: 2,
        inProgress: StageRun(stage: 2, solved: const {1: 100, 2: 100}),
      );
      await tester.pumpWidget(
        app(const GamePage(stage: 2, slot: 3), useDummy: true),
      );
      await settleRoute(tester);
      await solveCurrent(tester);
      expect(find.text('Stage 2 selesai!'), findsOneWidget);
      await tester.tap(find.text('Selesai'));
      await settleRoute(tester);
      expect(find.byType(AllStagesDonePage), findsOneWidget);
      expect(find.text('Semua stage selesai!'), findsOneWidget);
    });
  });

  group('LevelImageStatusTracker', () {
    test('placeholder setelah gambar (fade OctoImage) tidak menurunkan '
        'status loaded', () {
      final t = LevelImageStatusTracker();
      expect(t.update(LevelImageStatus.loading), isTrue);
      // Satu frame fade: imageBuilder lalu placeholder.
      expect(t.update(LevelImageStatus.loaded), isTrue);
      expect(t.update(LevelImageStatus.loading), isFalse);
      expect(t.status, LevelImageStatus.loaded);
    });

    test('error lalu Coba lagi (reset) bisa loading -> loaded lagi', () {
      final t = LevelImageStatusTracker()
        ..update(LevelImageStatus.loading)
        ..update(LevelImageStatus.error);
      t.reset();
      expect(t.update(LevelImageStatus.loading), isTrue);
      expect(t.update(LevelImageStatus.loaded), isTrue);
    });

    test('status sama tidak dilaporkan dua kali', () {
      final t = LevelImageStatusTracker()..update(LevelImageStatus.loaded);
      expect(t.update(LevelImageStatus.loaded), isFalse);
    });
  });

  group('ZoomImage / LevelImage', () {
    Future<List<LevelImageStatus>> pumpImage(
      WidgetTester tester,
      String asset,
    ) async {
      final statuses = <LevelImageStatus>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 300,
              child: ZoomImage(
                source: LocalLevelImage(asset),
                scale: 2,
                focusX: 0.25,
                focusY: 0.75,
                onStatusChanged: statuses.add,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      return statuses;
    }

    testWidgets('aset lokal termuat, zoom ke titik fokus tetap berlaku', (
      tester,
    ) async {
      final statuses = await pumpImage(tester, 'assets/images/level1.png');
      expect(statuses.last, LevelImageStatus.loaded);
      final transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(ZoomImage),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.alignment, const Alignment(-0.5, 0.5));
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(2, 1e-6));
    });

    testWidgets('gagal dimuat: pesan ramah + Coba lagi, tanpa zoom', (
      tester,
    ) async {
      final statuses = await pumpImage(tester, 'assets/images/tidak_ada.png');
      expect(statuses.last, LevelImageStatus.error);
      expect(find.text('Gambar belum bisa dimuat'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      // Pesan error tidak ikut di-scale.
      expect(
        find.descendant(
          of: find.byType(LevelImageError),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(LevelImageError),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Coba lagi'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gambar belum bisa dimuat'), findsOneWidget);
    });
  });
}
