/// Public / in-app addresses for Play Console & My Info.
///
/// Production (Vercel):
/// - Privacy: https://miro-n2kj.vercel.app/privacy
/// - Account deletion: https://miro-n2kj.vercel.app/account-deletion
abstract final class LegalUrls {
  /// Public site origin (Vercel production).
  static const siteOrigin = 'https://miro-n2kj.vercel.app';

  /// In-app GoRouter paths.
  static const privacyPolicyPath = '/legal/privacy';
  static const termsPath = '/legal/terms';
  static const accountDeletionPath = '/legal/account-deletion';

  /// Public web URLs (Play Console).
  static const privacyPolicyUrl = '$siteOrigin/privacy';
  static const accountDeletionUrl = '$siteOrigin/account-deletion';

  /// Relative paths under repo `docs/` (Vercel outputDirectory).
  static const privacyPolicyWebPath = 'legal/privacy.html';
  static const accountDeletionWebPath = 'legal/account-deletion.html';

  /// Contact for deletion / privacy requests.
  static const supportEmail = 'baekson777@gmail.com';

  static Uri get supportMailto => Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {
          'subject': '[미로미로해] 회원탈퇴 및 개인정보 삭제 요청',
        },
      );
}
