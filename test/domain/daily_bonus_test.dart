import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/domain/daily_bonus.dart';

void main() {
  final today = DateTime(2026, 11, 13, 9, 30);

  test('formatDate yyyy-MM-dd', () {
    expect(formatDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('hari pertama: bonus 20, streak 1', () {
    final o = DailyBonus.check(lastDate: null, streak: 0, today: today)!;
    expect(o.amount, 20);
    expect(o.newStreak, 1);
    expect(o.todayKey, '2026-11-13');
  });

  test('hari berurutan: streak naik dan bonus +10', () {
    final o = DailyBonus.check(
      lastDate: '2026-11-12',
      streak: 2,
      today: today,
    )!;
    expect(o.newStreak, 3);
    expect(o.amount, 40);
  });

  test('bonus maksimum 70', () {
    expect(DailyBonus.amountFor(6), 70);
    expect(DailyBonus.amountFor(20), 70);
    final o = DailyBonus.check(
      lastDate: '2026-11-12',
      streak: 9,
      today: today,
    )!;
    expect(o.amount, 70);
  });

  test('terlewat sehari: streak reset ke 1', () {
    final o = DailyBonus.check(
      lastDate: '2026-11-11',
      streak: 5,
      today: today,
    )!;
    expect(o.newStreak, 1);
    expect(o.amount, 20);
  });

  test('klaim dua kali di hari yang sama tidak boleh', () {
    expect(
      DailyBonus.check(lastDate: '2026-11-13', streak: 3, today: today),
      isNull,
    );
  });

  test('berurutan lintas bulan dan tahun', () {
    final o = DailyBonus.check(
      lastDate: '2026-12-31',
      streak: 1,
      today: DateTime(2027, 1, 1),
    )!;
    expect(o.newStreak, 2);
    expect(o.amount, 30);
  });
}
