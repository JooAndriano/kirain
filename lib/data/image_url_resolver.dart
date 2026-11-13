/// Menggabungkan base URL (Remote Config) dengan nama file gambar level.
/// Dart murni, tanpa Flutter.
class ImageUrlResolver {
  const ImageUrlResolver._();

  /// Contoh: `resolve('https://cdn.x/img/', '/kucing.webp')`
  /// -> `https://cdn.x/img/kucing.webp`.
  ///
  /// - Spasi di tepi dibuang.
  /// - Garis miring berlebih di sambungan base/file dirapatkan jadi satu
  ///   (tanpa menyentuh `//` milik skema `https://`).
  /// - [baseUrl] kosong -> nama file saja (tanpa `/` di depan).
  /// - [imageFile] kosong -> string kosong (tidak ada gambar).
  /// - [imageFile] yang sudah URL absolut (`http://`/`https://`) dipakai apa adanya.
  static String resolve(String baseUrl, String imageFile) {
    final file = imageFile.trim().replaceFirst(RegExp(r'^/+'), '');
    if (file.isEmpty) return '';
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(file)) {
      return file;
    }
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty) return file;
    return '$base/$file';
  }
}

/// Folder aset lokal untuk level dummy.
const String kLocalLevelImageDir = 'assets/images/';

/// Resolver sementara: level dummy memakai gambar dari aset lokal.
/// Diganti URL remote saat level diambil dari Firestore.
String localLevelAsset(String imageFile) =>
    ImageUrlResolver.resolve(kLocalLevelImageDir, imageFile);
