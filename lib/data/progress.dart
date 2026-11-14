/// Stage yang sedang dimainkan tapi belum tuntas, agar pemain bisa lanjut
/// setelah keluar di tengah stage. Immutable.
class StageRun {
  StageRun({required this.stage, Map<int, int> solved = const {}})
    : solved = Map.unmodifiable(solved);

  final int stage;

  /// slot (1..3) -> skor gambar yang sudah benar.
  final Map<int, int> solved;

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'solved': Progress._encodeMap(solved),
  };

  static StageRun? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final stage = raw['stage'];
    if (stage is! num) return null;
    return StageRun(
      stage: stage.toInt(),
      solved: Progress._decodeMap(raw['solved']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StageRun &&
      other.stage == stage &&
      Progress._mapEquals(other.solved, solved);

  @override
  int get hashCode => Object.hash(stage, Progress._mapHash(solved));

  @override
  String toString() => 'StageRun(${toJson()})';
}

/// Progress pemain yang disimpan lokal. Immutable.
class Progress {
  Progress({
    required this.coins,
    required this.highestUnlockedStage,
    Map<int, int> stageStars = const {},
    Map<int, int> stageBestScore = const {},
    Set<String> clearedPuzzleIds = const {},
    this.inProgress,
    this.lastDailyBonusDate,
    this.dailyStreak = 0,
  }) : stageStars = Map.unmodifiable(stageStars),
       stageBestScore = Map.unmodifiable(stageBestScore),
       clearedPuzzleIds = Set.unmodifiable(clearedPuzzleIds);

  factory Progress.initial() =>
      Progress(coins: initialCoins, highestUnlockedStage: 1);

  static const int initialCoins = 50;

  /// Versi format JSON. Data dengan versi lain diabaikan (reset ke default).
  static const int schemaVersion = 2;

  final int coins;
  final int highestUnlockedStage;

  /// Bintang terbaik per stage (1..3). Ada key = stage pernah tuntas.
  final Map<int, int> stageStars;

  /// Skor total terbaik per stage.
  final Map<int, int> stageBestScore;

  /// Puzzle yang sudah pernah benar; koin gambar hanya diberikan sekali.
  final Set<String> clearedPuzzleIds;

  /// null jika tidak ada stage yang sedang dimainkan.
  final StageRun? inProgress;

  /// Format yyyy-MM-dd, null jika belum pernah klaim.
  final String? lastDailyBonusDate;
  final int dailyStreak;

  Progress copyWith({
    int? coins,
    int? highestUnlockedStage,
    Map<int, int>? stageStars,
    Map<int, int>? stageBestScore,
    Set<String>? clearedPuzzleIds,
    StageRun? inProgress,
    bool clearInProgress = false,
    String? lastDailyBonusDate,
    int? dailyStreak,
  }) {
    return Progress(
      coins: coins ?? this.coins,
      highestUnlockedStage: highestUnlockedStage ?? this.highestUnlockedStage,
      stageStars: stageStars ?? this.stageStars,
      stageBestScore: stageBestScore ?? this.stageBestScore,
      clearedPuzzleIds: clearedPuzzleIds ?? this.clearedPuzzleIds,
      inProgress: clearInProgress ? null : (inProgress ?? this.inProgress),
      lastDailyBonusDate: lastDailyBonusDate ?? this.lastDailyBonusDate,
      dailyStreak: dailyStreak ?? this.dailyStreak,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'coins': coins,
    'highestUnlockedStage': highestUnlockedStage,
    'stageStars': _encodeMap(stageStars),
    'stageBestScore': _encodeMap(stageBestScore),
    'clearedPuzzleIds': clearedPuzzleIds.toList()..sort(),
    'inProgress': inProgress?.toJson(),
    'lastDailyBonusDate': lastDailyBonusDate,
    'dailyStreak': dailyStreak,
  };

  /// Melempar [FormatException] jika [Progress.schemaVersion] tidak cocok
  /// (format lama), dan TypeError/FormatException jika isinya rusak.
  factory Progress.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Versi progress ${json['schemaVersion']} != $schemaVersion',
      );
    }
    final initial = Progress.initial();
    final cleared = json['clearedPuzzleIds'];
    return Progress(
      coins: (json['coins'] as num?)?.toInt() ?? initial.coins,
      highestUnlockedStage:
          (json['highestUnlockedStage'] as num?)?.toInt() ??
          initial.highestUnlockedStage,
      stageStars: _decodeMap(json['stageStars']),
      stageBestScore: _decodeMap(json['stageBestScore']),
      clearedPuzzleIds: cleared is List ? cleared.cast<String>().toSet() : {},
      inProgress: StageRun.fromJson(json['inProgress']),
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

  static bool _mapEquals(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static int _mapHash(Map<int, int> m) => Object.hashAllUnordered(
    m.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  bool operator ==(Object other) =>
      other is Progress &&
      other.coins == coins &&
      other.highestUnlockedStage == highestUnlockedStage &&
      _mapEquals(other.stageStars, stageStars) &&
      _mapEquals(other.stageBestScore, stageBestScore) &&
      other.clearedPuzzleIds.length == clearedPuzzleIds.length &&
      other.clearedPuzzleIds.containsAll(clearedPuzzleIds) &&
      other.inProgress == inProgress &&
      other.lastDailyBonusDate == lastDailyBonusDate &&
      other.dailyStreak == dailyStreak;

  @override
  int get hashCode => Object.hash(
    coins,
    highestUnlockedStage,
    _mapHash(stageStars),
    _mapHash(stageBestScore),
    Object.hashAllUnordered(clearedPuzzleIds),
    inProgress,
    lastDailyBonusDate,
    dailyStreak,
  );

  @override
  String toString() => 'Progress(${toJson()})';
}
