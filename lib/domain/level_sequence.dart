import '../data/level.dart';
import 'game_engine.dart';

/// Navigasi antar level berdasarkan [Level.order]. Dart murni.
///
/// Semua fungsi menerima daftar yang belum tentu terurut dan aman terhadap
/// order yang tidak ada di daftar (mis. progress lama menunjuk level yang
/// sudah dihapus).

final _answerPattern = RegExp(r'^[A-Z]+$');

/// Level yang bisa dimainkan: order > 0, ada gambar, jawaban huruf A-Z yang
/// muat di papan. Order ganda -> yang pertama dipakai. Hasil terurut order.
List<Level> playableLevels(Iterable<Level> levels) {
  final byOrder = <int, Level>{};
  for (final l in levels) {
    if (l.order <= 0 || l.imageFile.isEmpty) continue;
    if (!_answerPattern.hasMatch(l.answer)) continue;
    if (l.answer.length > GameEngine.defaultTileCount) continue;
    byOrder.putIfAbsent(l.order, () => l);
  }
  return byOrder.values.toList()..sort((a, b) => a.order.compareTo(b.order));
}

/// Level dengan [order] tersebut, atau null jika tidak ada.
Level? levelByOrder(List<Level> levels, int order) {
  for (final l in levels) {
    if (l.order == order) return l;
  }
  return null;
}

/// Order terkecil yang lebih besar dari [order], atau null jika tidak ada
/// (berarti [order] adalah level terakhir).
int? nextOrder(List<Level> levels, int order) {
  int? best;
  for (final l in levels) {
    if (l.order > order && (best == null || l.order < best)) best = l.order;
  }
  return best;
}

/// Level untuk tombol "Lanjutkan": order terbesar yang <= [highestUnlocked].
/// Jika tidak ada (progress menunjuk di bawah semua level), level pertama.
/// Daftar kosong -> null.
Level? continueLevel(List<Level> levels, int highestUnlocked) {
  Level? best;
  Level? first;
  for (final l in levels) {
    if (first == null || l.order < first.order) first = l;
    if (l.order <= highestUnlocked && (best == null || l.order > best.order)) {
      best = l;
    }
  }
  return best ?? first;
}
