import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/ui/game_controller.dart';
import 'package:kirain/ui/level_select_page.dart';

class _MemRepo implements ProgressRepository {
  _MemRepo(this.saved);
  Progress saved;
  @override
  Future<Progress> load() async => saved;
  @override
  Future<void> save(Progress p) async => saved = p;
}

void main() {
  ProviderContainer containerWith(int coins) => ProviderContainer.test(
    overrides: [
      progressRepositoryProvider.overrideWithValue(
        _MemRepo(Progress(coins: coins, highestUnlockedLevel: 1)),
      ),
    ],
  );

  test('hint buka huruf memotong koin', () async {
    final c = containerWith(50);
    final provider = gameControllerProvider(0);
    c.listen(provider, (_, _) {});
    final r = await c.read(provider.notifier).revealLetter();
    expect(r, HintResult.used);
    expect(
      (await c.read(progressProvider.future)).coins,
      50 - Economy.revealLetterCost,
    );
    expect(c.read(provider).snapshot.slots.first.locked, isTrue);
  });

  test('hint gagal jika koin kurang, papan tidak berubah', () async {
    final c = containerWith(Economy.removeWrongCost - 1);
    final provider = gameControllerProvider(0);
    c.listen(provider, (_, _) {});
    final r = await c.read(provider.notifier).removeWrongLetters();
    expect(r, HintResult.notEnoughCoins);
    expect(c.read(provider).snapshot.tiles.where((t) => t.hidden), isEmpty);
    expect(
      (await c.read(progressProvider.future)).coins,
      Economy.removeWrongCost - 1,
    );
  });

  test('menyelesaikan level menyimpan progress dan memberi koin', () async {
    final c = containerWith(500);
    final provider = gameControllerProvider(0);
    c.listen(provider, (_, _) {});
    final notifier = c.read(provider.notifier);
    while (c.read(provider).snapshot.canReveal) {
      await notifier.revealLetter();
    }
    // Tunggu completeLevel selesai.
    await pumpEventQueue();
    final state = c.read(provider);
    expect(state.firstClear, isTrue);
    final p = await c.read(progressProvider.future);
    expect(p.highestUnlockedLevel, 2);
    expect(p.starsPerLevel[1], state.snapshot.stars);
  });

  testWidgets('LevelTile terkunci: gembok dan tidak bisa ditap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox.square(
                dimension: 100,
                child: LevelTile(
                  number: 2,
                  locked: true,
                  stars: null,
                  onTap: () => taps++,
                ),
              ),
              SizedBox.square(
                dimension: 100,
                child: LevelTile(
                  number: 1,
                  locked: false,
                  stars: 2,
                  onTap: () => taps++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    await tester.tap(find.byIcon(Icons.lock_rounded));
    expect(taps, 0);
    await tester.tap(find.text('1'));
    expect(taps, 1);
  });
}
