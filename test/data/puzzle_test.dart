import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/dummy_puzzles.dart';
import 'package:kirain/data/puzzle.dart';
import 'package:kirain/domain/stage.dart';

void main() {
  group('Puzzle.fromFirestore', () {
    test('membaca dokumen lengkap, id dari doc id', () {
      final p = Puzzle.fromFirestore('stage_003_2', {
        'stage': 3,
        'slot': 2,
        'imageFile': ' kucing_3.webp ',
        'answer': 'ku cing',
        'focusX': -0.5,
        'focusY': 0.5,
        'packId': 'hewan',
        'difficulty': 2,
        'active': true,
      });
      expect(p.id, 'stage_003_2');
      expect(p.stage, 3);
      expect(p.slot, 2);
      expect(p.imageFile, 'kucing_3.webp');
      expect(p.answer, 'KUCING');
      expect(p.focusX, 0.25);
      expect(p.focusY, 0.75);
      expect(p.packId, 'hewan');
      expect(p.difficulty, 2);
      expect(p.active, isTrue);
      expect(p.isLocal, isFalse);
    });

    test('field hilang atau tipe salah -> default aman, tidak melempar', () {
      final p = Puzzle.fromFirestore('x', {
        'stage': '3',
        'slot': null,
        'imageFile': 1,
        'focusX': 9,
        'active': 'true',
      });
      expect(p.stage, 0);
      expect(p.slot, 0);
      expect(p.imageFile, '');
      expect(p.focusX, 1.0); // dijepit
      expect(p.focusY, 0.5);
      expect(p.active, isFalse);
    });

    test('toMap -> fromMap bolak-balik', () {
      final p = Puzzle.fromFirestore('stage_001_1', {
        'stage': 1,
        'slot': 1,
        'imageFile': 'a.webp',
        'answer': 'GAJAH',
        'focusX': 0.2,
        'focusY': -0.4,
        'packId': 'hewan',
        'difficulty': 2,
        'active': true,
      });
      final back = Puzzle.fromMap(p.toMap());
      expect(back.toMap(), p.toMap());
      expect(back.id, 'stage_001_1');
    });
  });

  test('dummy: minimal 2 stage lengkap x 3 gambar, semua aset lokal', () {
    final stages = buildStages(dummyPuzzles);
    expect(stages.length, greaterThanOrEqualTo(2));
    expect(dummyPuzzles.every((p) => p.isLocal), isTrue);
    expect(dummyPuzzles.map((p) => p.id).toSet().length, dummyPuzzles.length);
    for (final s in stages) {
      expect(s.puzzles.map((p) => p.answer).toSet().length, 3);
    }
  });
}
