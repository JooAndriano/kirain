import 'dart:async';

/// Status privacyOptionsRequirementStatus UMP, tanpa tipe SDK.
enum PrivacyOptionsStatus {
  /// Belum diketahui (consent belum dicek / gagal).
  unknown,

  /// Wajib ada entri "Pengaturan privasi" (mis. pengguna EEA/UK).
  required,

  notRequired,
}

/// Ringkasan consent setelah dicek. Immutable.
class ConsentState {
  const ConsentState({
    required this.consent,
    required this.canRequestAds,
    required this.privacyOptions,
  });

  /// Status consent UMP (teks untuk debug).
  final String consent;
  final bool canRequestAds;
  final PrivacyOptionsStatus privacyOptions;
}

/// Akses UMP (ConsentInformation / ConsentForm). Implementasi SDK:
/// UmpConsentGateway; di tes: fake.
abstract class ConsentGateway {
  /// true jika berhasil, false jika gagal (tidak melempar).
  Future<bool> requestInfoUpdate({
    required bool debugGeographyEea,
    required List<String> testDeviceIds,
  });

  /// Pesan error, atau null jika sukses / tidak perlu form.
  Future<String?> loadAndShowFormIfRequired();

  /// Pesan error, atau null jika form ditutup normal.
  Future<String?> showPrivacyOptionsForm();

  Future<String> consentStatus();
  Future<bool> canRequestAds();
  Future<PrivacyOptionsStatus> privacyOptionsStatus();
  Future<void> reset();
}

/// Alur consent (Dart murni): kumpulkan consent saat start, dan buka
/// "Pengaturan privasi" lalu muat ulang status. Tidak pernah melempar;
/// kegagalan dianggap "tidak boleh meminta iklan".
class ConsentFlow {
  ConsentFlow(
    this._gateway, {
    void Function(String message)? log,
    this.infoUpdateTimeout = const Duration(seconds: 5),
  }) : _log = log ?? _noLog;

  static void _noLog(String _) {}

  final ConsentGateway _gateway;
  final void Function(String message) _log;
  final Duration infoUpdateTimeout;

  /// canRequestAds dari sesi sebelumnya (tersimpan di perangkat).
  Future<bool> cachedCanRequestAds() =>
      _safe('canRequestAds', _gateway.canRequestAds, false);

  /// requestConsentInfoUpdate -> loadAndShowConsentFormIfRequired -> status.
  Future<ConsentState> gather({
    bool debugGeographyEea = false,
    List<String> testDeviceIds = const [],
  }) async {
    final updated = await _safe(
      'requestConsentInfoUpdate',
      () => _gateway
          .requestInfoUpdate(
            debugGeographyEea: debugGeographyEea,
            testDeviceIds: testDeviceIds,
          )
          .timeout(
            infoUpdateTimeout,
            onTimeout: () {
              _log('requestConsentInfoUpdate timeout ($infoUpdateTimeout)');
              return false;
            },
          ),
      false,
    );
    if (updated) {
      // Tanpa timeout: form menunggu pemain (init berjalan di latar).
      final error = await _safe(
        'consent form',
        _gateway.loadAndShowFormIfRequired,
        'gagal',
      );
      if (error != null) _log('consent form error: $error');
    }
    return refresh();
  }

  /// Buka form "Pengaturan privasi", lalu muat ulang status consent dan
  /// canRequestAds.
  Future<ConsentState> showPrivacyOptions() async {
    final error = await _safe(
      'privacy options form',
      _gateway.showPrivacyOptionsForm,
      'gagal',
    );
    if (error != null) _log('privacy options form error: $error');
    return refresh();
  }

  Future<ConsentState> refresh() async {
    final state = ConsentState(
      consent: await _safe('getConsentStatus', _gateway.consentStatus, '?'),
      canRequestAds: await cachedCanRequestAds(),
      privacyOptions: await _safe(
        'privacyOptionsRequirementStatus',
        _gateway.privacyOptionsStatus,
        PrivacyOptionsStatus.unknown,
      ),
    );
    _log(
      'consent=${state.consent} canRequestAds=${state.canRequestAds} '
      'privacyOptions=${state.privacyOptions.name}',
    );
    return state;
  }

  Future<void> reset() => _safe('reset consent', _gateway.reset, null);

  Future<T> _safe<T>(String what, Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } catch (e) {
      _log('$what gagal: $e');
      return fallback;
    }
  }
}
