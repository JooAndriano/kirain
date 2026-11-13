/// Harga dan hadiah koin.
abstract final class Economy {
  /// Hint: buka satu huruf yang benar.
  static const int revealLetterCost = 30;

  /// Hint: hapus huruf pengecoh.
  static const int removeWrongCost = 20;

  /// Zoom Out GRATIS; hanya mengurangi poin (lihat ScoreEngine).
  static const int zoomOutCost = 0;

  /// Hadiah menonton iklan di Toko.
  static const int adReward = 25;
}
