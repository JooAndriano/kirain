import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/state/progress_providers.dart';

class InMemoryProgressRepository implements ProgressRepository {
  InMemoryProgressRepository([Progress? initial])
    : saved = initial ?? Progress.initial();

  Progress saved;

  @override
  Future<Progress> load() async => saved;

  @override
  Future<void> save(Progress p) async => saved = p;
}

void main() {
  late InMemoryProgressRepository repo;
  late ProviderContainer container;
  var now = DateTime(2026, 11, 13, 8);

  setUp(() {
    repo = InMemoryProgressRepository();
    now = DateTime(2026, 11, 13, 8);
    container = ProviderContainer.test(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  ProgressNotifier notifier() => container.read(progressProvider.notifier);
  Future<Progress> progress() => container.read(progressProvider.future);

  group('spendCoins', () {
    test('berhasil jika koin cukup dan langsung disimpan', () async {
      expect(await notifier().spendCoins(30), isTrue);
      expect((await progress()).coins, 20);
      expect(repo.saved.coins, 20);
    });

    test('gagal jika koin kurang, koin tidak berubah', () async {
      expect(await notifier().spendCoins(51), isFalse);
      expect((await progress()).coins, 50);
      expect(repo.saved.coins, 50);
    });
  });

  test('addCoins menambah dan menyimpan', () async {
    await notifier().addCoins(25);
    expect(repo.saved.coins, 75);
  });

  group('completeLevel', () {
    test(
      'tidak menimpa bintang/skor lebih tinggi dengan yang lebih rendah',
      () async {
        expect(await notifier().completeLevel(1, 90, 3, coins: 9), isTrue);
        expect(await notifier().completeLevel(1, 20, 1, coins: 2), isFalse);

        final p = await progress();
        expect(p.starsPerLevel[1], 3);
        expect(p.bestScorePerLevel[1], 90);
        expect(p.highestUnlockedLevel, 2);
        expect(p.coins, 59); // koin hanya saat pertama kali
        expect(repo.saved, p);
      },
    );
  });

  group('claimDailyBonus', () {
    test('sekali per hari, streak naik di hari berikutnya', () async {
      expect(container.read(dailyBonusOfferProvider), isNull); // belum dimuat
      await progress();
      expect(container.read(dailyBonusOfferProvider)?.amount, 20);

      expect(await notifier().claimDailyBonus(), 20);
      expect(await notifier().claimDailyBonus(), 0);
      expect(container.read(dailyBonusOfferProvider), isNull);
      expect(repo.saved.coins, 70);
      expect(repo.saved.lastDailyBonusDate, '2026-11-13');

      now = DateTime(2026, 11, 14, 8);
      expect(await notifier().claimDailyBonus(), 30);
      expect(repo.saved.dailyStreak, 2);
    });
  });

  test('progress dimuat dari repository', () async {
    final c = ProviderContainer.test(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          InMemoryProgressRepository(
            Progress(coins: 7, highestUnlockedLevel: 3),
          ),
        ),
      ],
    );
    final p = await c.read(progressProvider.future);
    expect(p.coins, 7);
    expect(p.highestUnlockedLevel, 3);
  });
}
