import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/ads/ad_manager.dart';
import 'package:kirain/data/app_settings.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/settings_repository.dart';
import 'package:kirain/state/connectivity_providers.dart';
import 'package:kirain/state/firebase_providers.dart';
import 'package:kirain/state/progress_providers.dart';
import 'package:kirain/state/settings_providers.dart';
import 'package:kirain/ui/home_page.dart';

import '../support/fakes.dart';

class _MemSettings implements SettingsRepository {
  AppSettings saved = const AppSettings();

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings s) async => saved = s;
}

void main() {
  late FakeAdManager ads;

  setUp(() => ads = FakeAdManager());

  Widget app() => ProviderScope(
    overrides: [
      adManagerProvider.overrideWithValue(ads),
      puzzleRepositoryProvider.overrideWithValue(FakePuzzleRepo(fullStages(1))),
      progressRepositoryProvider.overrideWithValue(
        MemProgressRepo(
          Progress(
            coins: 50,
            highestUnlockedStage: 1,
            lastDailyBonusDate: '2099-01-01',
          ),
        ),
      ),
      settingsRepositoryProvider.overrideWithValue(_MemSettings()),
      onlineProvider.overrideWithValue(const AsyncData(true)),
      // Bonus harian sudah diklaim hari ini: tanpa dialog bonus.
      clockProvider.overrideWithValue(() => DateTime(2099, 1, 1, 9)),
    ],
    child: const MaterialApp(home: HomePage()),
  );

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
  }

  void setPrivacy(PrivacyOptionsStatus p) =>
      ads.setStatus((s) => s.copyWith(privacyOptions: p));

  testWidgets('status required -> tombol tampil; ditekan memanggil form', (
    tester,
  ) async {
    setPrivacy(PrivacyOptionsStatus.required);
    await openSettings(tester);
    expect(find.text('Pengaturan privasi'), findsOneWidget);

    await tester.tap(find.text('Pengaturan privasi'));
    await tester.pumpAndSettle();
    expect(ads.privacyOptionsShows, 1);
    expect(find.text('Pengaturan privasi'), findsNothing); // dialog tertutup
  });

  testWidgets('status notRequired -> tombol tidak tampil', (tester) async {
    setPrivacy(PrivacyOptionsStatus.notRequired);
    await openSettings(tester);
    expect(find.text('Pengaturan privasi'), findsNothing);
  });

  testWidgets('status unknown (belum dicek) -> tombol tidak tampil', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('Pengaturan privasi'), findsNothing);
  });

  testWidgets('status berubah ke required saat dialog terbuka -> tampil', (
    tester,
  ) async {
    setPrivacy(PrivacyOptionsStatus.notRequired);
    await openSettings(tester);
    expect(find.text('Pengaturan privasi'), findsNothing);

    setPrivacy(PrivacyOptionsStatus.required);
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan privasi'), findsOneWidget);
  });

  test('privacyOptionsStatusProvider mengikuti status AdManager', () {
    final c = ProviderContainer.test(
      overrides: [adManagerProvider.overrideWithValue(ads)],
    );
    expect(c.read(privacyOptionsStatusProvider), PrivacyOptionsStatus.unknown);

    setPrivacy(PrivacyOptionsStatus.required);
    expect(c.read(privacyOptionsStatusProvider), PrivacyOptionsStatus.required);

    ads.privacyOptionsAfterForm = PrivacyOptionsStatus.notRequired;
    c.read(adManagerProvider).showPrivacyOptions();
    expect(
      c.read(privacyOptionsStatusProvider),
      PrivacyOptionsStatus.notRequired,
    );
  });
}
