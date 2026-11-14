import '../data/progress.dart';
import '../data/puzzle.dart';
import 'game_engine.dart';

/// Satu stage = tepat [Stage.puzzleCount] puzzle, urut slot 1..3. Dart murni.
class Stage {
  Stage({
    required this.number,
    required this.packId,
    required List<Puzzle> puzzles,
  }) : assert(puzzles.length == puzzleCount),
       puzzles = List.unmodifiable(puzzles);

  static const int puzzleCount = 3;

  final int number;
  final String packId;

  /// Index 0 = slot 1.
  final List<Puzzle> puzzles;

  /// Puzzle untuk [slot] (1..3), null jika di luar rentang.
  Puzzle? puzzleAt(int slot) =>
      slot >= 1 && slot <= puzzles.length ? puzzles[slot - 1] : null;
}

final _answerPattern = RegExp(r'^[A-Z]+$');

bool _playable(Puzzle p) =>
    p.stage > 0 &&
    p.slot > 0 &&
    p.imageFile.isNotEmpty &&
    _answerPattern.hasMatch(p.answer) &&
    p.answer.length <= GameEngine.defaultTileCount;

/// Menyusun daftar [Stage] dari daftar puzzle (urutan bebas).
///
/// - Puzzle tidak valid (jawaban bukan A-Z / terlalu panjang, tanpa gambar,
///   stage/slot <= 0) dibuang.
/// - Stage hanya ditampilkan jika punya slot 1, 2, 3 lengkap dan unik.
///   Stage tidak lengkap dilewati dan dicatat lewat [log].
/// - Nomor stage harus berurutan mulai 1 tanpa celah: stage setelah celah
///   pertama tidak ditampilkan (dicatat lewat [log]).
List<Stage> buildStages(
  Iterable<Puzzle> puzzles, {
  void Function(String message)? log,
}) {
  final byStage = <int, List<Puzzle>>{};
  for (final p in puzzles) {
    if (!_playable(p)) {
      log?.call('Puzzle ${p.id} dilewati: data tidak valid ($p)');
      continue;
    }
    byStage.putIfAbsent(p.stage, () => []).add(p);
  }

  final complete = <int, Stage>{};
  for (final entry in byStage.entries) {
    final list = [...entry.value]..sort((a, b) => a.slot.compareTo(b.slot));
    final slots = list.map((p) => p.slot).toList();
    final ok =
        list.length == Stage.puzzleCount &&
        slots.join(',') ==
            List.generate(Stage.puzzleCount, (i) => i + 1).join(',');
    if (!ok) {
      log?.call(
        'Stage ${entry.key} dilewati: slot harus tepat 1,2,3 unik, '
        'ditemukan $slots',
      );
      continue;
    }
    complete[entry.key] = Stage(
      number: entry.key,
      packId: list.first.packId,
      puzzles: list,
    );
  }

  final result = <Stage>[];
  for (var n = 1; complete.containsKey(n); n++) {
    result.add(complete[n]!);
  }
  final hidden = complete.keys.where((n) => n > result.length).toList()..sort();
  if (hidden.isNotEmpty) {
    log?.call(
      'Stage $hidden disembunyikan: ada celah setelah stage ${result.length}',
    );
  }
  return result;
}

/// Stage dengan [number], atau null.
Stage? stageByNumber(List<Stage> stages, int number) {
  for (final s in stages) {
    if (s.number == number) return s;
  }
  return null;
}

/// Nomor stage setelah [number], atau null jika [number] stage terakhir.
int? nextStageNumber(List<Stage> stages, int number) {
  int? best;
  for (final s in stages) {
    if (s.number > number && (best == null || s.number < best)) best = s.number;
  }
  return best;
}

/// Slot pertama (1..3) yang belum diselesaikan pada [stage] menurut
/// [Progress.inProgress]; 1 jika stage itu tidak sedang dimainkan.
int resumeSlot(Progress p, int stage) {
  final run = p.inProgress;
  if (run == null || run.stage != stage) return 1;
  for (var slot = 1; slot <= Stage.puzzleCount; slot++) {
    if (!run.solved.containsKey(slot)) return slot;
  }
  return 1;
}

/// Tujuan tombol "Lanjutkan".
typedef PlayTarget = ({int stage, int slot});

/// Stage/gambar untuk tombol "Lanjutkan":
/// 1. stage di [Progress.inProgress] jika masih ada, di slot yang belum selesai;
/// 2. stage terbuka tertinggi yang ada (<= highestUnlockedStage);
/// 3. stage pertama. Daftar kosong -> null.
PlayTarget? continueTarget(List<Stage> stages, Progress p) {
  if (stages.isEmpty) return null;
  final run = p.inProgress;
  if (run != null && stageByNumber(stages, run.stage) != null) {
    return (stage: run.stage, slot: resumeSlot(p, run.stage));
  }
  Stage? best;
  var first = stages.first;
  for (final s in stages) {
    if (s.number < first.number) first = s;
    if (s.number <= p.highestUnlockedStage &&
        (best == null || s.number > best.number)) {
      best = s;
    }
  }
  final target = best ?? first;
  return (stage: target.number, slot: resumeSlot(p, target.number));
}
