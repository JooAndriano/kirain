import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kirain/ads/ad_manager.dart';
import 'package:kirain/ads/ad_policy.dart';
import 'package:kirain/ads/consent.dart';
import 'package:kirain/data/progress.dart';
import 'package:kirain/data/progress_repository.dart';
import 'package:kirain/data/puzzle.dart';
import 'package:kirain/data/puzzle_cache.dart';
import 'package:kirain/data/puzzle_repository.dart';
import 'package:kirain/data/remote_settings.dart';

class MemProgressRepo implements ProgressRepository {
  MemProgressRepo([Progress? initial]) : saved = initial ?? Progress.initial();
  Progress saved;
  Object? error;

  @override
  Future<Progress> load() async {
    if (error != null) throw error!;
    return saved;
  }

  @override
  Future<void> save(Progress p) async => saved = p;
}

/// Repo puzzle palsu yang bisa ditahan (loading), gagal, atau sukses.
class FakePuzzleRepo implements PuzzleRepository {
  FakePuzzleRepo(this.puzzles);
  List<Puzzle> puzzles;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<Puzzle>> fetchPuzzles() async {
    calls++;
    await gate?.future;
    if (error != null) throw error!;
    return puzzles;
  }
}

class MemPuzzleCache implements PuzzleCache {
  List<Puzzle>? stored;

  @override
  Future<List<Puzzle>?> load() async => stored;

  @override
  Future<void> save(List<Puzzle> puzzles) async => stored = [...puzzles];
}

Puzzle puzzle(int stage, int slot, {String? answer, String? id}) => Puzzle(
  id: id ?? 'stage_${stage.toString().padLeft(3, '0')}_$slot',
  stage: stage,
  slot: slot,
  imageFile: 's${stage}_$slot.webp',
  answer: answer ?? 'KUCING',
  focusX: 0.5,
  focusY: 0.5,
);

/// [count] stage lengkap mulai stage 1.
List<Puzzle> fullStages(int count) => [
  for (var s = 1; s <= count; s++)
    for (var slot = 1; slot <= 3; slot++) puzzle(s, slot),
];

/// AdManager palsu: tidak pernah memanggil SDK iklan.
class FakeAdManager implements AdManager {
  FakeAdManager({this.rewardedReady = true, this.earnReward = true});

  bool rewardedReady;

  /// true: show memanggil onUserEarnedReward (ditonton sampai selesai).
  bool earnReward;
  RewardedShowResult notEarnedResult = RewardedShowResult.dismissed;
  int rewardedShows = 0;

  /// Stage yang meminta interstitial.
  final interstitialStages = <int>[];

  /// Jika diisi, interstitial "tampil" sampai gate diselesaikan (ditutup).
  Completer<void>? interstitialGate;

  final _status = ValueNotifier(const AdStatus());

  @override
  ValueListenable<AdStatus> get status => _status;

  /// Simulasikan perubahan status (mis. hasil cek consent).
  void setStatus(AdStatus Function(AdStatus s) update) =>
      _status.value = update(_status.value);

  int privacyOptionsShows = 0;

  /// Status privasi setelah form "Pengaturan privasi" ditutup.
  PrivacyOptionsStatus? privacyOptionsAfterForm;

  @override
  Future<void> showPrivacyOptions() async {
    privacyOptionsShows++;
    final next = privacyOptionsAfterForm;
    if (next != null) setStatus((s) => s.copyWith(privacyOptions: next));
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> maybeShowInterstitialAfterStage(int stage) async {
    interstitialStages.add(stage);
    await interstitialGate?.future;
  }

  @override
  bool get isRewardedReady => rewardedReady;

  @override
  Future<RewardedShowResult> showRewarded({
    required VoidCallback onUserEarnedReward,
  }) async {
    if (!rewardedReady) return RewardedShowResult.notReady;
    rewardedShows++;
    if (!earnReward) return notEarnedResult;
    onUserEarnedReward();
    return RewardedShowResult.earned;
  }

  @override
  Future<void> resetConsent() async {}

  @override
  void dispose() {}
}

class FixedRemoteSettings implements RemoteSettings {
  FixedRemoteSettings([this.adParams = AdParams.defaults]);

  @override
  AdParams adParams;

  @override
  String get imageBaseUrl => kDefaultImageBaseUrl;

  @override
  Future<void> init() async {}
}

/// ConsentGateway palsu (UMP tanpa SDK). Field bisa diubah per skenario.
class FakeConsentGateway implements ConsentGateway {
  FakeConsentGateway({
    this.privacyOptions = PrivacyOptionsStatus.notRequired,
    this.canRequest = true,
    this.consent = 'obtained',
  });

  PrivacyOptionsStatus privacyOptions;
  bool canRequest;
  String consent;

  bool updateSucceeds = true;
  Completer<bool>? updateGate;
  String? formError;
  Object? throwOnStatus;

  /// Dijalankan saat form "Pengaturan privasi" ditutup (pemain mengubah
  /// pilihan).
  void Function()? onPrivacyFormClosed;

  final calls = <String>[];

  @override
  Future<bool> requestInfoUpdate({
    required bool debugGeographyEea,
    required List<String> testDeviceIds,
  }) async {
    calls.add('update');
    if (updateGate != null) return updateGate!.future;
    return updateSucceeds;
  }

  @override
  Future<String?> loadAndShowFormIfRequired() async {
    calls.add('form');
    return formError;
  }

  @override
  Future<String?> showPrivacyOptionsForm() async {
    calls.add('privacyForm');
    onPrivacyFormClosed?.call();
    return formError;
  }

  @override
  Future<String> consentStatus() async {
    calls.add('status');
    if (throwOnStatus != null) throw throwOnStatus!;
    return consent;
  }

  @override
  Future<bool> canRequestAds() async {
    calls.add('canRequestAds');
    if (throwOnStatus != null) throw throwOnStatus!;
    return canRequest;
  }

  @override
  Future<PrivacyOptionsStatus> privacyOptionsStatus() async {
    calls.add('privacyStatus');
    if (throwOnStatus != null) throw throwOnStatus!;
    return privacyOptions;
  }

  @override
  Future<void> reset() async => calls.add('reset');
}
