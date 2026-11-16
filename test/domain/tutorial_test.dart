import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/domain/tutorial.dart';

void main() {
  test('langkah menyorot setiap bagian tepat sekali', () {
    expect(
      kTutorialSteps.map((s) => s.target).toSet(),
      TutorialTarget.values.toSet(),
    );
    expect(kTutorialSteps.length, TutorialTarget.values.length);
  });

  test('menjelaskan cara menghapus huruf lewat kotak jawaban', () {
    final step = kTutorialSteps.firstWhere(
      (s) => s.target == TutorialTarget.answerBoxes,
    );
    expect(step.body, contains('Ketuk huruf di kotak jawaban'));
  });

  test('next maju sampai selesai, lalu tetap selesai', () {
    var p = const TutorialProgress();
    expect(p.current, kTutorialSteps.first);
    for (var i = 0; i < kTutorialSteps.length - 1; i++) {
      expect(p.isLast, isFalse);
      p = p.next();
    }
    expect(p.isLast, isTrue);
    p = p.next();
    expect(p.isFinished, isTrue);
    expect(p.current, isNull);
    expect(p.next().isFinished, isTrue);
  });

  test('skip langsung selesai', () {
    expect(const TutorialProgress().skip().isFinished, isTrue);
  });
}
