import 'dart:math';

/// Format tanggal lokal menjadi yyyy-MM-dd.
String formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Bonus harian yang bisa diklaim hari ini.
class DailyBonusOffer {
  const DailyBonusOffer({
    required this.amount,
    required this.newStreak,
    required this.todayKey,
  });

  final int amount;
  final int newStreak;

  /// Tanggal hari ini (yyyy-MM-dd) yang disimpan setelah klaim.
  final String todayKey;
}

abstract final class DailyBonus {
  static const int base = 20;
  static const int step = 10;
  static const int max = 70;

  static int amountFor(int streak) =>
      min(base + step * (streak - 1), DailyBonus.max);

  /// Mengembalikan bonus yang tersedia, atau null jika hari ini sudah diklaim.
  /// [today] dikirim dari luar agar mudah dites.
  static DailyBonusOffer? check({
    required String? lastDate,
    required int streak,
    required DateTime today,
  }) {
    final todayKey = formatDate(today);
    if (lastDate == todayKey) return null;

    var newStreak = 1;
    final last = _parse(lastDate);
    if (last != null) {
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      final diff = todayUtc.difference(last).inDays;
      if (diff == 1) newStreak = streak + 1;
    }
    return DailyBonusOffer(
      amount: amountFor(newStreak),
      newStreak: newStreak,
      todayKey: todayKey,
    );
  }

  static DateTime? _parse(String? s) {
    if (s == null) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }
}
