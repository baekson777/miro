import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../leaderboard/data/leaderboard_repository.dart';
import 'kakao_auth_service.dart';
import 'user_firestore_repository.dart';

/// Kakao login + Firestore `users/{kakaoId}` upsert / delete.
final class KakaoFirestoreAuth {
  KakaoFirestoreAuth({
    KakaoAuthService? kakao,
    UserFirestoreRepository? users,
  })  : _kakao = kakao ?? const KakaoAuthService(),
        _users = users ?? UserFirestoreRepository();

  final KakaoAuthService _kakao;
  final UserFirestoreRepository _users;

  /// 1) Kakao login → 2) read id/nickname → 3) merge into Firestore.
  Future<KakaoLoginResult> loginAndSync() async {
    debugPrint('[Auth] loginAndSync begin');
    final result = await _kakao.login();
    await _users.upsertKakaoUser(
      kakaoId: result.id,
      kakaoNickname: result.nickname,
    );
    debugPrint('[Auth] loginAndSync success id=${result.id}');
    return result;
  }

  Future<void> logout() => _kakao.logout();

  /// Full withdrawal: Firestore + local ranking nick + Kakao unlink.
  Future<void> deleteAccount(int kakaoId) async {
    debugPrint('[Auth] deleteAccount begin id=$kakaoId');
    final playerId = 'kakao_$kakaoId';

    try {
      await _users.deleteAccount(kakaoId);
    } catch (e) {
      debugPrint('[Auth] Firestore delete failed: $e');
      rethrow;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await LeaderboardRepository(prefs).clearAccountLocalData(playerId);
    } catch (e) {
      debugPrint('[Auth] local clear failed: $e');
    }

    try {
      await _kakao.unlink();
    } catch (e) {
      debugPrint('[Auth] Kakao unlink failed, fallback logout: $e');
      try {
        await _kakao.logout();
      } catch (_) {}
    }

    debugPrint('[Auth] deleteAccount done id=$kakaoId');
  }

  Future<bool> hasValidToken() => _kakao.hasValidToken();

  Future<KakaoLoginResult?> restoreSession() async {
    if (!await _kakao.hasValidToken()) return null;
    final user = await _kakao.currentUser();
    return KakaoLoginResult(user: user);
  }
}
