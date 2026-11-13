/// Progress pemain yang disimpan lokal. Immutable.
class Progress {
  Progress({
    required this.coins,
    required this.highestUnlockedLevel,
    Map<int, int> starsPerLevel = const {},
    Map<int, int> bestScorePerLevel = const {},
    this.lastDailyBonusDate,
    this.dailyStreak = 0,
  }) : starsPerLevel = Map.unmodifiable(starsPerLevel),
       bestScorePerLevel = Map.unmodifiable(bestScorePerLevel);

  factory Progress.initial() =>
      Progress(coins: initialCoins, highestUnlockedLevel: 1);

  static const int initialCoins = 50;

  final int coins;
  final int highestUnlockedLevel;
  final Map<int, int> starsPerLevel;
  final Map<int, int> bestScorePerLevel;

  /// Format yyyy-MM-dd, null jika belum pernah klaim.
  final String? lastDailyBonusDate;
  final int dailyStreak;

  Progress copyWith({
    int? coins,
    int? highestUnlockedLevel,
    Map<int, int>? starsPerLevel,
    Map<int, int>? bestScorePerLevel,
    String? lastDailyBonusDate,
    int? dailyStreak,
  }) {
    return Progress(
      coins: coins ?? this.coins,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      starsPerLevel: starsPerLevel ?? this.starsPerLevel,
      bestScorePerLevel: bestScorePerLevel ?? this.bestScorePerLevel,
      lastDailyBonusDate: lastDailyBonusDate ?? this.lastDailyBonusDate,
      dailyStreak: dailyStreak ?? this.dailyStreak,
    );
  }

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'highestUnlockedLevel': highestUnlockedLevel,
    'starsPerLevel': _encodeMap(starsPerLevel),
    'bestScorePerLevel': _encodeMap(bestScorePerLevel),
    'lastDailyBonusDate': lastDailyBonusDate,
    'dailyStreak': dailyStreak,
  };

  factory Progress.fromJson(Map<String, dynamic> json) {
    final initial = Progress.initial();
    return Progress(
      coins: (json['coins'] as num?)?.toInt() ?? initial.coins,
      highestUnlockedLevel:
          (json['highestUnlockedLevel'] as num?)?.toInt() ??
          initial.highestUnlockedLevel,
      starsPerLevel: _decodeMap(json['starsPerLevel']),
      bestScorePerLevel: _decodeMap(json['bestScorePerLevel']),
      lastDailyBonusDate: json['lastDailyBonusDate'] as String?,
      dailyStreak: (json['dailyStreak'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, int> _encodeMap(Map<int, int> m) => {
    for (final e in m.entries) '${e.key}': e.value,
  };

  static Map<int, int> _decodeMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        int.parse(e.key as String): (e.value as num).toInt(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      other.coins == coins &&
      other.highestUnlockedLevel == highestUnlockedLevel &&
      _mapEquals(other.starsPerLevel, starsPerLevel) &&
      _mapEquals(other.bestScorePerLevel, bestScorePerLevel) &&
      other.lastDailyBonusDate == lastDailyBonusDate &&
      other.dailyStreak == dailyStreak;

  @override
  int get hashCode => Object.hash(
    coins,
    highestUnlockedLevel,
    Object.hashAllUnordered(
      starsPerLevel.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      bestScorePerLevel.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    lastDailyBonusDate,
    dailyStreak,
  );

  static bool _mapEquals(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  String toString() => 'Progress(${toJson()})';
}
