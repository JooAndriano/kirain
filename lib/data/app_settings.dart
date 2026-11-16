/// Preferensi pemain. Semua aktif secara default. Immutable.
class AppSettings {
  const AppSettings({
    this.music = true,
    this.soundEffects = true,
    this.vibration = true,
    this.tutorialSeen = false,
  });

  final bool music;
  final bool soundEffects;
  final bool vibration;

  /// Tutorial cara bermain sudah pernah ditampilkan (selesai atau dilewati).
  final bool tutorialSeen;

  AppSettings copyWith({
    bool? music,
    bool? soundEffects,
    bool? vibration,
    bool? tutorialSeen,
  }) => AppSettings(
    music: music ?? this.music,
    soundEffects: soundEffects ?? this.soundEffects,
    vibration: vibration ?? this.vibration,
    tutorialSeen: tutorialSeen ?? this.tutorialSeen,
  );

  Map<String, dynamic> toJson() => {
    'music': music,
    'soundEffects': soundEffects,
    'vibration': vibration,
    'tutorialSeen': tutorialSeen,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    music: json['music'] as bool? ?? true,
    soundEffects: json['soundEffects'] as bool? ?? true,
    vibration: json['vibration'] as bool? ?? true,
    tutorialSeen: json['tutorialSeen'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.music == music &&
      other.soundEffects == soundEffects &&
      other.vibration == vibration &&
      other.tutorialSeen == tutorialSeen;

  @override
  int get hashCode => Object.hash(music, soundEffects, vibration, tutorialSeen);

  @override
  String toString() => 'AppSettings(${toJson()})';
}
