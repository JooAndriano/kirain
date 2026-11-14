import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/services/stage_hooks.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/state/stages_controller.dart';
import 'package:kirain/ui/game_controller.dart';
import 'package:kirain/ui/stage_select_page.dart';

import '../support/fakes.dart';

class _SpyHook implements StageCompletionHook {
  final stages = <int>[];
  @override
  Future<void> onStageCompleted(int stage) async => stages.add(stage);
}

void main() {
  late _SpyHook hook;
  late MemProgressRepo repo;

  // Tanpa override puzzleRepositoryProvider: repo default selalu gagal, jadi
  // stage berasal dari fallback dummy (2 stage). Tidak memanggil Firebase.
  Future<ProviderContainer> containerWith(int coins) async {
    hook = _SpyHook();
    repo = MemProgressRepo(Progress(coins: coins, highestUnlockedStage: 1));
    final c = ProviderContainer.test(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        stageCompletionHookProvider.overrideWithValue(hook),
      ],
    );
    c.listen(stagesControllerProvider, (_, _) {});
    await c.read(stagesControllerProvider.future);
    return c;
  }

  /// Controller untuk stage/slot dengan gambar dianggap sudah termuat.
  GameController ready(ProviderContainer c, int stage, int slot) {
    final provider = gameControllerProvider((stage: stage, slot: slot));
    c.listen(provider, (_, _) {});
    return c.read(provider.notifier)..setImageReady(true);
  }

  /// Selesaikan gambar dengan hint buka huruf, kembalikan state akhirnya.
  Future<GameState> solve(ProviderContainer c, int stage, int slot) async {
    final provider = gameControllerProvider((stage: stage, slot: slot));
    final notifier = ready(c, stage, slot);
    while (c.read(provider).canReveal) {
      await notifier.revealLetter();
    }
    await pumpEventQueue();
    return c.read(provider);
  }

  test('hint buka huruf memotong koin', () async {
    final c = await containerWith(50);
    final provider = gameControllerProvider((stage: 1, slot: 1));
    final r = await ready(c, 1, 1).revealLetter();
    expect(r, HintResult.used);
    expect(
      (await c.read(progressProvider.future)).coins,
      50 - Economy.revealLetterCost,
    );
    expect(c.read(provider).snapshot.slots.first.locked, isTrue);
  });

  test('hint gagal jika koin kurang, papan tidak berubah', () async {
    final c = await containerWith(Economy.removeWrongCost - 1);
    final provider = gameControllerProvider((stage: 1, slot: 1));
    final r = await ready(c, 1, 1).removeWrongLetters();
    expect(r, HintResult.notEnoughCoins);
    expect(c.read(provider).snapshot.tiles.where((t) => t.hidden), isEmpty);
  });

  test('gambar 1-2 benar: hasil gambar tanpa stage selesai', () async {
    final c = await containerWith(1000);
    final s = await solve(c, 1, 1);
    expect(s.saved, isTrue);
    expect(s.result!.firstSolve, isTrue);
    expect(s.result!.stageClear, isNull);
    expect(s.isLastSlot, isFalse);
    expect(repo.saved.inProgress?.solved.keys, [1]);
    expect(hook.stages, isEmpty);
  });

  test('gambar 3 menuntaskan stage, hook dipanggil, stage 2 terbuka', () async {
    final c = await containerWith(1000);
    await solve(c, 1, 1);
    await solve(c, 1, 2);
    final s = await solve(c, 1, 3);
    final clear = s.result!.stageClear!;
    expect(clear.firstClear, isTrue);
    expect(clear.bonusCoins, Economy.stageClearBonusCoins);
    expect(s.nextStage, 2);
    expect(hook.stages, [1]);
    expect(repo.saved.highestUnlockedStage, 2);
    expect(repo.saved.inProgress, isNull);
    expect(repo.saved.stageStars[1], clear.stars);
  });

  test('stage terakhir: tidak ada stage berikutnya', () async {
    final c = await containerWith(50);
    final state = c.read(gameControllerProvider((stage: 2, slot: 3)));
    expect(state.nextStage, isNull);
    expect(state.isLastStage, isTrue);
    expect(state.isLastSlot, isTrue);
  });

  test('gambar belum termuat: Zoom Out dan hint ditolak', () async {
    final c = await containerWith(50);
    final provider = gameControllerProvider((stage: 1, slot: 1));
    c.listen(provider, (_, _) {});
    final notifier = c.read(provider.notifier);
    final before = c.read(provider).snapshot.score;

    expect(c.read(provider).canZoomOut, isFalse);
    notifier.zoomOut();
    expect(c.read(provider).snapshot.score, before);
    expect(await notifier.revealLetter(), HintResult.unavailable);
    expect((await c.read(progressProvider.future)).coins, 50);

    notifier.setImageReady(true);
    expect(c.read(provider).canZoomOut, isTrue);
    notifier.zoomOut();
    expect(c.read(provider).snapshot.score, lessThan(before));
  });

  testWidgets('StageTile terkunci: gembok, teks Stage N, tidak bisa ditap', (
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
                child: StageTile(
                  number: 2,
                  locked: true,
                  stars: null,
                  onTap: () => taps++,
                ),
              ),
              SizedBox.square(
                dimension: 100,
                child: StageTile(
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
    expect(find.text('Stage 2'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    await tester.tap(find.byIcon(Icons.lock_rounded));
    expect(taps, 0);
    await tester.tap(find.text('1'));
    expect(taps, 1);
  });
}
