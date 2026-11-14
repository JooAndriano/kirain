class Level {
  const Level({
    required this.id,
    required this.imageFile,
    required this.answer,
    required this.focusX,
    required this.focusY,
    this.packId = '',
    this.order = 0,
    this.difficulty = 1,
    this.active = true,
    this.isLocal = false,
  });

  /// Bentuk dokumen Firestore koleksi `levels`. Field hilang atau bertipe
  /// salah diganti nilai default yang aman (tidak melempar).
  ///
  /// Di Firestore `focusX`/`focusY` memakai rentang -1..1 (0 = tengah, gaya
  /// `Alignment`); di model dikonversi ke 0..1.
  factory Level.fromFirestore(Map<String, dynamic> map) {
    final id = _int(map['id'], 0);
    return Level(
      id: id,
      imageFile: _string(map['imageFile']).trim(),
      answer: _string(
        map['answer'],
      ).toUpperCase().replaceAll(RegExp(r'\s'), ''),
      focusX: _focusFromRemote(map['focusX']),
      focusY: _focusFromRemote(map['focusY']),
      packId: _string(map['packId']).trim(),
      order: _int(map['order'], id),
      difficulty: _int(map['difficulty'], 1),
      active: map['active'] is bool ? map['active'] as bool : false,
    );
  }

  final int id;

  /// Nama file gambar saja (mis. `kucing.webp`), bukan URL atau path.
  final String imageFile;

  /// Huruf besar tanpa spasi.
  final String answer;

  /// Titik fokus zoom, 0..1 dari kiri/atas gambar (0.5 = tengah).
  final double focusX;
  final double focusY;

  final String packId;

  /// Urutan tampil di dalam daftar level.
  final int order;
  final int difficulty;
  final bool active;

  /// true untuk level dummy bawaan app (gambar dari aset lokal).
  final bool isLocal;

  /// Bentuk dokumen Firestore (fokus dalam -1..1). [isLocal] tidak disimpan.
  Map<String, dynamic> toMap() => {
    'id': id,
    'imageFile': imageFile,
    'answer': answer,
    'focusX': focusX * 2 - 1,
    'focusY': focusY * 2 - 1,
    'packId': packId,
    'order': order,
    'difficulty': difficulty,
    'active': active,
  };

  static String _string(Object? v) => v is String ? v : '';

  static int _int(Object? v, int fallback) =>
      v is num && v.isFinite ? v.toInt() : fallback;

  /// Firestore -1..1 -> model 0..1; di luar rentang dijepit,
  /// hilang/rusak -> tengah (0.5).
  static double _focusFromRemote(Object? v) =>
      v is num && v.isFinite ? (v.toDouble().clamp(-1.0, 1.0) + 1) / 2 : 0.5;
}
