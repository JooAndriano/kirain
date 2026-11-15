import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent.dart';

/// ConsentGateway dengan UMP SDK (ConsentInformation / ConsentForm).
class UmpConsentGateway implements ConsentGateway {
  const UmpConsentGateway();

  ConsentInformation get _info => ConsentInformation.instance;

  @override
  Future<bool> requestInfoUpdate({
    required bool debugGeographyEea,
    required List<String> testDeviceIds,
  }) {
    final done = Completer<bool>();
    _info.requestConsentInfoUpdate(
      ConsentRequestParameters(
        consentDebugSettings: debugGeographyEea
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: testDeviceIds,
              )
            : null,
      ),
      () {
        if (!done.isCompleted) done.complete(true);
      },
      (FormError _) {
        if (!done.isCompleted) done.complete(false);
      },
    );
    return done.future;
  }

  @override
  Future<String?> loadAndShowFormIfRequired() async {
    final done = Completer<String?>();
    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (!done.isCompleted) done.complete(error?.message);
    });
    return done.future;
  }

  @override
  Future<String?> showPrivacyOptionsForm() async {
    final done = Completer<String?>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!done.isCompleted) done.complete(error?.message);
    });
    return done.future;
  }

  @override
  Future<String> consentStatus() async => (await _info.getConsentStatus()).name;

  @override
  Future<bool> canRequestAds() => _info.canRequestAds();

  @override
  Future<PrivacyOptionsStatus> privacyOptionsStatus() async =>
      switch (await _info.getPrivacyOptionsRequirementStatus()) {
        PrivacyOptionsRequirementStatus.required =>
          PrivacyOptionsStatus.required,
        PrivacyOptionsRequirementStatus.notRequired =>
          PrivacyOptionsStatus.notRequired,
        PrivacyOptionsRequirementStatus.unknown => PrivacyOptionsStatus.unknown,
      };

  @override
  Future<void> reset() => _info.reset();
}
