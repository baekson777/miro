import 'package:blind_weekly_maze/features/auth/domain/nickname_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NicknameRules', () {
    test('display trims and collapses spaces', () {
      expect(NicknameRules.display('  미로  고수  '), '미로 고수');
    });

    test('normalizeKey is case-insensitive for ascii', () {
      expect(NicknameRules.normalizeKey('MiRo'), 'miro');
      expect(
        NicknameRules.normalizeKey('미로A'),
        NicknameRules.normalizeKey('미로a'),
      );
    });

    test('validate length bounds', () {
      expect(NicknameRules.validate('a'), isNotNull);
      expect(NicknameRules.validate('ab'), isNull);
      expect(NicknameRules.validate('가' * 12), isNull);
      expect(NicknameRules.validate('가' * 13), isNotNull);
    });

    test('validate rejects empty', () {
      expect(NicknameRules.validate('   '), isNotNull);
    });
  });
}
