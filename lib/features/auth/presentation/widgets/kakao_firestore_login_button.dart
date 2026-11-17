import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/top_toast.dart';
import '../auth_session.dart';

enum KakaoAuthButtonMode {
  /// Show login when logged out; nothing when logged in.
  loginOnly,

  /// Show logout when logged in; nothing when logged out.
  logoutOnly,

  /// Toggle login / logout (default).
  both,
}

/// Kakao login + Firestore users upsert, wired to [authSessionProvider].
class KakaoFirestoreLoginButton extends ConsumerStatefulWidget {
  const KakaoFirestoreLoginButton({
    super.key,
    this.onSuccess,
    this.onLoggedOut,
    this.mode = KakaoAuthButtonMode.both,
  });

  final VoidCallback? onSuccess;
  final VoidCallback? onLoggedOut;
  final KakaoAuthButtonMode mode;

  @override
  ConsumerState<KakaoFirestoreLoginButton> createState() =>
      _KakaoFirestoreLoginButtonState();
}

class _KakaoFirestoreLoginButtonState
    extends ConsumerState<KakaoFirestoreLoginButton> {
  static const _kakaoYellow = Color(0xFFFEE500);
  static const _kakaoBrown = Color(0xFF191919);

  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = ref.read(authSessionProvider);
    try {
      if (auth.isLoggedIn) {
        debugPrint('[UI] logout…');
        await auth.logout();
        widget.onLoggedOut?.call();
        if (!mounted) return;
        TopToast.show(context, '카카오 로그아웃 완료');
        return;
      }

      debugPrint('[UI] 카카오 로그인 및 연동 start');
      final result = await auth.loginAndSync();
      widget.onSuccess?.call();
      debugPrint(
        '[UI] success id=${result.id} nickname=${result.nickname}',
      );
      if (!mounted) return;
      TopToast.show(context, '카카오 연동 완료');
    } catch (e, st) {
      debugPrint('[UI] 카카오 로그인 및 연동 failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      TopToast.show(context, '연동 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final loggedIn = session.isLoggedIn;
    final disabled = _busy || !session.isReady;

    final showLogin = !loggedIn &&
        (widget.mode == KakaoAuthButtonMode.loginOnly ||
            widget.mode == KakaoAuthButtonMode.both);
    final showLogout = loggedIn &&
        (widget.mode == KakaoAuthButtonMode.logoutOnly ||
            widget.mode == KakaoAuthButtonMode.both);

    if (!showLogin && !showLogout) {
      return const SizedBox.shrink();
    }

    return FilledButton(
      onPressed: disabled ? null : _onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: showLogout ? Colors.transparent : _kakaoYellow,
        foregroundColor: showLogout ? Colors.white70 : _kakaoBrown,
        disabledBackgroundColor: _kakaoYellow.withValues(alpha: 0.6),
        side: showLogout
            ? const BorderSide(color: Colors.white24)
            : BorderSide.none,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: _busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: showLogout ? Colors.white70 : _kakaoBrown,
              ),
            )
          : Text(
              showLogout ? '카카오 로그아웃' : '카카오 로그인',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: showLogout ? Colors.white70 : _kakaoBrown,
              ),
            ),
    );
  }
}
