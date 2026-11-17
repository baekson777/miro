import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

/// Blocks screenshots, screen recording, and app-switcher previews.
///
/// Enable during gameplay and while the 3-second hint reveal is active.
final class ScreenProtectService {
  ScreenProtectService._();

  static bool _active = false;

  static bool get isActive => _active;

  static Future<void> enable() async {
    if (kIsWeb || _active) return;
    try {
      await ScreenProtector.preventScreenshotOn();
      if (!kIsWeb && Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (!kIsWeb && Platform.isIOS) {
        // App-switcher preview cover on iOS.
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
      }
      _active = true;
    } catch (e, st) {
      debugPrint('ScreenProtect enable failed: $e\n$st');
    }
  }

  static Future<void> disable() async {
    if (kIsWeb || !_active) return;
    try {
      await ScreenProtector.preventScreenshotOff();
      if (!kIsWeb && Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOff();
      } else if (!kIsWeb && Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithColorOff();
      }
      _active = false;
    } catch (e, st) {
      debugPrint('ScreenProtect disable failed: $e\n$st');
    }
  }
}
