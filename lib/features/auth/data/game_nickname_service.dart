import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../leaderboard/data/leaderboard_repository.dart';
import '../domain/nickname_rules.dart';
import 'user_firestore_repository.dart';

/// Saves game nicknames locally and claims uniqueness on Firestore when logged in.
final class GameNicknameService {
  GameNicknameService({UserFirestoreRepository? users})
      : _users = users ?? UserFirestoreRepository();

  final UserFirestoreRepository _users;

  /// Validates + saves. When [kakaoId] is set, also claims on Firestore.
  ///
  /// Returns the stored display nickname.
  Future<String> save({
    required String nickname,
    int? kakaoId,
  }) async {
    final error = NicknameRules.validate(nickname);
    if (error != null) {
      throw ArgumentError(error);
    }

    final display = NicknameRules.display(nickname);

    if (kakaoId != null) {
      try {
        await _users.claimGameNickname(
          kakaoId: kakaoId,
          nickname: display,
        );
      } on NicknameTakenException {
        rethrow;
      } catch (e, st) {
        debugPrint('[Nick] Firestore claim failed: $e\n$st');
        rethrow;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await LeaderboardRepository(prefs).setNickname(display);
    return display;
  }
}
