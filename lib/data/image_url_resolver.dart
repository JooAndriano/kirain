import 'puzzle.dart';

/// Menggabungkan base URL (Remote Config) dengan nama file gambar puzzle.
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

/// Folder aset lokal untuk puzzle dummy.
const String kLocalLevelImageDir = 'assets/images/';

/// Path aset lokal untuk gambar puzzle dummy.
String localLevelAsset(String imageFile) =>
    ImageUrlResolver.resolve(kLocalLevelImageDir, imageFile);

/// Asal gambar soal: aset lokal (dummy) atau URL remote (Firestore + R2).
sealed class LevelImageSource {
  const LevelImageSource();
}

class LocalLevelImage extends LevelImageSource {
  const LocalLevelImage(this.assetPath);
  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is LocalLevelImage && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;

  @override
  String toString() => 'LocalLevelImage($assetPath)';
}

class RemoteLevelImage extends LevelImageSource {
  const RemoteLevelImage(this.url);
  final String url;

  @override
  bool operator ==(Object other) =>
      other is RemoteLevelImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'RemoteLevelImage($url)';
}

/// Dummy -> aset lokal; puzzle Firestore -> imageBaseUrl + imageFile.
LevelImageSource puzzleImageSource(Puzzle puzzle, String imageBaseUrl) =>
    puzzle.isLocal
    ? LocalLevelImage(localLevelAsset(puzzle.imageFile))
    : RemoteLevelImage(
        ImageUrlResolver.resolve(imageBaseUrl, puzzle.imageFile),
      );
