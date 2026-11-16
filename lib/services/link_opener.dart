import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Halaman Terms & Condition Kirain.
final termsAndConditionsUrl = Uri.parse(
  'https://jivottama.dev/kirain/termsandcondition',
);

/// Membuka link di luar aplikasi. Widget memakai ini, bukan url_launcher
/// langsung, agar mudah diganti saat test.
abstract class LinkOpener {
  /// Mengembalikan false bila link gagal dibuka. Tidak pernah melempar.
  Future<bool> open(Uri url);
}

class UrlLauncherLinkOpener implements LinkOpener {
  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Gagal membuka $url: $e');
      return false;
    }
  }
}

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => UrlLauncherLinkOpener(),
);
