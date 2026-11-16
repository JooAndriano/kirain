import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/app_settings.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/settings_repository.dart';
import 'package:kirain/domain/tutorial.dart';
import 'package:kirain/state/connectivity_providers.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/state/settings_providers.dart';
import 'package:kirain/ui/game_page.dart';
import 'package:kirain/ui/home_page.dart';
import 'package:kirain/ui/shop_page.dart';
import 'package:kirain/ui/widgets/coach_marks.dart';
import 'package:kirain/ui/widgets/coin_badge.dart';
import 'package:kirain/ui/widgets/how_to_play_dialog.dart';

import '../support/fakes.dart';

class _MemSettings implements SettingsRepository {
  _MemSettings(this.saved);
  AppSettings saved;
  @override
  Future<AppSettings> load() async => saved;
  @override
  Future<void> save(AppSettings s) async => saved = s;
}

void main() {
  late _MemSettings settings;

  Widget app(Widget home) => ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settings),
      progressRepositoryProvider.overrideWithValue(
        MemProgressRepo(
          Progress(
            coins: 50,
            highestUnlockedStage: 1,
            lastDailyBonusDate: '2099-01-01',
          ),
        ),
      ),
      onlineProvider.overrideWithValue(const AsyncData(true)),
      // Bonus harian sudah diambil hari ini: tidak ada dialog bonus.
      clockProvider.overrideWithValue(() => DateTime(2099)),
    ],
    child: MaterialApp(home: home),
  );

  /// Animasi tutorial berulang terus; pump dengan durasi, bukan settle.
  Future<void> pumpFor(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void wideView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    settings = _MemSettings(const AppSettings());
  });

  testWidgets('pertama kali main: tutorial tampil, selesai -> tersimpan', (
    tester,
  ) async {
    wideView(tester);
    await tester.pumpWidget(app(const GamePage(stage: 1)));
    await pumpFor(tester);

    expect(find.byType(CoachMarks), findsOneWidget);
    expect(find.text(kTutorialSteps.first.title), findsOneWidget);
    expect(find.text('1/${kTutorialSteps.length}'), findsOneWidget);

    for (var i = 1; i < kTutorialSteps.length; i++) {
      await tester.tap(find.text('Lanjut'));
      await pumpFor(tester);
      expect(find.text('${i + 1}/${kTutorialSteps.length}'), findsOneWidget);
    }
    expect(settings.saved.tutorialSeen, isFalse);
    await tester.tap(find.text('Mengerti'));
    await pumpFor(tester);

    expect(find.byType(CoachMarks), findsNothing);
    expect(settings.saved.tutorialSeen, isTrue);
  });

  testWidgets('Lewati menutup tutorial dan tidak muncul lagi', (tester) async {
    await tester.pumpWidget(app(const GamePage(stage: 1)));
    await pumpFor(tester);
    await tester.tap(find.text('Lewati'));
    await pumpFor(tester);
    expect(find.byType(CoachMarks), findsNothing);
    expect(settings.saved.tutorialSeen, isTrue);

    // Halaman baru: tutorial tidak tampil otomatis lagi.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const GamePage(stage: 1)));
    await pumpFor(tester);
    expect(find.byType(CoachMarks), findsNothing);
  });

  testWidgets('di dalam game: tanpa tombol bantuan, koin membuka Toko', (
    tester,
  ) async {
    wideView(tester);
    settings = _MemSettings(const AppSettings(tutorialSeen: true));
    await tester.pumpWidget(app(const GamePage(stage: 1)));
    await pumpFor(tester);
    expect(find.byType(CoachMarks), findsNothing);
    expect(find.byTooltip('Cara bermain'), findsNothing);
    expect(find.text('Hilangkan Huruf Salah'), findsOneWidget);
    expect(find.text('Hapus Huruf Salah'), findsNothing);

    await tester.tap(find.byType(CoinBadge));
    await pumpFor(tester);
    expect(find.byType(ShopPage), findsOneWidget);
  });

  testWidgets('home: tombol ? -> Cara Bermain -> main dengan tutorial', (
    tester,
  ) async {
    settings = _MemSettings(const AppSettings(tutorialSeen: true));
    await tester.pumpWidget(app(const HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cara bermain'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayDialog), findsOneWidget);
    expect(find.text('Salah pilih huruf?'), findsOneWidget);

    await tester.tap(find.text('Main dengan tutorial'));
    await pumpFor(tester);
    expect(settings.saved.tutorialSeen, isFalse);
    expect(find.byType(GamePage), findsOneWidget);
    expect(find.byType(CoachMarks), findsOneWidget);
  });
}
