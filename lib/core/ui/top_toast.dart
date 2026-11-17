import 'package:flutter/material.dart';

/// Floating toast anchored near the top of the screen.
abstract final class TopToast {
  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final media = MediaQuery.of(context);
    final bottomGap = media.size.height - media.padding.top - 96;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomGap.clamp(48.0, double.infinity),
        ),
        duration: const Duration(seconds: 2),
        dismissDirection: DismissDirection.up,
      ),
    );
  }
}
