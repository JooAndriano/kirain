/// Satu gambar tebakan. Tiga puzzle dengan [stage] yang sama (slot 1..3)
/// membentuk satu stage.
class Puzzle {
  const Puzzle({
    required this.id,
    required this.stage,
    required this.slot,
    required this.imageFile,
    required this.answer,
    required this.focusX,
    required this.focusY,
    this.packId = '',
    this.difficulty = 1,
    this.active = true,
    this.isLocal = false,
  });

  /// Bentuk dokumen Firestore koleksi `puzzles`. [docId] (mis. `stage_003_2`)
  /// menjadi [id]. Field hilang atau bertipe salah diganti nilai default yang
  /// aman (tidak melempar).
  ///
  /// Di Firestore `focusX`/`focusY` memakai rentang -1..1 (0 = tengah, gaya
  /// `Alignment`); di model dikonversi ke 0..1.
  factory Puzzle.fromFirestore(String docId, Map<String, dynamic> map) {
    return Puzzle(
      id: docId,
      stage: _int(map['stage'], 0),
      slot: _int(map['slot'], 0),
      imageFile: _string(map['imageFile']).trim(),
      answer: _string(
        map['answer'],
      ).toUpperCase().replaceAll(RegExp(r'\s'), ''),
      focusX: _focusFromRemote(map['focusX']),
      focusY: _focusFromRemote(map['focusY']),
      packId: _string(map['packId']).trim(),
      difficulty: _int(map['difficulty'], 1),
      active: map['active'] is bool ? map['active'] as bool : false,
    );
  }

  /// Kebalikan [toMap] (dipakai cache lokal).
  factory Puzzle.fromMap(Map<String, dynamic> map) =>
      Puzzle.fromFirestore(_string(map['id']), map);

  /// Id dokumen Firestore; kunci [clearedPuzzleIds] di progress.
  final String id;

  /// Nomor stage (1..).
  final int stage;

  /// Urutan di dalam stage (1..3).
  final int slot;

  /// Nama file gambar saja (mis. `kucing_1.webp`), bukan URL atau path.
  final String imageFile;

  /// Huruf besar tanpa spasi.
  final String answer;

  /// Titik fokus zoom, 0..1 dari kiri/atas gambar (0.5 = tengah).
  final double focusX;
  final double focusY;

  final String packId;
  final int difficulty;
  final bool active;

  /// true untuk puzzle dummy bawaan app (gambar dari aset lokal).
  final bool isLocal;

  /// Bentuk dokumen Firestore (fokus dalam -1..1) ditambah [id].
  /// [isLocal] tidak disimpan.
  Map<String, dynamic> toMap() => {
    'id': id,
    'stage': stage,
    'slot': slot,
    'imageFile': imageFile,
    'answer': answer,
    'focusX': focusX * 2 - 1,
    'focusY': focusY * 2 - 1,
    'packId': packId,
    'difficulty': difficulty,
    'active': active,
  };

  @override
  String toString() => 'Puzzle($id, stage $stage slot $slot, $answer)';

  static String _string(Object? v) => v is String ? v : '';

  static int _int(Object? v, int fallback) =>
      v is num && v.isFinite ? v.toInt() : fallback;

  /// Firestore -1..1 -> model 0..1; di luar rentang dijepit,
  /// hilang/rusak -> tengah (0.5).
  static double _focusFromRemote(Object? v) =>
      v is num && v.isFinite ? (v.toDouble().clamp(-1.0, 1.0) + 1) / 2 : 0.5;
}
