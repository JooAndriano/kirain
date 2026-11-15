import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kirain/ads/consent.dart';

import '../support/fakes.dart';

void main() {
  late FakeConsentGateway gateway;
  late List<String> logs;

  ConsentFlow flow({Duration timeout = const Duration(seconds: 5)}) =>
      ConsentFlow(gateway, log: logs.add, infoUpdateTimeout: timeout);

  setUp(() {
    gateway = FakeConsentGateway();
    logs = [];
  });

  group('gather (saat start)', () {
    test('status privasi required diteruskan', () async {
      gateway.privacyOptions = PrivacyOptionsStatus.required;
      final s = await flow().gather();
      expect(s.privacyOptions, PrivacyOptionsStatus.required);
      expect(s.canRequestAds, isTrue);
      expect(s.consent, 'obtained');
      expect(gateway.calls.take(2), ['update', 'form']);
    });

    test('status privasi notRequired diteruskan', () async {
      gateway.privacyOptions = PrivacyOptionsStatus.notRequired;
      final s = await flow().gather();
      expect(s.privacyOptions, PrivacyOptionsStatus.notRequired);
    });

    test(
      'update consent gagal -> form dilewati, status tetap dibaca',
      () async {
        gateway.updateSucceeds = false;
        final s = await flow().gather();
        expect(gateway.calls, isNot(contains('form')));
        expect(gateway.calls, contains('privacyStatus'));
        expect(s.canRequestAds, isTrue); // consent tersimpan dari sesi lalu
      },
    );

    test('update consent timeout -> tidak menggantung', () async {
      gateway.updateGate = Completer();
      final s = await flow(timeout: const Duration(milliseconds: 10)).gather();
      expect(gateway.calls, isNot(contains('form')));
      expect(s.privacyOptions, PrivacyOptionsStatus.notRequired);
      expect(logs.any((l) => l.contains('timeout')), isTrue);
    });

    test('UMP melempar -> aman: tanpa iklan, status unknown', () async {
      gateway.throwOnStatus = Exception('channel');
      final s = await flow().gather();
      expect(s.canRequestAds, isFalse);
      expect(s.privacyOptions, PrivacyOptionsStatus.unknown);
    });
  });

  group('showPrivacyOptions', () {
    test(
      'buka form lalu muat ulang status consent dan canRequestAds',
      () async {
        gateway.privacyOptions = PrivacyOptionsStatus.required;
        final s = await flow().showPrivacyOptions();
        expect(gateway.calls, [
          'privacyForm',
          'status',
          'canRequestAds',
          'privacyStatus',
        ]);
        expect(s.privacyOptions, PrivacyOptionsStatus.required);
      },
    );

    test('pemain menolak iklan di form -> canRequestAds false', () async {
      gateway
        ..privacyOptions = PrivacyOptionsStatus.required
        ..onPrivacyFormClosed = () {
          gateway
            ..canRequest = false
            ..consent = 'required';
        };
      final s = await flow().showPrivacyOptions();
      expect(s.canRequestAds, isFalse);
      expect(s.consent, 'required');
    });

    test('pemain mengizinkan lagi -> canRequestAds true', () async {
      gateway
        ..canRequest = false
        ..onPrivacyFormClosed = () => gateway.canRequest = true;
      final s = await flow().showPrivacyOptions();
      expect(s.canRequestAds, isTrue);
    });

    test('form error tetap memuat ulang status', () async {
      gateway.formError = 'form tidak tersedia';
      final s = await flow().showPrivacyOptions();
      expect(gateway.calls, contains('canRequestAds'));
      expect(s.canRequestAds, isTrue);
      expect(logs.any((l) => l.contains('form tidak tersedia')), isTrue);
    });
  });
}
