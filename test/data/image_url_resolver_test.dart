import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/data/image_url_resolver.dart';

void main() {
  String r(String base, String file) => ImageUrlResolver.resolve(base, file);

  group('ImageUrlResolver.resolve', () {
    const base = 'https://cdn.example.com/images';

    test('base dengan / di akhir', () {
      expect(r('$base/', 'kucing.webp'), '$base/kucing.webp');
    });

    test('base tanpa / di akhir -> ditambah satu', () {
      expect(r(base, 'kucing.webp'), '$base/kucing.webp');
    });

    test('garis miring ganda di sambungan dirapatkan', () {
      expect(r('$base/', '/kucing.webp'), '$base/kucing.webp');
      expect(r('$base//', '//kucing.webp'), '$base/kucing.webp');
    });

    test('// pada skema https tidak disentuh', () {
      expect(
        r('https://cdn.example.com/', 'a.png'),
        'https://cdn.example.com/a.png',
      );
    });

    test('subfolder di imageFile dipertahankan', () {
      expect(r('$base/', 'hewan/kucing.webp'), '$base/hewan/kucing.webp');
    });

    test('baseUrl kosong -> nama file saja', () {
      expect(r('', 'kucing.webp'), 'kucing.webp');
      expect(r('', '/kucing.webp'), 'kucing.webp');
      expect(r('   ', 'kucing.webp'), 'kucing.webp');
    });

    test('baseUrl hanya garis miring -> nama file saja', () {
      expect(r('/', 'kucing.webp'), 'kucing.webp');
    });

    test('imageFile kosong -> string kosong', () {
      expect(r(base, ''), '');
      expect(r(base, '   '), '');
      expect(r(base, '/'), '');
    });

    test('spasi di tepi dibuang', () {
      expect(r('  $base/  ', '  kucing.webp '), '$base/kucing.webp');
    });

    test('imageFile yang sudah URL absolut dipakai apa adanya', () {
      expect(r(base, 'https://other.com/x.png'), 'https://other.com/x.png');
      expect(r(base, 'HTTP://other.com/x.png'), 'HTTP://other.com/x.png');
    });
  });

  test('localLevelAsset menunjuk ke folder aset', () {
    expect(localLevelAsset('level1.png'), 'assets/images/level1.png');
  });
}
