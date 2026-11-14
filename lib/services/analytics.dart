import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pencatat event game. Default [SilentAnalytics]; main.dart meng-override
/// dengan [FirebaseGameAnalytics]. [puzzleId] = id dokumen puzzle
/// (mis. `stage_003_2`).
abstract class GameAnalytics {
  Future<void> puzzleStart(String puzzleId);
  Future<void> puzzleComplete(
    String puzzleId, {
    required int score,
    required bool firstSolve,
  });
  Future<void> stageComplete(
    int stage, {
    required int score,
    required int stars,
    required bool firstClear,
  });
  Future<void> hintUsed(String puzzleId, String hint, {required int cost});
  Future<void> dailyBonusClaimed({required int amount, required int streak});
}

final analyticsProvider = Provider<GameAnalytics>(
  (ref) => const SilentAnalytics(),
);

class SilentAnalytics implements GameAnalytics {
  const SilentAnalytics();
  @override
  Future<void> puzzleStart(String puzzleId) async {}
  @override
  Future<void> puzzleComplete(
    String puzzleId, {
    required int score,
    required bool firstSolve,
  }) async {}
  @override
  Future<void> stageComplete(
    int stage, {
    required int score,
    required int stars,
    required bool firstClear,
  }) async {}
  @override
  Future<void> hintUsed(
    String puzzleId,
    String hint, {
    required int cost,
  }) async {}
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
  Future<void> puzzleStart(String puzzleId) =>
      _fa.logLevelStart(levelName: puzzleId);

  @override
  Future<void> puzzleComplete(
    String puzzleId, {
    required int score,
    required bool firstSolve,
  }) => _fa.logLevelEnd(
    levelName: puzzleId,
    success: 1,
    parameters: {'score': score, 'first_clear': '$firstSolve'},
  );

  @override
  Future<void> stageComplete(
    int stage, {
    required int score,
    required int stars,
    required bool firstClear,
  }) => _fa.logEvent(
    name: 'stage_complete',
    parameters: {
      'stage': stage,
      'score': score,
      'stars': stars,
      'first_clear': '$firstClear',
    },
  );

  @override
  Future<void> hintUsed(String puzzleId, String hint, {required int cost}) =>
      _fa.logSpendVirtualCurrency(
        itemName: hint,
        virtualCurrencyName: 'coin',
        value: cost,
        parameters: {'level_name': puzzleId},
      );

  @override
  Future<void> dailyBonusClaimed({required int amount, required int streak}) =>
      _fa.logEarnVirtualCurrency(
        virtualCurrencyName: 'coin',
        value: amount,
        parameters: {'source': 'daily_bonus', 'streak': streak},
      );
}
