import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/dummy_levels.dart';
import 'package:kirain/data/level.dart';

void main() {
  group('Level.fromFirestore', () {
    test('membaca dokumen lengkap', () {
      final level = Level.fromFirestore({
        'id': 7,
        'imageFile': 'kucing.webp',
        'answer': 'KUCING',
        'focusX': -0.5,
        'focusY': 0.5,
        'packId': 'hewan',
        'order': 12,
        'difficulty': 2,
        'active': true,
      });

      expect(level.id, 7);
      expect(level.imageFile, 'kucing.webp');
      expect(level.answer, 'KUCING');
      // Firestore -1..1 -> model 0..1.
      expect(level.focusX, 0.25);
      expect(level.focusY, 0.75);
      expect(level.packId, 'hewan');
      expect(level.order, 12);
      expect(level.difficulty, 2);
      expect(level.active, isTrue);
      expect(level.isLocal, isFalse);
    });

    test('fokus 0 di Firestore = tengah gambar', () {
      final level = Level.fromFirestore({'focusX': 0, 'focusY': 0});
      expect(level.focusX, 0.5);
      expect(level.focusY, 0.5);
    });

    test('field hilang -> nilai default aman', () {
      final level = Level.fromFirestore({});

      expect(level.id, 0);
      expect(level.imageFile, '');
      expect(level.answer, '');
      expect(level.focusX, 0.5);
      expect(level.focusY, 0.5);
      expect(level.packId, '');
      expect(level.order, 0);
      expect(level.difficulty, 1);
      expect(level.active, isFalse);
    });

    test('order hilang -> memakai id', () {
      expect(Level.fromFirestore({'id': 4}).order, 4);
    });

    test('tipe salah -> default, tidak melempar', () {
      final level = Level.fromFirestore({
        'id': '7',
        'imageFile': 123,
        'answer': null,
        'focusX': 'tengah',
        'focusY': double.nan,
        'packId': false,
        'order': 'satu',
        'difficulty': <int>[],
        'active': 'true',
      });

      expect(level.id, 0);
      expect(level.imageFile, '');
      expect(level.answer, '');
      expect(level.focusX, 0.5);
      expect(level.focusY, 0.5);
      expect(level.packId, '');
      expect(level.order, 0);
      expect(level.difficulty, 1);
      expect(level.active, isFalse);
    });

    test('angka Firestore int/double dikonversi', () {
      final level = Level.fromFirestore({
        'id': 3.0,
        'focusX': 1,
        'focusY': -1,
        'order': 5.0,
      });

      expect(level.id, 3);
      expect(level.focusX, 1.0);
      expect(level.focusY, 0.0);
      expect(level.order, 5);
    });

    test('fokus di luar -1..1 dijepit', () {
      final level = Level.fromFirestore({'focusX': -1.2, 'focusY': 1.8});
      expect(level.focusX, 0.0);
      expect(level.focusY, 1.0);
    });

    test('jawaban dinormalisasi: huruf besar tanpa spasi', () {
      final level = Level.fromFirestore({'answer': ' kue  lapis\n'});
      expect(level.answer, 'KUELAPIS');
    });

    test('imageFile dan packId di-trim', () {
      final level = Level.fromFirestore({
        'imageFile': '  a.png ',
        'packId': ' p1 ',
      });
      expect(level.imageFile, 'a.png');
      expect(level.packId, 'p1');
    });
  });

  test('toMap -> fromFirestore bolak-balik sama', () {
    for (final l in dummyLevels) {
      final back = Level.fromFirestore(l.toMap());
      expect(back.focusX, closeTo(l.focusX, 1e-9));
      expect(back.focusY, closeTo(l.focusY, 1e-9));
      expect(back.answer, l.answer);
      expect(back.order, l.order);
      expect(back.imageFile, l.imageFile);
    }
  });

  test('toMap menulis fokus dalam -1..1', () {
    final m = dummyLevels.first.toMap();
    expect(m['focusX'], 0.0);
    expect(m.containsKey('isLocal'), isFalse);
  });

  test('dummy levels lokal, memakai nama file, order unik', () {
    for (final l in dummyLevels) {
      expect(l.imageFile, isNot(contains('/')));
      expect(l.active, isTrue);
      expect(l.isLocal, isTrue);
    }
    expect(dummyLevels.map((l) => l.order).toSet(), hasLength(5));
  });
}
