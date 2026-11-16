/// Bagian layar permainan yang disorot oleh satu langkah tutorial.
enum TutorialTarget {
  image,
  zoomOut,
  letterBoard,
  answerBoxes,
  revealLetter,
  removeWrong,
  coins,
}

/// Satu langkah tutorial: bagian yang disorot dan penjelasannya.
class TutorialStep {
  const TutorialStep({
    required this.target,
    required this.title,
    required this.body,
  });

  final TutorialTarget target;
  final String title;
  final String body;
}

/// Urutan langkah tutorial cara bermain.
const List<TutorialStep> kTutorialSteps = [
  TutorialStep(
    target: TutorialTarget.image,
    title: 'Tebak gambarnya',
    body:
        'Gambar dimulai dari jarak sangat dekat. '
        'Tebak benda apa yang ada di gambar ini!',
  ),
  TutorialStep(
    target: TutorialTarget.zoomOut,
    title: 'Zoom Out',
    body:
        'Belum tertebak? Tekan Zoom Out untuk melihat gambar lebih luas. '
        'Gratis, tapi poin yang bisa didapat berkurang.',
  ),
  TutorialStep(
    target: TutorialTarget.letterBoard,
    title: 'Pilih huruf',
    body: 'Ketuk huruf di papan ini untuk mengisi kotak jawaban.',
  ),
  TutorialStep(
    target: TutorialTarget.answerBoxes,
    title: 'Salah pilih huruf?',
    body:
        'Ketuk huruf di kotak jawaban untuk menghapusnya. '
        'Huruf itu kembali ke papan dan bisa dipilih lagi.',
  ),
  TutorialStep(
    target: TutorialTarget.revealLetter,
    title: 'Buka Huruf',
    body:
        'Butuh bantuan? Buka satu huruf yang benar memakai koin. '
        'Huruf yang dibuka terkunci dan tidak bisa dihapus.',
  ),
  TutorialStep(
    target: TutorialTarget.removeWrong,
    title: 'Hilangkan Huruf Salah',
    body:
        'Menghilangkan huruf pengecoh dari papan huruf agar pilihan lebih '
        'sedikit. Untuk menghapus huruf di kotak jawaban, cukup ketuk '
        'kotaknya.',
  ),
  TutorialStep(
    target: TutorialTarget.coins,
    title: 'Koin',
    body:
        'Koin didapat dari tebakan benar dan stage yang selesai. '
        'Kurang koin? Ketuk koin ini untuk ke Toko.',
  ),
];

/// Posisi pemain di dalam tutorial. Immutable.
class TutorialProgress {
  const TutorialProgress({this.steps = kTutorialSteps, this.index = 0})
    : assert(index >= 0);

  final List<TutorialStep> steps;
  final int index;

  bool get isFinished => index >= steps.length;
  bool get isLast => index == steps.length - 1;
  TutorialStep? get current => isFinished ? null : steps[index];

  /// Langkah berikutnya; setelah langkah terakhir menjadi selesai.
  TutorialProgress next() =>
      TutorialProgress(steps: steps, index: isFinished ? index : index + 1);

  TutorialProgress skip() =>
      TutorialProgress(steps: steps, index: steps.length);
}
