import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/services/analytics.dart';
import 'package:kirain/state/levels_controller.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/ui/game_controller.dart';

class _MemRepo implements ProgressRepository {
  _MemRepo(this.saved);
  Progress saved;
  @override
  Future<Progress> load() async => saved;
  @override
  Future<void> save(Progress p) async => saved = p;
}

class _SpyAnalytics extends SilentAnalytics {
  final events = <String>[];
  @override
  Future<void> levelStart(int levelId) async => events.add('start:$levelId');
  @override
  Future<void> levelComplete(
    int levelId, {
    required int score,
    required int stars,
    required bool firstClear,
  }) async => events.add('complete:$levelId:$firstClear');
  @override
  Future<void> hintUsed(int levelId, String hint, {required int cost}) async =>
      events.add('hint:$levelId:$hint:$cost');
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
          _MemRepo(Progress(coins: 1000, highestUnlockedLevel: 1)),
        ),
        analyticsProvider.overrideWithValue(spy),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 13)),
      ],
    );
  });

  test('mulai level, pakai hint, dan selesai tercatat', () async {
    // Repo level default gagal -> fallback dummy (order 1..5).
    await c.read(levelsControllerProvider.future);
    final provider = gameControllerProvider(1);
    c.listen(provider, (_, _) {});
    final id = c.read(provider).level.id;
    expect(spy.events, ['start:$id']);

    c.read(provider.notifier).setImageReady(true);
    await c.read(provider.notifier).revealLetter();
    expect(
      spy.events.last,
      'hint:$id:reveal_letter:${Economy.revealLetterCost}',
    );

    // Buka huruf sampai jawaban lengkap dan benar.
    while (c.read(provider).snapshot.canReveal) {
      await c.read(provider.notifier).revealLetter();
    }
    await Future<void>.delayed(Duration.zero);
    expect(spy.events.last, 'complete:$id:true');
  });

  test('klaim bonus harian tercatat', () async {
    final amount = await c.read(progressProvider.notifier).claimDailyBonus();
    expect(spy.events, ['bonus:$amount:1']);
  });
}
