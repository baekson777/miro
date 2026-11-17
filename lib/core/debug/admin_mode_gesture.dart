import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/top_toast.dart';
import 'admin_mode.dart';

/// Hold for 3 seconds to toggle admin mode (debug builds only).
class AdminModeLongPress extends ConsumerWidget {
  const AdminModeLongPress({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AdminModeController.isAvailable) return child;

    return _HoldToUnlock(
      holdDuration: const Duration(seconds: 3),
      onUnlocked: () {
        final admin = ref.read(adminModeProvider);
        admin.toggle();
        HapticFeedback.heavyImpact();
        final on = admin.isAdminMode;
        TopToast.show(
          context,
          on ? '관리자 모드 ON — 전체 미로 / 힌트 무제한' : '관리자 모드 OFF',
        );
      },
      child: child,
    );
  }
}

class _HoldToUnlock extends StatefulWidget {
  const _HoldToUnlock({
    required this.holdDuration,
    required this.onUnlocked,
    required this.child,
  });

  final Duration holdDuration;
  final VoidCallback onUnlocked;
  final Widget child;

  @override
  State<_HoldToUnlock> createState() => _HoldToUnlockState();
}

class _HoldToUnlockState extends State<_HoldToUnlock> {
  DateTime? _downAt;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) async {
        _downAt = DateTime.now();
        _fired = false;
        final started = _downAt;
        await Future<void>.delayed(widget.holdDuration);
        if (!mounted || _fired) return;
        if (_downAt == null || _downAt != started) return;
        _fired = true;
        if (kDebugMode) widget.onUnlocked();
      },
      onPointerUp: (_) {
        _downAt = null;
        _fired = false;
      },
      onPointerCancel: (_) {
        _downAt = null;
        _fired = false;
      },
      child: widget.child,
    );
  }
}
