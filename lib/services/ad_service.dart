import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'game_backend.dart';

class AdService {
  AdService(this._backend);

  final GameBackend _backend;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  DateTime? _lastInterstitialAt;
  bool _isLoadingRewarded = false;
  bool _isLoadingInterstitial = false;

  static const interstitialCooldown = Duration(minutes: 3);

  // Google test IDs. Replace these with production IDs before release.
  static const _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const _androidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  String get _rewardedUnitId =>
      Platform.isIOS ? _iosRewardedId : _androidRewardedId;
  String get _interstitialUnitId =>
      Platform.isIOS ? _iosInterstitialId : _androidInterstitialId;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  Future<void> preload() async {
    _loadRewarded();
    _loadInterstitial();
  }

  Future<RewardClaimResult?> showRewarded({
    required RewardKind kind,
    String? carId,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      await _loadRewarded();
      return null;
    }

    final rewardId = _newRewardId();
    final completer = Completer<RewardClaimResult?>();
    var earned = false;
    ad.setServerSideOptions(
      ServerSideVerificationOptions(customData: rewardId),
    );
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted && !earned) completer.complete(null);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        earned = true;
        final claim = await _backend.claimReward(
          rewardId: rewardId,
          kind: kind,
          carId: carId,
        );
        if (!completer.isCompleted) completer.complete(claim);
      },
    );
    _rewardedAd = null;
    return completer.future;
  }

  Future<bool> maybeShowInterstitial({
    required bool isRestoring,
    required bool isSelling,
  }) async {
    if (isRestoring || isSelling) return false;
    final last = _lastInterstitialAt;
    if (last != null &&
        DateTime.now().difference(last) < interstitialCooldown) {
      return false;
    }
    final ad = _interstitialAd;
    if (ad == null) {
      await _loadInterstitial();
      return false;
    }

    final completer = Completer<bool>();
    _lastInterstitialAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    ad.show();
    _interstitialAd = null;
    return completer.future;
  }

  Future<void> _loadRewarded() async {
    if (_rewardedAd != null || _isLoadingRewarded) return;
    _isLoadingRewarded = true;
    await RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  Future<void> _loadInterstitial() async {
    if (_interstitialAd != null || _isLoadingInterstitial) return;
    _isLoadingInterstitial = true;
    await InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  String _newRewardId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
