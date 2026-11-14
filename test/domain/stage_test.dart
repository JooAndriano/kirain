import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/domain/economy.dart';
import 'package:kirain/domain/stage.dart';

import '../support/fakes.dart';

void main() {
  group('buildStages', () {
    test('urut stage lalu slot walau input acak', () {
      final input = fullStages(2).reversed.toList();
      final stages = buildStages(input);
      expect(stages.map((s) => s.number), [1, 2]);
      expect(stages[0].puzzles.map((p) => p.slot), [1, 2, 3]);
      expect(stages[1].puzzleAt(3)!.id, 'stage_002_3');
    });

    test('stage tidak lengkap disembunyikan dan dicatat', () {
      final logs = <String>[];
      final input = [
        ...fullStages(1),
        puzzle(2, 1),
        puzzle(2, 2), // slot 3 hilang
      ];
      final stages = buildStages(input, log: logs.add);
      expect(stages.map((s) => s.number), [1]);
      expect(logs.any((l) => l.contains('Stage 2')), isTrue);
    });

    test('slot ganda atau di luar 1..3 -> stage disembunyikan', () {
      final dup = [puzzle(1, 1), puzzle(1, 2), puzzle(1, 2, id: 'lain')];
      expect(buildStages(dup), isEmpty);
      final four = [...fullStages(1), puzzle(1, 4)];
      expect(buildStages(four), isEmpty);
      final wrong = [puzzle(1, 1), puzzle(1, 2), puzzle(1, 4)];
      expect(buildStages(wrong), isEmpty);
    });

    test('celah nomor stage: stage setelah celah tidak ditampilkan', () {
      final logs = <String>[];
      final input = [
        ...fullStages(2),
        for (var slot = 1; slot <= 3; slot++) puzzle(4, slot),
      ];
      final stages = buildStages(input, log: logs.add);
      expect(stages.map((s) => s.number), [1, 2]);
      expect(logs.any((l) => l.contains('[4]')), isTrue);
    });

    test('stage tidak lengkap di tengah juga membuat celah', () {
      final input = [
        ...fullStages(3).where((p) => !(p.stage == 2 && p.slot == 2)),
      ];
      expect(buildStages(input).map((s) => s.number), [1]);
    });

    test('stage 1 tidak lengkap -> semua stage tersembunyi', () {
      final input = [puzzle(1, 1), ...fullStages(3).skip(3)];
      expect(buildStages(input), isEmpty);
    });

    test('puzzle tidak valid membuat stage-nya tidak lengkap', () {
      final input = [puzzle(1, 1), puzzle(1, 2), puzzle(1, 3, answer: 'A1')];
      expect(buildStages(input), isEmpty);
    });
  });

  group('continueTarget', () {
    final stages = buildStages(fullStages(3));

    test('inProgress -> stage itu, slot pertama yang belum benar', () {
      final p = Progress(
        coins: 0,
        highestUnlockedStage: 3,
        inProgress: StageRun(stage: 2, solved: {1: 80}),
      );
      expect(continueTarget(stages, p), (stage: 2, slot: 2));
      expect(resumeSlot(p, 2), 2);
      expect(resumeSlot(p, 1), 1);
    });

    test('tanpa inProgress -> stage terbuka tertinggi, slot 1', () {
      final p = Progress(coins: 0, highestUnlockedStage: 3);
      expect(continueTarget(stages, p), (stage: 3, slot: 1));
    });

    test('progress menunjuk stage yang tidak ada -> tidak crash', () {
      final p = Progress(
        coins: 0,
        highestUnlockedStage: 99,
        inProgress: StageRun(stage: 50, solved: {1: 10}),
      );
      expect(continueTarget(stages, p), (stage: 3, slot: 1));
    });

    test('daftar kosong -> null', () {
      expect(continueTarget(const [], Progress.initial()), isNull);
    });
  });

  test('ambang bintang stage', () {
    expect(Economy.stageStars(300), 3);
    expect(Economy.stageStars(210), 3);
    expect(Economy.stageStars(209), 2);
    expect(Economy.stageStars(120), 2);
    expect(Economy.stageStars(119), 1);
    expect(Economy.stageStars(30), 1);
    expect(Economy.stageClearBonusCoins, 15);
  });
}
