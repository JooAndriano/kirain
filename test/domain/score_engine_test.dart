import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/domain/score_engine.dart';

void main() {
  group('ScoreEngine', () {
    test('nilai awal', () {
      final e = ScoreEngine();
      expect(e.scale, 8);
      expect(e.score, 100);
      expect(e.stars, 3);
      expect(e.coins, 10);
      expect(e.nextBasePoint, 80);
    });

    test('zoomOut manual melewati semua tingkat lalu berhenti', () {
      final e = ScoreEngine();
      final scales = <double>[e.scale];
      final points = <int>[e.score];
      while (e.zoomOut()) {
        scales.add(e.scale);
        points.add(e.score);
      }
      expect(scales, [8, 5, 3, 2, 1]);
      expect(points, [100, 80, 60, 40, 20]);
      expect(e.canZoomOut, isFalse);
      expect(e.nextBasePoint, isNull);
      expect(e.zoomOut(), isFalse);
      expect(e.scale, 1);
    });

    test('penalti salah -5 dan hint -10', () {
      final e = ScoreEngine()
        ..addWrong()
        ..addWrong()
        ..addHint();
      expect(e.score, 100 - 10 - 10);
    });

    test('poin minimum 10', () {
      final e = ScoreEngine();
      while (e.zoomOut()) {}
      e
        ..addHint()
        ..addHint();
      expect(e.score, 10);
      expect(e.stars, 1);
      expect(e.coins, 1);
    });

    test('batas bintang', () {
      ScoreEngine at(int target) {
        // 100 - 5*n untuk mendapatkan skor tertentu
        final e = ScoreEngine();
        for (var i = 0; i < (100 - target) ~/ 5; i++) {
          e.addWrong();
        }
        expect(e.score, target);
        return e;
      }

      expect(at(70).stars, 3);
      expect(at(65).stars, 2);
      expect(at(40).stars, 2);
      expect(at(35).stars, 1);
    });

    test('scoreAfterZoomOut memperhitungkan penalti dan lantai', () {
      final e = ScoreEngine()..addWrong(); // 95
      expect(e.scoreAfterZoomOut, 75);
      while (e.zoomOut()) {}
      expect(e.scoreAfterZoomOut, isNull);
      final f = ScoreEngine();
      f
        ..zoomOut()
        ..zoomOut()
        ..addHint()
        ..addHint()
        ..addHint(); // 60-30 = 30 -> zoom: 10
      expect(f.scoreAfterZoomOut, 10);
    });

    test('koin = score ~/ 10', () {
      final e = ScoreEngine()..addWrong(); // 95
      expect(e.coins, 9);
    });
  });
}
