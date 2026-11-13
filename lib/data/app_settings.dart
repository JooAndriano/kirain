/// Preferensi pemain. Semua aktif secara default. Immutable.
class AppSettings {
  const AppSettings({
    this.music = true,
    this.soundEffects = true,
    this.vibration = true,
  });

  final bool music;
  final bool soundEffects;
  final bool vibration;

  AppSettings copyWith({bool? music, bool? soundEffects, bool? vibration}) =>
      AppSettings(
        music: music ?? this.music,
        soundEffects: soundEffects ?? this.soundEffects,
        vibration: vibration ?? this.vibration,
      );

  Map<String, dynamic> toJson() => {
    'music': music,
    'soundEffects': soundEffects,
    'vibration': vibration,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    music: json['music'] as bool? ?? true,
    soundEffects: json['soundEffects'] as bool? ?? true,
    vibration: json['vibration'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.music == music &&
      other.soundEffects == soundEffects &&
      other.vibration == vibration;

  @override
  int get hashCode => Object.hash(music, soundEffects, vibration);

  @override
  String toString() => 'AppSettings(${toJson()})';
}
