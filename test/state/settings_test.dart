import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/app_settings.dart';
import 'package:kirain/data/settings_repository.dart';
import 'package:kirain/services/game_audio.dart';
import 'package:kirain/services/link_opener.dart';
import 'package:kirain/state/settings_providers.dart';
import 'package:kirain/ui/widgets/settings_dialog.dart';

class _MemRepo implements SettingsRepository {
  _MemRepo([this.saved = const AppSettings()]);
  AppSettings saved;
  @override
  Future<AppSettings> load() async => saved;
  @override
  Future<void> save(AppSettings s) async => saved = s;
}

class _SpyAudio extends SilentGameAudio {
  final calls = <String>[];
  @override
  Future<void> playCorrect() async => calls.add('correct');
  @override
  Future<void> playWrong() async => calls.add('wrong');
}

class _SpyHaptics extends Haptics {
  final calls = <String>[];
  @override
  Future<void> wrong() async => calls.add('wrong');
}

void main() {
  test('toggle pengaturan tersimpan lewat repository', () async {
    final repo = _MemRepo();
    final c = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).setMusic(false);
    await c.read(settingsProvider.notifier).setVibration(false);
    expect(repo.saved, const AppSettings(music: false, vibration: false));
    expect(c.read(settingsProvider).value, repo.saved);
  });

  test('markTutorialSeen tersimpan tanpa mengubah pengaturan lain', () async {
    final repo = _MemRepo(const AppSettings(music: false));
    final c = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    );
    await c.read(settingsProvider.future);
    await c.read(settingsProvider.notifier).markTutorialSeen();
    expect(repo.saved, const AppSettings(music: false, tutorialSeen: true));
  });

  Future<(GameFeedback, _SpyAudio, _SpyHaptics)> feedbackWith(
    AppSettings s,
  ) async {
    final audio = _SpyAudio();
    final haptics = _SpyHaptics();
    final c = ProviderContainer.test(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_MemRepo(s)),
        gameAudioProvider.overrideWithValue(audio),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    await c.read(settingsProvider.future);
    return (c.read(gameFeedbackProvider), audio, haptics);
  }

  test('feedback default: suara benar/salah, getar hanya saat salah', () async {
    final (f, audio, haptics) = await feedbackWith(const AppSettings());
    f.correct();
    f.wrong();
    expect(audio.calls, ['correct', 'wrong']);
    expect(haptics.calls, ['wrong']);
  });

  test('feedback mengikuti pengaturan yang dimatikan', () async {
    final (f, audio, haptics) = await feedbackWith(
      const AppSettings(soundEffects: false, vibration: false),
    );
    f.correct();
    f.wrong();
    expect(audio.calls, isEmpty);
    expect(haptics.calls, isEmpty);
  });

  testWidgets('dialog pengaturan: switch mematikan backsound', (tester) async {
    final repo = _MemRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNWidgets(3));
    await tester.tap(find.text('Backsound'));
    await tester.pumpAndSettle();
    expect(repo.saved.music, isFalse);
    expect(repo.saved.soundEffects, isTrue);
    expect(repo.saved.vibration, isTrue);
  });

  Future<_SpyLinkOpener> pumpWithOpener(
    WidgetTester tester, {
    required bool succeed,
  }) async {
    final opener = _SpyLinkOpener(succeed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_MemRepo()),
          linkOpenerProvider.overrideWithValue(opener),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terms & Condition'));
    await tester.pumpAndSettle();
    return opener;
  }

  testWidgets('dialog pengaturan: Terms & Condition membuka link', (
    tester,
  ) async {
    final opener = await pumpWithOpener(tester, succeed: true);
    expect(opener.opened, [
      Uri.parse('https://jivottama.dev/kirain/termsandcondition'),
    ]);
    expect(find.text('Tidak bisa membuka halaman.'), findsNothing);
  });

  testWidgets('dialog pengaturan: link gagal dibuka -> pesan', (tester) async {
    await pumpWithOpener(tester, succeed: false);
    expect(find.text('Tidak bisa membuka halaman.'), findsOneWidget);
  });
}

class _SpyLinkOpener implements LinkOpener {
  _SpyLinkOpener(this.succeed);
  final bool succeed;
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeed;
  }
}
