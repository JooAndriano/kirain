/// Pengaturan jarak jauh (Remote Config). Read-only bagi app.
abstract class RemoteSettings {
  /// Prefix URL gambar level; URL = imageBaseUrl + Level.imageFile.
  String get imageBaseUrl;

  /// Ambil dan aktifkan nilai terbaru. Tidak boleh melempar: jika gagal,
  /// nilai default/terakhir tetap dipakai.
  Future<void> init();
}

const String kDefaultImageBaseUrl = 'https://example.com/images/';

/// Dipakai saat Firebase tidak tersedia: selalu nilai default.
class DefaultRemoteSettings implements RemoteSettings {
  const DefaultRemoteSettings();

  @override
  String get imageBaseUrl => kDefaultImageBaseUrl;

  @override
  Future<void> init() async {}
}
