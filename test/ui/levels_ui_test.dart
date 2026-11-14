import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/image_url_resolver.dart';
import 'package:kirain/data/level.dart';
import 'package:kirain/data/level_repository.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/state/connectivity_providers.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/ui/game_page.dart';
import 'package:kirain/ui/level_image.dart';
import 'package:kirain/ui/level_select_page.dart';
import 'package:kirain/ui/widgets/offline_banner.dart';
import 'package:kirain/ui/widgets/zoom_image.dart';

class _MemRepo implements ProgressRepository {
  _MemRepo(this.saved);
  Progress saved;
  Object? error;
  @override
  Future<Progress> load() async {
    if (error != null) throw error!;
    return saved;
  }

  @override
  Future<void> save(Progress p) async => saved = p;
}

/// Repo palsu yang bisa ditahan (loading), gagal, atau sukses.
class _FakeLevels implements LevelRepository {
  _FakeLevels(this.levels);
  List<Level> levels;
  Object? error;
  Completer<void>? gate;

  @override
  Future<List<Level>> fetchLevels() async {
    await gate?.future;
    if (error != null) throw error!;
    return levels;
  }
}

Level remote(int order) => Level(
  id: order,
  order: order,
  imageFile: 'l$order.webp',
  answer: 'KUCING',
  focusX: 0.5,
  focusY: 0.5,
);

void main() {
  late _FakeLevels levels;
  late _MemRepo progress;

  setUp(() {
    levels = _FakeLevels([remote(10), remote(20)]);
    progress = _MemRepo(Progress(coins: 50, highestUnlockedLevel: 10));
  });

  Widget app(Widget home, {bool online = true}) => ProviderScope(
    overrides: [
      levelRepositoryProvider.overrideWithValue(levels),
      progressRepositoryProvider.overrideWithValue(progress),
      onlineProvider.overrideWithValue(AsyncData(online)),
    ],
    child: MaterialApp(home: home),
  );

  group('LevelSelectPage', () {
    testWidgets('skeleton saat memuat, lalu tile bernomor order', (
      tester,
    ) async {
      levels.gate = Completer();
      await tester.pumpWidget(app(const LevelSelectPage()));
      await tester.pump();
      expect(find.byKey(const ValueKey('level-skeleton')), findsWidgets);

      levels.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('level-skeleton')), findsNothing);
      expect(find.text('10'), findsOneWidget); // terbuka
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget); // order 20
    });

    testWidgets('error -> tombol Muat ulang memuat ulang', (tester) async {
      progress.error = Exception('rusak');
      await tester.pumpWidget(app(const LevelSelectPage()));
      await tester.pumpAndSettle();
      expect(find.text('Daftar level belum bisa dimuat'), findsOneWidget);

      progress.error = null;
      await tester.tap(find.text('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('progress menunjuk order yang tidak ada: tidak crash', (
      tester,
    ) async {
      progress.saved = Progress(
        coins: 0,
        highestUnlockedLevel: 999,
        starsPerLevel: const {3: 2, 10: 3},
      );
      await tester.pumpWidget(app(const LevelSelectPage()));
      await tester.pumpAndSettle();
      expect(find.text('10'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      levels.error = const LevelRepositoryException('offline');
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(find.textContaining('Mode offline'), findsOneWidget);

      levels.error = null;
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

  testWidgets('GamePage: order tidak ada -> pesan, tidak crash', (
    tester,
  ) async {
    await tester.pumpWidget(app(const GamePage(order: 99)));
    await tester.pumpAndSettle();
    expect(find.text('Level tidak ditemukan'), findsOneWidget);
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
