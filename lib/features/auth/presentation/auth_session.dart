import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/kakao_auth_service.dart';
import '../data/kakao_firestore_auth.dart';

/// Shared Kakao login session for ranking / guest UX.
final class AuthSessionController extends ChangeNotifier {
  AuthSessionController({KakaoFirestoreAuth? auth})
      : _auth = auth ?? KakaoFirestoreAuth();

  final KakaoFirestoreAuth _auth;

  KakaoLoginResult? _user;
  bool _ready = false;

  KakaoLoginResult? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isReady => _ready;

  /// Kakao id string for stable ranking playerId when logged in.
  String? get rankingPlayerId =>
      _user == null ? null : 'kakao_${_user!.id}';

  String? get nickname => _user?.nickname;

  Future<void> restore() async {
    try {
      final session = await _auth.restoreSession();
      _user = session;
    } catch (e) {
      debugPrint('[Auth] restore skipped: $e');
      _user = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<KakaoLoginResult> loginAndSync() async {
    final result = await _auth.loginAndSync();
    _user = result;
    _ready = true;
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    notifyListeners();
  }

  /// 회원탈퇴: 서버/로컬 데이터 삭제 + 카카오 연동 해제.
  Future<void> deleteAccount() async {
    final user = _user;
    if (user == null) {
      throw StateError('로그인된 계정이 없습니다.');
    }
    await _auth.deleteAccount(user.id);
    _user = null;
    notifyListeners();
  }
}

final authSessionProvider =
    ChangeNotifierProvider<AuthSessionController>((ref) {
  final c = AuthSessionController();
  // Fire-and-forget restore so home/result can react when ready.
  c.restore();
  return c;
});
