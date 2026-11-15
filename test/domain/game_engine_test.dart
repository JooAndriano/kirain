import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/domain/game_engine.dart';

GameEngine engine(String answer, [int seed = 1]) =>
    GameEngine(answer, random: Random(seed));

/// Id tile untuk huruf [letter] yang masih tersedia di papan.
int tileFor(GameEngine e, String letter) =>
    e.snapshot.tiles.firstWhere((t) => t.letter == letter && t.available).id;

void type(GameEngine e, String word) {
  for (final c in word.split('')) {
    e.tapTile(tileFor(e, c));
  }
}

String slotsText(GameEngine e) =>
    e.snapshot.slots.map((s) => s.letter ?? '_').join();

void main() {
  group('GameEngine setup', () {
    test('14 huruf memuat semua huruf jawaban, kotak sepanjang jawaban', () {
      for (var seed = 0; seed < 20; seed++) {
        final e = engine('PISANG', seed);
        final letters = e.tiles.map((t) => t.letter).toList();
        expect(letters, hasLength(14));
        for (final c in 'PISANG'.split('')) {
          expect(letters, contains(c));
        }
        expect(e.snapshot.slots, hasLength(6));
        expect(e.snapshot.status, GameStatus.playing);
      }
    });

    test('huruf ganda pada jawaban tersedia sebanyak yang dibutuhkan', () {
      final e = engine('PAPAYA');
      final letters = e.tiles.map((t) => t.letter).toList();
      expect(letters.where((c) => c == 'A').length, 3);
      expect(letters.where((c) => c == 'P').length, 2);
    });

    test('jawaban lebih dari 14 huruf ditolak', () {
      expect(() => GameEngine('ABCDEFGHIJKLMNO'), throwsArgumentError);
    });
  });

  group('isi dan kembalikan', () {
    test('tap huruf mengisi kotak kosong pertama', () {
      final e = engine('KUCING');
      type(e, 'KU');
      expect(slotsText(e), 'KU____');
    });

    test('tap kotak terisi mengembalikan huruf ke papan', () {
      final e = engine('KUCING');
      type(e, 'KUC');
      final uId = e.snapshot.tiles
          .firstWhere((t) => t.letter == 'U' && t.used)
          .id;
      e.tapSlot(1);
      expect(slotsText(e), 'K_C___');
      expect(e.snapshot.tiles.firstWhere((t) => t.id == uId).used, isFalse);
      // Huruf berikutnya mengisi kotak kosong pertama (indeks 1).
      type(e, 'U');
      expect(slotsText(e), 'KUC___');
    });

    test('tile yang sudah dipakai tidak bisa ditap lagi', () {
      final e = engine('KUCING');
      final k = tileFor(e, 'K');
      e.tapTile(k);
      e.tapTile(k);
      expect(slotsText(e), 'K_____');
    });
  });

  group('evaluasi', () {
    test('jawaban benar -> status correct', () {
      final e = engine('GITAR');
      type(e, 'GITAR');
      expect(e.snapshot.status, GameStatus.correct);
      expect(e.snapshot.score, 100);
    });

    test('jawaban salah -> wrongCount++ dan kotak dikosongkan', () {
      final e = engine('GITAR');
      type(e, 'TIGAR');
      final s = e.snapshot;
      expect(s.status, GameStatus.playing);
      expect(s.wrongCount, 1);
      expect(slotsText(e), '_____');
      expect(s.tiles.every((t) => !t.used), isTrue);
      expect(s.score, 95);
    });

    test('setelah correct, input diabaikan', () {
      final e = engine('GITAR');
      type(e, 'GITAR');
      e.tapSlot(0);
      expect(slotsText(e), 'GITAR');
      expect(e.zoomOut(), isFalse);
      expect(e.revealLetter(), isFalse);
      expect(e.removeWrongLetters(), isFalse);
    });

    test('setelah correct, gambar tampil penuh tanpa mengubah skor', () {
      final e = engine('GITAR');
      expect(e.snapshot.displayScale, 8);
      type(e, 'GITAR');
      final s = e.snapshot;
      expect(s.displayScale, 1);
      expect(s.scale, 8);
      expect(s.score, 100);
    });

    test('zoomOut mengubah skala dan poin', () {
      final e = engine('GITAR');
      expect(e.zoomOut(), isTrue);
      expect(e.snapshot.scale, 5);
      expect(e.snapshot.score, 80);
      expect(e.snapshot.nextBasePoint, 60);
    });
  });

  group('hint buka huruf', () {
    test('mengisi kotak pertama dengan huruf benar dan menguncinya', () {
      final e = engine('PAYUNG');
      expect(e.revealLetter(), isTrue);
      final s = e.snapshot;
      expect(s.slots[0].letter, 'P');
      expect(s.slots[0].locked, isTrue);
      expect(s.score, 90);
      e.tapSlot(0);
      expect(e.snapshot.slots[0].letter, 'P');
    });

    test('mengganti huruf salah di kotak target', () {
      final e = engine('PAYUNG');
      type(e, 'AP');
      expect(e.revealLetter(), isTrue);
      expect(e.snapshot.slots[0].letter, 'P');
      expect(e.snapshot.slots[0].locked, isTrue);
      // A yang tadi di kotak 0 kembali ke papan; P diambil dari kotak 1.
      expect(e.snapshot.slots[1].letter, isNull);
    });

    test('mengambil huruf dari kotak lain yang salah tempat', () {
      final e = engine('PAPAYA'); // P ada 2
      type(e, 'AP');
      e.tapTile(tileFor(e, 'P')); // P kedua di kotak 2 (seharusnya P: benar)
      // Kotak: A P P _ _ _ ; target kotak 0 butuh P, tidak ada P bebas.
      expect(e.revealLetter(), isTrue);
      final s = e.snapshot;
      expect(s.slots[0].letter, 'P');
      expect(s.slots[2].letter, 'P');
      expect(s.slots[1].letter, isNull);
    });

    test('hint yang melengkapi jawaban langsung correct', () {
      final e = engine('GITAR');
      type(e, 'GITA');
      e.revealLetter();
      expect(e.snapshot.status, GameStatus.correct);
      expect(e.snapshot.score, 90);
    });

    test('hint terus-menerus menyelesaikan level', () {
      final e = engine('KUCING');
      while (e.revealLetter()) {}
      expect(e.snapshot.status, GameStatus.correct);
      expect(slotsText(e), 'KUCING');
    });
  });

  group('hint hapus huruf salah', () {
    test('menyembunyikan 3 pengecoh, huruf jawaban tetap ada', () {
      final e = engine('PAPAYA');
      expect(e.removeWrongLetters(), isTrue);
      final s = e.snapshot;
      final hidden = s.tiles.where((t) => t.hidden).toList();
      expect(hidden, hasLength(3));
      expect(hidden.every((t) => !'PAPAYA'.contains(t.letter)), isTrue);
      final visible = s.tiles.where((t) => !t.hidden).map((t) => t.letter);
      expect(visible.where((c) => c == 'A').length, 3);
      expect(visible.where((c) => c == 'P').length, 2);
      expect(s.score, 90);
    });

    test('mengosongkan kotak berisi pengecoh yang disembunyikan', () {
      final e = engine('GITAR');
      final decoy = e.tiles.firstWhere((t) => !'GITAR'.contains(t.letter)).id;
      e.tapTile(decoy);
      // Sembunyikan sampai pengecoh itu ikut hilang.
      while (!e.snapshot.tiles.firstWhere((t) => t.id == decoy).hidden) {
        e.removeWrongLetters();
      }
      expect(e.snapshot.slots[0].letter, isNull);
    });

    test('tanpa pengecoh tersisa: tidak ada penalti', () {
      final e = engine('KUCING'); // 8 pengecoh -> 3 + 3 + 2
      expect(e.removeWrongLetters(), isTrue);
      expect(e.removeWrongLetters(), isTrue);
      expect(e.removeWrongLetters(), isTrue);
      expect(e.snapshot.canRemoveWrong, isFalse);
      expect(e.removeWrongLetters(), isFalse);
      expect(e.snapshot.score, 70);
      expect(e.snapshot.tiles.where((t) => !t.hidden), hasLength(6));
    });

    test('huruf tersembunyi tidak bisa ditap', () {
      final e = engine('GITAR');
      e.removeWrongLetters();
      final hidden = e.snapshot.tiles.firstWhere((t) => t.hidden).id;
      e.tapTile(hidden);
      expect(slotsText(e), '_____');
    });
  });
}
