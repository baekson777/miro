import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

/// Result of a successful Kakao login + [UserApi.me] call.
final class KakaoLoginResult {
  const KakaoLoginResult({
    required this.user,
    this.token,
    this.usedKakaoTalk = false,
  });

  final OAuthToken? token;
  final User user;
  final bool usedKakaoTalk;

  /// Kakao unique user id (`User.id`).
  int get id => user.id;

  /// Kakao profile nickname (fallback label if missing).
  String get nickname =>
      user.kakaoAccount?.profile?.nickname?.trim().isNotEmpty == true
          ? user.kakaoAccount!.profile!.nickname!.trim()
          : '카카오 사용자';

  String? get email => user.kakaoAccount?.email;

  @Deprecated('Use id')
  int get kakaoUserId => id;
}

/// Kakao Login helper: Talk app when installed, otherwise account (web) login.
final class KakaoAuthService {
  const KakaoAuthService();

  /// Issues an OAuth token, then loads id + nickname via [UserApi.me].
  ///
  /// Flow (Kakao docs):
  /// 1. [isKakaoTalkInstalled] → [UserApi.loginWithKakaoTalk]
  /// 2. On cancel (`PlatformException` code `CANCELED`) → rethrow
  /// 3. On other Talk failures → [UserApi.loginWithKakaoAccount]
  /// 4. Talk not installed → [UserApi.loginWithKakaoAccount]
  Future<KakaoLoginResult> login() async {
    debugPrint('[Kakao] login start');
    final talkInstalled = await isKakaoTalkInstalled();
    debugPrint('[Kakao] isKakaoTalkInstalled=$talkInstalled');

    late final OAuthToken token;
    var usedKakaoTalk = false;

    if (talkInstalled) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
        usedKakaoTalk = true;
        debugPrint('[Kakao] loginWithKakaoTalk success');
      } catch (error) {
        debugPrint('[Kakao] loginWithKakaoTalk failed: $error');
        if (error is PlatformException && error.code == 'CANCELED') {
          rethrow;
        }
        token = await UserApi.instance.loginWithKakaoAccount();
        debugPrint('[Kakao] loginWithKakaoAccount success (fallback)');
      }
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
      debugPrint('[Kakao] loginWithKakaoAccount success');
    }

    final user = await UserApi.instance.me();
    final result = KakaoLoginResult(
      token: token,
      user: user,
      usedKakaoTalk: usedKakaoTalk,
    );
    debugPrint('[Kakao] me() id=${result.id} nickname=${result.nickname}');
    return result;
  }

  Future<void> logout() => UserApi.instance.logout();

  /// Disconnects the app from the Kakao account (회원탈퇴용).
  Future<void> unlink() => UserApi.instance.unlink();

  Future<User> currentUser() => UserApi.instance.me();

  Future<bool> hasValidToken() async {
    if (!await AuthApi.instance.hasToken()) return false;
    try {
      await UserApi.instance.accessTokenInfo();
      return true;
    } catch (_) {
      return false;
    }
  }
}
