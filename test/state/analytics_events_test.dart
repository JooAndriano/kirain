import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/services/analytics.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/state/stages_controller.dart';
import 'package:kirain/ui/game_controller.dart';

import '../support/fakes.dart';

class _SpyAnalytics extends SilentAnalytics {
  final events = <String>[];
  @override
  Future<void> puzzleStart(String puzzleId) async =>
      events.add('start:$puzzleId');
  @override
  Future<void> puzzleComplete(
    String puzzleId, {
    required int score,
    required bool firstSolve,
  }) async => events.add('complete:$puzzleId:$firstSolve');
  @override
  Future<void> stageComplete(
    int stage, {
    required int score,
    required int stars,
    required bool firstClear,
  }) async => events.add('stage:$stage:$firstClear');
  @override
  Future<void> hintUsed(
    String puzzleId,
    String hint, {
    required int cost,
  }) async => events.add('hint:$puzzleId:$hint:$cost');
  @override
  Future<void> dailyBonusClaimed({
    required int amount,
    required int streak,
  }) async => events.add('bonus:$amount:$streak');
}

void main() {
  late _SpyAnalytics spy;
  late ProviderContainer c;

  setUp(() {
    spy = _SpyAnalytics();
    c = ProviderContainer.test(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          MemProgressRepo(Progress(coins: 1000, highestUnlockedStage: 1)),
        ),
        analyticsProvider.overrideWithValue(spy),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 13)),
      ],
    );
  });

  /// Buka huruf sampai jawaban lengkap dan benar.
  Future<String> solve(int stage, int slot) async {
    final provider = gameControllerProvider((stage: stage, slot: slot));
    c.listen(provider, (_, _) {});
    final notifier = c.read(provider.notifier)..setImageReady(true);
    while (c.read(provider).snapshot.canReveal) {
      await notifier.revealLetter();
    }
    await pumpEventQueue();
    return c.read(provider).puzzle.id;
  }

  test('mulai gambar, pakai hint, dan selesai tercatat', () async {
    // Repo default gagal -> fallback dummy.
    await c.read(stagesControllerProvider.future);
    final provider = gameControllerProvider((stage: 1, slot: 1));
    c.listen(provider, (_, _) {});
    final id = c.read(provider).puzzle.id;
    expect(spy.events, ['start:$id']);

    c.read(provider.notifier).setImageReady(true);
    await c.read(provider.notifier).revealLetter();
    expect(
      spy.events.last,
      'hint:$id:reveal_letter:${Economy.revealLetterCost}',
    );

    await solve(1, 1);
    expect(spy.events.last, 'complete:$id:true');
  });

  test('gambar ke-3 mencatat stage selesai', () async {
    await c.read(stagesControllerProvider.future);
    await solve(1, 1);
    await solve(1, 2);
    await solve(1, 3);
    expect(spy.events.last, 'stage:1:true');
  });

  test('klaim bonus harian tercatat', () async {
    final amount = await c.read(progressProvider.notifier).claimDailyBonus();
    expect(spy.events, ['bonus:$amount:1']);
  });
}
