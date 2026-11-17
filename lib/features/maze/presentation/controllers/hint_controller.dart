import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/game_constants.dart';
import '../../../ads/rewarded_ad_service.dart';
import '../../../security/screen_protect_service.dart';
import 'timer_controller.dart';

/// Manages free hints, 3s reveal, and ad-gated recharge (max 2 ads / round).
final class HintController extends ChangeNotifier {
  HintController({
    required this._timer,
    this._onAdPause,
    this._onAdResume,
    bool Function()? isAdminMode,
    RewardedAdService? adService,
  })  : _isAdminMode = isAdminMode ?? (() => false),
        _ads = adService ?? RewardedAdService();

  final TimerController _timer;
  final VoidCallback? _onAdPause;
  final VoidCallback? _onAdResume;
  final bool Function() _isAdminMode;
  final RewardedAdService _ads;

  int _remaining = GameConstants.defaultHintCount;
  int _usedTotal = 0;
  int _adHintsGranted = 0;
  bool _revealing = false;
  Timer? _revealTimer;

  bool get _admin => _isAdminMode();

  int get remaining => _admin ? 999 : _remaining;
  int get usedTotal => _usedTotal;
  int get adHintsGranted => _adHintsGranted;
  bool get isRevealing => _revealing;
  bool get canUseHint =>
      !_revealing && !_timer.isPaused && (_admin || _remaining > 0);
  bool get canWatchAdForHint =>
      !_admin &&
      _remaining == 0 &&
      _adHintsGranted < GameConstants.maxAdHintPerRound &&
      !_revealing &&
      !_timer.isPaused;
  int get adsRemaining =>
      _admin ? 0 : GameConstants.maxAdHintPerRound - _adHintsGranted;

  Future<void> preloadAd() => _ads.preload();

  void refreshLimits() => notifyListeners();

  /// Spend one hint and reveal maze for 3 seconds.
  Future<void> useHint() async {
    if (!canUseHint) return;

    if (!_admin) {
      _remaining--;
    }
    _usedTotal++;
    _revealing = true;
    notifyListeners();

    await ScreenProtectService.enable();

    _revealTimer?.cancel();
    _revealTimer = Timer(GameConstants.hintRevealDuration, () {
      _revealing = false;
      notifyListeners();
    });
  }

  /// Show rewarded ad → +1 hint if earned. Pauses stopwatch while ad is open.
  Future<bool> watchAdForHint() async {
    if (_admin) {
      // Admin: grant a free hint without ads.
      _remaining++;
      notifyListeners();
      return true;
    }
    if (!canWatchAdForHint) return false;

    final earned = await _ads.show(
      onAdOpened: () => (_onAdPause ?? _timer.pause)(),
      onAdClosed: () => (_onAdResume ?? _timer.resume)(),
    );

    if (earned) {
      _adHintsGranted++;
      _remaining++;
      notifyListeners();
    }
    return earned;
  }

  void disposeTimers() {
    _revealTimer?.cancel();
    _ads.dispose();
  }

  @override
  void dispose() {
    disposeTimers();
    super.dispose();
  }
}
