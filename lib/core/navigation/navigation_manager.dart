import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Debounced, stack-safe navigation helper.
///
/// Prevents:
/// - double-tap duplicate pushes
/// - deep stacks from Retry / Home / Result transitions
final class NavigationManager {
  NavigationManager._();

  static const Duration _debounceWindow = Duration(milliseconds: 450);
  static DateTime? _lastNavAt;
  static String? _lastNavTarget;

  static bool _shouldAllow(String target) {
    final now = DateTime.now();
    if (_lastNavTarget == target &&
        _lastNavAt != null &&
        now.difference(_lastNavAt!) < _debounceWindow) {
      return false;
    }
    _lastNavAt = now;
    _lastNavTarget = target;
    return true;
  }

  /// Replace current route (Retry / mode switch). Stack depth stays constant.
  static void replace(BuildContext context, String location, {Object? extra}) {
    if (!_shouldAllow('replace:$location')) return;
    context.replace(location, extra: extra);
  }

  /// Clear entire stack then land on [location] (Home / after clear).
  static void goAndClear(BuildContext context, String location, {Object? extra}) {
    if (!_shouldAllow('clear:$location')) return;
    // go() resets the imperative stack for that branch.
    context.go(location, extra: extra);
  }

  /// Named-style clear using Navigator when outside GoRouter scope.
  static void pushNamedAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    if (!_shouldAllow('named:$routeName')) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Result screen: replace game so back never returns to a finished maze.
  static void toResult(BuildContext context, {required Object extra}) {
    if (!_shouldAllow('result')) return;
    context.pushReplacement('/result', extra: extra);
  }

  /// Retry same mode: replace game route with a fresh instance.
  static void retryGame(BuildContext context, {required Object extra}) {
    if (!_shouldAllow('retry')) return;
    // Extra seed/mode object drives a new GameScreen; stack depth = 1 under shell.
    context.pushReplacement('/game', extra: extra);
  }

  /// Main / home — wipe stack.
  static void toHome(BuildContext context) {
    goAndClear(context, '/');
  }
}
