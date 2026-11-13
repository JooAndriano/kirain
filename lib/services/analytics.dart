import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pencatat event game. Default [SilentAnalytics]; main.dart meng-override
/// dengan [FirebaseGameAnalytics].
abstract class GameAnalytics {
  Future<void> levelStart(int levelId);
  Future<void> levelComplete(
    int levelId, {
    required int score,
    required int stars,
    required bool firstClear,
  });
  Future<void> hintUsed(int levelId, String hint, {required int cost});
  Future<void> dailyBonusClaimed({required int amount, required int streak});
}

final analyticsProvider = Provider<GameAnalytics>(
  (ref) => const SilentAnalytics(),
);

class SilentAnalytics implements GameAnalytics {
  const SilentAnalytics();
  @override
  Future<void> levelStart(int levelId) async {}
  @override
  Future<void> levelComplete(
    int levelId, {
    required int score,
    required int stars,
    required bool firstClear,
  }) async {}
  @override
  Future<void> hintUsed(int levelId, String hint, {required int cost}) async {}
  @override
  Future<void> dailyBonusClaimed({
    required int amount,
    required int streak,
  }) async {}
}

class FirebaseGameAnalytics implements GameAnalytics {
  FirebaseGameAnalytics([FirebaseAnalytics? fa])
    : _fa = fa ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _fa;

  @override
  Future<void> levelStart(int levelId) =>
      _fa.logLevelStart(levelName: 'level_$levelId');

  @override
  Future<void> levelComplete(
    int levelId, {
    required int score,
    required int stars,
    required bool firstClear,
  }) => _fa.logLevelEnd(
    levelName: 'level_$levelId',
    success: 1,
    parameters: {'score': score, 'stars': stars, 'first_clear': '$firstClear'},
  );

  @override
  Future<void> hintUsed(int levelId, String hint, {required int cost}) =>
      _fa.logSpendVirtualCurrency(
        itemName: hint,
        virtualCurrencyName: 'coin',
        value: cost,
        parameters: {'level_name': 'level_$levelId'},
      );

  @override
  Future<void> dailyBonusClaimed({required int amount, required int streak}) =>
      _fa.logEarnVirtualCurrency(
        virtualCurrencyName: 'coin',
        value: amount,
        parameters: {'source': 'daily_bonus', 'streak': streak},
      );
}
