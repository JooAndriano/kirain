/// Pengaturan jarak jauh (Remote Config). Read-only bagi app.
abstract class RemoteSettings {
  /// Prefix URL gambar level; URL = imageBaseUrl + Level.imageFile.
  String get imageBaseUrl;

  /// Ambil dan aktifkan nilai terbaru. Tidak boleh melempar: jika gagal,
  /// nilai default/terakhir tetap dipakai.
  Future<void> init();
}

/// Default bila Remote Config belum di-fetch/di-publish: URL publik R2
/// (r2.dev). Nilai di Remote Config tetap diutamakan.
const String kDefaultImageBaseUrl =
    'https://pub-63a1d8f373824840b2af5ae066a33a12.r2.dev/';

/// Dipakai saat Firebase tidak tersedia: selalu nilai default.
class DefaultRemoteSettings implements RemoteSettings {
  const DefaultRemoteSettings();

  @override
  String get imageBaseUrl => kDefaultImageBaseUrl;

  @override
  Future<void> init() async {}
}
