import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/state/connectivity_providers.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/ui/home_page.dart';
import 'package:kirain/ui/splash_page.dart';

class _MemRepo implements ProgressRepository {
  Progress saved = Progress(
    coins: 50,
    highestUnlockedLevel: 1,
    lastDailyBonusDate: '2026-11-13',
    dailyStreak: 1,
  );
  @override
  Future<Progress> load() async => saved;
  @override
  Future<void> save(Progress p) async => saved = p;
}

void main() {
  testWidgets('SplashPage beranimasi lalu pindah ke HomePage', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(_MemRepo()),
          // Bonus hari ini sudah diklaim, jadi tidak ada dialog di Home.
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 13)),
          // Plugin connectivity tidak tersedia di tes.
          onlineProvider.overrideWithValue(const AsyncData(true)),
        ],
        child: const MaterialApp(home: SplashPage()),
      ),
    );

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Pilih Level'), findsOneWidget);
  });
}
