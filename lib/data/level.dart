class Level {
  const Level({
    required this.id,
    required this.imagePath,
    required this.answer,
    required this.focusX,
    required this.focusY,
  });

  final int id;
  final String imagePath;

  /// Huruf besar tanpa spasi.
  final String answer;

  /// Titik fokus zoom, 0..1 dari kiri/atas gambar.
  final double focusX;
  final double focusY;
}
