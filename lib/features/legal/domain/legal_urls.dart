/// Public / in-app addresses for Play Console & My Info.
///
/// Host the HTML under your domain (GitHub Pages, Firebase Hosting, etc.):
/// - Privacy: `{origin}/docs/legal/privacy.html`
/// - Account deletion: `{origin}/docs/legal/account-deletion.html`
abstract final class LegalUrls {
  /// In-app GoRouter paths.
  static const privacyPolicyPath = '/legal/privacy';
  static const termsPath = '/legal/terms';
  static const accountDeletionPath = '/legal/account-deletion';

  /// Relative web paths (repo `docs/legal/`).
  static const privacyPolicyWebPath = 'docs/legal/privacy.html';
  static const accountDeletionWebPath = 'docs/legal/account-deletion.html';

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
