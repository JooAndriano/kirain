/// Menghitung poin satu gambar berdasarkan tingkat zoom, jawaban salah,
/// dan pemakaian hint. Zoom-out dilakukan manual oleh pemain.
class ScoreEngine {
  static const List<double> scales = [8, 5, 3, 2, 1];
  static const List<int> basePoints = [100, 80, 60, 40, 20];
  static const int wrongPenalty = 5;
  static const int hintPenalty = 10;
  static const int minScore = 10;

  int _zoomIndex = 0;
  int _wrongCount = 0;
  int _hintCount = 0;

  int get zoomIndex => _zoomIndex;
  int get wrongCount => _wrongCount;
  int get hintCount => _hintCount;

  bool get canZoomOut => _zoomIndex < scales.length - 1;

  /// Mundur satu tingkat zoom. Mengembalikan false jika sudah paling jauh.
  bool zoomOut() {
    if (!canZoomOut) return false;
    _zoomIndex++;
    return true;
  }

  void addWrong() => _wrongCount++;
  void addHint() => _hintCount++;

  double get scale => scales[_zoomIndex];
  int get basePoint => basePoints[_zoomIndex];

  /// Poin dasar setelah zoom-out berikutnya, atau null jika tidak bisa zoom.
  int? get nextBasePoint => canZoomOut ? basePoints[_zoomIndex + 1] : null;

  /// Skor jika pemain zoom-out sekarang, atau null jika tidak bisa zoom.
  int? get scoreAfterZoomOut {
    final next = nextBasePoint;
    if (next == null) return null;
    final raw = score - (basePoint - next);
    return raw < minScore ? minScore : raw;
  }

  int get score {
    final raw =
        basePoint - wrongPenalty * _wrongCount - hintPenalty * _hintCount;
    return raw < minScore ? minScore : raw;
  }

  int get stars {
    final s = score;
    if (s >= 70) return 3;
    if (s >= 40) return 2;
    return 1;
  }

  int get coins => score ~/ 10;
}
