import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centisecond-precision stopwatch that supports ad-driven pause/resume.
///
/// Elapsed time is always derived from wall-clock segments (accurate).
/// UI [notifyListeners] runs at [_uiInterval] so HUD rebuilds stay cheap.
final class TimerController extends ChangeNotifier {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _segmentStartedAt;
  bool _running = false;
  bool _paused = false;

  /// How often HUD listeners are notified while running.
  static const Duration _uiInterval = Duration(milliseconds: 50);

  Duration get elapsed => _syncElapsed();
  bool get isRunning => _running && !_paused;
  bool get isPaused => _paused;

  /// Formatted as `12.45` (seconds with 2 decimal places).
  String get formatted {
    final totalCs = _syncElapsed().inMilliseconds ~/ 10;
    final whole = totalCs ~/ 100;
    final frac = (totalCs % 100).toString().padLeft(2, '0');
    return '$whole.$frac';
  }

  double get elapsedSeconds {
    final totalCs = _syncElapsed().inMilliseconds ~/ 10;
    return totalCs / 100.0;
  }

  Duration _frozenElapsed = Duration.zero;

  Duration _syncElapsed() {
    if (_running && !_paused && _segmentStartedAt != null) {
      _elapsed = _frozenElapsed + DateTime.now().difference(_segmentStartedAt!);
    }
    return _elapsed;
  }

  void start() {
    if (_running) return;
    _running = true;
    _paused = false;
    _segmentStartedAt = DateTime.now();
    _ticker = Timer.periodic(_uiInterval, (_) {
      if (_paused || _segmentStartedAt == null) return;
      _elapsed = _frozenElapsed + DateTime.now().difference(_segmentStartedAt!);
      notifyListeners();
    });
    notifyListeners();
  }

  void pause() {
    if (!_running || _paused) return;
    if (_segmentStartedAt != null) {
      _frozenElapsed += DateTime.now().difference(_segmentStartedAt!);
      _elapsed = _frozenElapsed;
    }
    _paused = true;
    _segmentStartedAt = null;
    notifyListeners();
  }

  void resume() {
    if (!_running || !_paused) return;
    _paused = false;
    _segmentStartedAt = DateTime.now();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    if (_running && !_paused && _segmentStartedAt != null) {
      _frozenElapsed += DateTime.now().difference(_segmentStartedAt!);
      _elapsed = _frozenElapsed;
    }
    _running = false;
    _paused = false;
    _segmentStartedAt = null;
    notifyListeners();
  }

  void reset() {
    stop();
    _elapsed = Duration.zero;
    _frozenElapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
