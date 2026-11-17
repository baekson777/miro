import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only admin mode. Hard-disabled in release / profile production builds.
///
/// Safety: [isAvailable] is `true` only when `kDebugMode` is true.
/// Release builds never expose the toggle UI and cannot enable the flag.
final class AdminModeController extends ChangeNotifier {
  bool _isAdminMode = false;

  /// Compile-time gate — false in `flutter run --release` / store builds.
  static bool get isAvailable => kDebugMode;

  bool get isAdminMode => isAvailable && _isAdminMode;

  void setEnabled(bool enabled) {
    if (!isAvailable) {
      if (_isAdminMode) {
        _isAdminMode = false;
        notifyListeners();
      }
      return;
    }
    if (_isAdminMode == enabled) return;
    _isAdminMode = enabled;
    notifyListeners();
  }

  void toggle() => setEnabled(!_isAdminMode);

  void forceOff() => setEnabled(false);
}

final adminModeProvider =
    ChangeNotifierProvider<AdminModeController>((ref) => AdminModeController());
