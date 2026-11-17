/// Kakao Developers native app key (플랫폼 키).
abstract final class KakaoAppKeys {
  static const nativeAppKey = 'bfc81b2ecfe0f4ccd56ad91d481bb01a';

  /// Android / iOS custom URL scheme: `kakao{NATIVE_APP_KEY}`
  static const urlScheme = 'kakao$nativeAppKey';
}
