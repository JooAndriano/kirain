import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/app_settings.dart';
import 'package:kirain/data/local_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<LocalSettingsRepository> repoWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LocalSettingsRepository(await SharedPreferences.getInstance());
  }

  test('default: backsound, efek suara, dan getar aktif', () async {
    final s = await (await repoWith({})).load();
    expect(
      s,
      const AppSettings(music: true, soundEffects: true, vibration: true),
    );
  });

  test('save lalu load menghasilkan nilai yang sama', () async {
    final repo = await repoWith({});
    const s = AppSettings(music: false, soundEffects: true, vibration: false);
    await repo.save(s);
    expect(await repo.load(), s);
  });

  test(
    'tutorialSeen: default false, tersimpan, data lama tanpa key -> false',
    () async {
      expect((await (await repoWith({})).load()).tutorialSeen, isFalse);

      final repo = await repoWith({
        LocalSettingsRepository.storageKey:
            '{"music":false,"soundEffects":true,"vibration":true}',
      });
      expect(await repo.load(), const AppSettings(music: false));

      await repo.save(const AppSettings(tutorialSeen: true));
      expect((await repo.load()).tutorialSeen, isTrue);
    },
  );

  test('data rusak kembali ke default', () async {
    final repo = await repoWith({LocalSettingsRepository.storageKey: '{oops'});
    expect(await repo.load(), const AppSettings());
  });
}
