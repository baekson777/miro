import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/ad_constants.dart';

typedef AdLifecycleCallback = void Function();

/// Loads & shows rewarded ads. Notifies pause/resume for the game stopwatch.
final class RewardedAdService {
  RewardedAd? _ad;
  bool _isLoading = false;

  String get _unitId {
    if (kIsWeb) return AdConstants.rewardedAndroid;
    return Platform.isIOS
        ? AdConstants.rewardedIos
        : AdConstants.rewardedAndroid;
  }

  Future<void> preload() async {
    if (_ad != null || _isLoading) return;
    _isLoading = true;
    await RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed: $error');
          _ad = null;
          _isLoading = false;
        },
      ),
    );
  }

  bool get isReady => _ad != null;

  /// Shows ad. [onAdOpened] → pause timer; [onAdClosed] → resume.
  /// Returns `true` if the user earned the reward.
  Future<bool> show({
    required AdLifecycleCallback onAdOpened,
    required AdLifecycleCallback onAdClosed,
  }) async {
    final ad = _ad;
    if (ad == null) {
      await preload();
      return false;
    }

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => onAdOpened(),
      onAdDismissedFullScreenContent: (dismissed) {
        dismissed.dispose();
        _ad = null;
        onAdClosed();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (failed, error) {
        debugPrint('Rewarded show failed: $error');
        failed.dispose();
        _ad = null;
        onAdClosed();
        unawaited(preload());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );

    _ad = null;
    return completer.future;
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
