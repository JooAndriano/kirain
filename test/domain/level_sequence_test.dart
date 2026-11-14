import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/level.dart';
import 'package:kirain/domain/level_sequence.dart';

Level lv(int order, {String answer = 'KUCING', String imageFile = 'a.webp'}) =>
    Level(
      id: order,
      order: order,
      imageFile: imageFile,
      answer: answer,
      focusX: 0.5,
      focusY: 0.5,
    );

void main() {
  // Sengaja tidak terurut dan bercelah.
  final levels = [lv(10), lv(2), lv(5)];

  group('nextOrder', () {
    test('order terkecil yang lebih besar', () {
      expect(nextOrder(levels, 2), 5);
      expect(nextOrder(levels, 5), 10);
    });

    test('level terakhir -> null (tidak ada level berikutnya)', () {
      expect(nextOrder(levels, 10), isNull);
    });

    test('order yang tidak ada di daftar tetap aman', () {
      expect(nextOrder(levels, 3), 5);
      expect(nextOrder(levels, 99), isNull);
      expect(nextOrder(const [], 1), isNull);
    });
  });

  test('levelByOrder', () {
    expect(levelByOrder(levels, 5)?.order, 5);
    expect(levelByOrder(levels, 4), isNull);
  });

  group('continueLevel', () {
    test('order terbesar yang sudah terbuka', () {
      expect(continueLevel(levels, 5)?.order, 5);
      expect(continueLevel(levels, 7)?.order, 5);
    });

    test('progress menunjuk level yang sudah tidak ada', () {
      expect(continueLevel(levels, 999)?.order, 10);
      expect(continueLevel(levels, 1)?.order, 2); // di bawah semua -> pertama
    });

    test('daftar kosong -> null', () {
      expect(continueLevel(const [], 3), isNull);
    });
  });

  group('playableLevels', () {
    test('terurut, order ganda dan level rusak dibuang', () {
      final result = playableLevels([
        lv(3),
        lv(1),
        lv(3, answer: 'GANDA'),
        lv(0),
        lv(4, answer: ''),
        lv(5, imageFile: ''),
        lv(6, answer: 'ABCDEFGHIJKLMNO'), // 15 huruf, papan cuma 14
        lv(7, answer: 'KUE LAPIS'),
      ]);
      expect(result.map((l) => l.order), [1, 3]);
      expect(result[1].answer, 'KUCING');
    });
  });
}
