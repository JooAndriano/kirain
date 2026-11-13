import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'remote_settings.dart';

class FirebaseRemoteSettings implements RemoteSettings {
  FirebaseRemoteSettings(this._rc, {bool debug = kDebugMode})
    : _minimumFetchInterval = debug ? Duration.zero : const Duration(hours: 1);

  static const imageBaseUrlKey = 'imageBaseUrl';

  final FirebaseRemoteConfig _rc;
  final Duration _minimumFetchInterval;

  @override
  String get imageBaseUrl {
    try {
      final v = _rc.getString(imageBaseUrlKey).trim();
      return v.isEmpty ? kDefaultImageBaseUrl : v;
    } catch (_) {
      return kDefaultImageBaseUrl;
    }
  }

  @override
  Future<void> init() async {
    try {
      await _rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: _minimumFetchInterval,
        ),
      );
      await _rc.setDefaults(const {imageBaseUrlKey: kDefaultImageBaseUrl});
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteSettings: fetch gagal, memakai default/terakhir: $e');
    }
  }
}
