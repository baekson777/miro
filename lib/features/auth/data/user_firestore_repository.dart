import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/nickname_rules.dart';

/// Persists Kakao users under `users/{kakaoId}` and unique game nicknames
/// under `nicknames/{normalizedKey}`.
final class UserFirestoreRepository {
  UserFirestoreRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _nicknames =>
      _db.collection('nicknames');

  /// Login sync: never overwrites [gameNickname] with Kakao profile name.
  Future<void> upsertKakaoUser({
    required int kakaoId,
    required String kakaoNickname,
  }) async {
    final docId = kakaoId.toString();
    final ref = _users.doc(docId);

    debugPrint('[Firestore] upsert users/$docId …');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'kakaoId': kakaoId,
          'kakaoNickname': kakaoNickname,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'bestScore': 0,
        });
        debugPrint('[Firestore] created users/$docId (bestScore=0)');
      } else {
        tx.set(
          ref,
          {
            'kakaoId': kakaoId,
            'kakaoNickname': kakaoNickname,
            'lastLoginAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        debugPrint('[Firestore] merged users/$docId (gameNickname preserved)');
      }
    });
  }

  /// Claims a unique game nickname for [kakaoId].
  ///
  /// Throws [NicknameTakenException] when another account owns it.
  /// Returns the display nickname that was stored.
  Future<String> claimGameNickname({
    required int kakaoId,
    required String nickname,
  }) async {
    final error = NicknameRules.validate(nickname);
    if (error != null) {
      throw ArgumentError(error);
    }

    final display = NicknameRules.display(nickname);
    final key = NicknameRules.normalizeKey(display);
    final nickRef = _nicknames.doc(key);
    final userRef = _users.doc(kakaoId.toString());

    debugPrint('[Firestore] claim nickname "$display" (key=$key) for $kakaoId');

    await _db.runTransaction((tx) async {
      final nickSnap = await tx.get(nickRef);
      final userSnap = await tx.get(userRef);

      if (nickSnap.exists) {
        final owner = nickSnap.data()?['kakaoId'];
        if (owner != kakaoId) {
          throw const NicknameTakenException();
        }
      }

      final previous = userSnap.data()?['gameNickname'] as String?;
      final previousKey =
          previous == null || previous.isEmpty
              ? null
              : NicknameRules.normalizeKey(previous);

      DocumentReference<Map<String, dynamic>>? oldRef;
      DocumentSnapshot<Map<String, dynamic>>? oldSnap;
      if (previousKey != null && previousKey != key) {
        oldRef = _nicknames.doc(previousKey);
        oldSnap = await tx.get(oldRef);
      }

      tx.set(nickRef, {
        'kakaoId': kakaoId,
        'nickname': display,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (oldRef != null &&
          oldSnap != null &&
          oldSnap.exists &&
          oldSnap.data()?['kakaoId'] == kakaoId) {
        tx.delete(oldRef);
      }

      tx.set(
        userRef,
        {
          'kakaoId': kakaoId,
          'gameNickname': display,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    debugPrint('[Firestore] claimed nickname "$display" for $kakaoId');
    return display;
  }

  Future<String?> gameNicknameFor(int kakaoId) async {
    final snap = await _users.doc(kakaoId.toString()).get();
    final value = snap.data()?['gameNickname'] as String?;
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// True when [nickname] is free, or already owned by [kakaoId].
  Future<bool> isNicknameAvailable({
    required String nickname,
    int? kakaoId,
  }) async {
    final error = NicknameRules.validate(nickname);
    if (error != null) return false;
    final key = NicknameRules.normalizeKey(nickname);
    final snap = await _nicknames.doc(key).get();
    if (!snap.exists) return true;
    if (kakaoId == null) return false;
    return snap.data()?['kakaoId'] == kakaoId;
  }

  /// Deletes `users/{kakaoId}` and any nickname doc owned by this user.
  Future<void> deleteAccount(int kakaoId) async {
    final userRef = _users.doc(kakaoId.toString());
    debugPrint('[Firestore] deleteAccount users/$kakaoId …');

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      DocumentReference<Map<String, dynamic>>? nickRef;
      DocumentSnapshot<Map<String, dynamic>>? nickSnap;
      if (userSnap.exists) {
        final nick = userSnap.data()?['gameNickname'] as String?;
        if (nick != null && nick.trim().isNotEmpty) {
          nickRef = _nicknames.doc(NicknameRules.normalizeKey(nick));
          nickSnap = await tx.get(nickRef);
        }
      }

      if (nickRef != null &&
          nickSnap != null &&
          nickSnap.exists &&
          nickSnap.data()?['kakaoId'] == kakaoId) {
        tx.delete(nickRef);
      }
      if (userSnap.exists) {
        tx.delete(userRef);
      }
    });

    debugPrint('[Firestore] deleteAccount done users/$kakaoId');
  }
}
