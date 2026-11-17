enum LegalDocumentType { privacyPolicy, terms, accountDeletion }

enum LegalLanguage { ko, en }

extension LegalDocumentTypeX on LegalDocumentType {
  String title(LegalLanguage lang) => switch (this) {
        LegalDocumentType.privacyPolicy =>
          lang == LegalLanguage.ko ? '개인정보 처리방침' : 'Privacy Policy',
        LegalDocumentType.terms =>
          lang == LegalLanguage.ko ? '이용약관' : 'Terms & Conditions',
        LegalDocumentType.accountDeletion => lang == LegalLanguage.ko
            ? '연동 회원탈퇴 안내'
            : 'Account Deletion Guide',
      };

  String assetPath(LegalLanguage lang) => switch (this) {
        LegalDocumentType.privacyPolicy => lang == LegalLanguage.ko
            ? 'assets/legal/privacy_policy_ko.md'
            : 'assets/legal/privacy_policy_en.md',
        LegalDocumentType.terms => lang == LegalLanguage.ko
            ? 'assets/legal/terms_ko.md'
            : 'assets/legal/terms_en.md',
        LegalDocumentType.accountDeletion => lang == LegalLanguage.ko
            ? 'assets/legal/account_deletion_ko.md'
            : 'assets/legal/account_deletion_en.md',
      };
}
