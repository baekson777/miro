import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/fixed_board_keys.dart';
import '../domain/leaderboard_entry.dart';

/// Local leaderboard store. Swap implementation for a remote backend later.
///
/// Fixed boards share one prefs list (`lb_fixed_*`). Public vs admin rows are
/// separated by [LeaderboardEntry.isAdminTest] — not by different keys — so
/// sort/fairness rules stay identical while public rankings stay unpolluted.
final class LeaderboardRepository {
  LeaderboardRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _prefix = 'lb_';
  static const _devicePrefix = 'device_pb_';
  static const _nickKey = 'player_nickname';
  static const _idKey = 'player_id';

  /// Prefs key for a board (`lb_fixed_easy`, `lb_weekly_…`, …).
  static String storageKey(String boardKey) => '$_prefix$boardKey';

  /// Device-only personal best (guest / not on ranking).
  static String deviceBestKey(String boardKey, {bool adminTest = false}) =>
      '$_devicePrefix${adminTest ? 'admin_' : ''}$boardKey';

  Future<String> ensurePlayerId() async {
    final existing = _prefs.getString(_idKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _prefs.setString(_idKey, id);
    return id;
  }

  String? get nickname => _prefs.getString(_nickKey);

  Future<void> setNickname(String name) =>
      _prefs.setString(_nickKey, name.trim());

  Future<void> clearNickname() => _prefs.remove(_nickKey);

  /// Removes this player's rows from local boards and clears nickname.
  Future<void> clearAccountLocalData(String playerId) async {
    await clearNickname();
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) {
        final raw = _prefs.getStringList(key) ?? const <String>[];
        final kept = <String>[];
        for (final s in raw) {
          try {
            final e = LeaderboardEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
            if (e.playerId != playerId) kept.add(s);
          } catch (_) {
            kept.add(s);
          }
        }
        if (kept.length != raw.length) {
          await _prefs.setStringList(key, kept);
        }
      } else if (key.startsWith(_devicePrefix)) {
        final raw = _prefs.getString(key);
        if (raw == null) continue;
        try {
          final e = LeaderboardEntry.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (e.playerId == playerId) {
            await _prefs.remove(key);
          }
        } catch (_) {}
      }
    }
  }

  /// Raw list as stored (no fairness / admin filter).
  Future<List<LeaderboardEntry>> rawEntriesFor(String boardKey) async {
    final raw = _prefs.getStringList(storageKey(boardKey)) ?? const [];
    return raw
        .map((s) => LeaderboardEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList()
      ..sort();
  }

  /// Saves / improves a guest personal best on this device only.
  ///
  /// Never written into the public ranking lists (`lb_*`).
  Future<bool> saveDeviceBest(LeaderboardEntry entry) async {
    validateForSubmit(entry);
    final key = deviceBestKey(
      entry.boardKey,
      adminTest: entry.isAdminTestRecord,
    );
    final raw = _prefs.getString(key);
    if (raw != null) {
      final existing = LeaderboardEntry.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!LeaderboardEntry.isBetterRecord(entry, existing)) {
        return false;
      }
    }
    await _prefs.setString(key, jsonEncode(entry.toJson()));
    return true;
  }

  Future<LeaderboardEntry?> deviceBestFor(
    String boardKey, {
    bool adminTest = false,
  }) async {
    final raw = _prefs.getString(
      deviceBestKey(boardKey, adminTest: adminTest),
    );
    if (raw == null) return null;
    return LeaderboardEntry.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Upserts personal best for [entry.playerId] on this board (+ admin flag).
  ///
  /// Returns `true` when the board list changed (new row or improved PB).
  /// Worse / equal scores leave the stored personal best untouched.
  Future<bool> submit(LeaderboardEntry entry) async {
    validateForSubmit(entry);
    final list = await rawEntriesFor(entry.boardKey);
    final idx = list.indexWhere(
      (e) =>
          e.playerId == entry.playerId &&
          e.isAdminTestRecord == entry.isAdminTestRecord,
    );
    if (idx >= 0) {
      final existing = list[idx];
      if (!LeaderboardEntry.isBetterRecord(entry, existing)) {
        return false;
      }
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    list.sort();
    final encoded = list.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(storageKey(entry.boardKey), encoded);
    return true;
  }

  /// Public ranking (excludes admin test rows).
  Future<List<LeaderboardEntry>> entriesFor(String boardKey) async {
    return _filtered(boardKey, adminTestsOnly: false);
  }

  /// Admin playtest ranking only (same boardKey / sort rules).
  Future<List<LeaderboardEntry>> adminTestEntriesFor(String boardKey) async {
    return _filtered(boardKey, adminTestsOnly: true);
  }

  Future<List<LeaderboardEntry>> _filtered(
    String boardKey, {
    required bool adminTestsOnly,
  }) async {
    final list = await rawEntriesFor(boardKey);
    Iterable<LeaderboardEntry> scoped = list.where(
      (e) => adminTestsOnly ? e.isAdminTestRecord : !e.isAdminTestRecord,
    );
    if (!FixedBoardKeys.isFixed(boardKey)) {
      return scoped.toList()..sort();
    }
    final expectedMaze = FixedBoardKeys.mazeIdFor(boardKey)!;
    return scoped
        .where(
          (e) =>
              e.mazeId == expectedMaze &&
              e.rulesVersion == FixedBoardKeys.currentRulesVersion,
        )
        .toList()
      ..sort();
  }

  /// Rejects fixed-board submits that target the wrong maze/rules/board.
  static void validateForSubmit(LeaderboardEntry entry) {
    if (!FixedBoardKeys.isFixed(entry.boardKey)) return;

    final expectedMaze = FixedBoardKeys.mazeIdFor(entry.boardKey)!;
    if (entry.mazeId == null || entry.mazeId != expectedMaze) {
      throw ArgumentError(
        'Fixed board ${entry.boardKey} requires mazeId=$expectedMaze, '
        'got ${entry.mazeId}',
      );
    }
    if (entry.rulesVersion == null ||
        entry.rulesVersion != FixedBoardKeys.currentRulesVersion) {
      throw ArgumentError(
        'Fixed board ${entry.boardKey} requires '
        'rulesVersion=${FixedBoardKeys.currentRulesVersion}, '
        'got ${entry.rulesVersion}',
      );
    }
  }
}
