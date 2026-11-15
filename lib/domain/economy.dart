/// Harga dan hadiah koin.
abstract final class Economy {
  /// Hint: buka satu huruf yang benar.
  static const int revealLetterCost = 30;

  /// Hint: hapus huruf pengecoh.
  static const int removeWrongCost = 20;

  /// Zoom Out GRATIS; hanya mengurangi poin (lihat ScoreEngine).
  static const int zoomOutCost = 0;

  /// Bonus saat sebuah stage pertama kali tuntas.
  static const int stageClearBonusCoins = 15;

  /// Ambang bintang stage berdasarkan skor total 3 gambar (maks. 300).
  static const int stageThreeStars = 210;
  static const int stageTwoStars = 120;

  static int stageStars(int totalScore) {
    if (totalScore >= stageThreeStars) return 3;
    if (totalScore >= stageTwoStars) return 2;
    return 1;
  }
}
