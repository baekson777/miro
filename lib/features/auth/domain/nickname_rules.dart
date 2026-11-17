/// Display / uniqueness rules for player-registered game nicknames.
abstract final class NicknameRules {
  static const minLength = 2;
  static const maxLength = 12;

  /// Visible nickname (trimmed, collapsed spaces).
  static String display(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Firestore doc id key — case-insensitive for ASCII letters.
  static String normalizeKey(String raw) {
    return display(raw).toLowerCase();
  }

  /// Returns an error message, or `null` when valid.
  static String? validate(String raw) {
    final name = display(raw);
    if (name.isEmpty) return '닉네임을 입력해 주세요.';
    if (name.length < minLength) {
      return '닉네임은 $minLength자 이상이어야 합니다.';
    }
    if (name.length > maxLength) {
      return '닉네임은 $maxLength자 이하여야 합니다.';
    }
    // Letters / numbers / Hangul / spaces / limited punctuation.
    if (!RegExp(r'^[\w가-힣ㄱ-ㅎㅏ-ㅣ ·.\-]+$', unicode: true).hasMatch(name)) {
      return '사용할 수 없는 문자가 포함되어 있습니다.';
    }
    return null;
  }
}

final class NicknameTakenException implements Exception {
  const NicknameTakenException([this.nickname]);

  final String? nickname;

  @override
  String toString() =>
      nickname == null ? '이미 사용 중인 닉네임입니다.' : '"$nickname"은(는) 이미 사용 중입니다.';
}
