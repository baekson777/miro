import 'dart:convert';

import 'package:blind_weekly_maze/features/leaderboard/data/leaderboard_repository.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/fixed_board_keys.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LeaderboardEntry _e({
  required String playerId,
  required String boardKey,
  required double time,
  required int hints,
  String nickname = 'n',
  String? mazeId,
  bool? isAdminTest,
  DateTime? createdAt,
}) {
  return LeaderboardEntry(
    playerId: playerId,
    nickname: nickname,
    elapsedSeconds: time,
    hintCount: hints,
    boardKey: boardKey,
    createdAt: createdAt ?? DateTime.utc(2026, 11, 15),
    mazeId: mazeId ?? FixedBoardKeys.mazeIdFor(boardKey),
    rulesVersion: FixedBoardKeys.isFixed(boardKey)
        ? FixedBoardKeys.currentRulesVersion
        : null,
    isAdminTest: isAdminTest,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('player identity', () {
    test('ensurePlayerId persists a stable UUID across calls', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final a = await repo.ensurePlayerId();
      final b = await repo.ensurePlayerId();
      expect(a, isNotEmpty);
      expect(a, b);
      expect(prefs.getString('player_id'), a);
    });
  });

  group('official ranking order (hints then time)', () {
    test('A 23s/0 → B 21s/1 → C 22s/3 → D 25s/3', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.easy;
      await repo.submit(
        _e(playerId: 'd', boardKey: board, time: 25, hints: 3, nickname: 'D'),
      );
      await repo.submit(
        _e(playerId: 'b', boardKey: board, time: 21, hints: 1, nickname: 'B'),
      );
      await repo.submit(
        _e(playerId: 'c', boardKey: board, time: 22, hints: 3, nickname: 'C'),
      );
      await repo.submit(
        _e(playerId: 'a', boardKey: board, time: 23, hints: 0, nickname: 'A'),
      );

      final list = await repo.entriesFor(board);
      expect(list.map((e) => e.nickname).toList(), ['A', 'B', 'C', 'D']);
    });

    test('0-hint always ranks above hinted even if slower', () {
      final zero = _e(
        playerId: 'a',
        boardKey: FixedBoardKeys.easy,
        time: 23,
        hints: 0,
      );
      final hinted = _e(
        playerId: 'b',
        boardKey: FixedBoardKeys.easy,
        time: 21,
        hints: 1,
      );
      expect(zero.compareTo(hinted), lessThan(0));
      expect(LeaderboardEntry.isBetterRecord(hinted, zero), isFalse);
    });
  });

  group('personal best update', () {
    test('23s/0 vs 22s/3 → keep 23s/0', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.easy;
      final kept = await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 23, hints: 0),
      );
      final rejected = await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 22, hints: 3),
      );
      expect(kept, isTrue);
      expect(rejected, isFalse);
      final list = await repo.entriesFor(board);
      expect(list.single.elapsedSeconds, 23);
      expect(list.single.hintCount, 0);
    });

    test('23s/0 vs 21s/0 → update to 21s/0', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.easy;
      await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 23, hints: 0),
      );
      final updated = await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 21, hints: 0),
      );
      expect(updated, isTrue);
      final list = await repo.entriesFor(board);
      expect(list.single.elapsedSeconds, 21);
      expect(list.single.hintCount, 0);
    });

    test('23s/1 vs 22s/1 → update to 22s/1', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.normal;
      await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 23, hints: 1),
      );
      final updated = await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 22, hints: 1),
      );
      expect(updated, isTrue);
      expect((await repo.entriesFor(board)).single.elapsedSeconds, 22);
    });

    test('21s/2 vs 23s/1 → keep 23s/1 (fewer hints wins)', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.hard;
      await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 23, hints: 1),
      );
      final rejected = await repo.submit(
        _e(playerId: 'p', boardKey: board, time: 21, hints: 2),
      );
      expect(rejected, isFalse);
      final best = (await repo.entriesFor(board)).single;
      expect(best.elapsedSeconds, 23);
      expect(best.hintCount, 1);
    });

    test('identical hint+time keeps existing record', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.easy;
      final firstAt = DateTime.utc(2026, 1, 1);
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: board,
          time: 20,
          hints: 0,
          nickname: 'first',
          createdAt: firstAt,
        ),
      );
      final same = await repo.submit(
        _e(
          playerId: 'p',
          boardKey: board,
          time: 20,
          hints: 0,
          nickname: 'second',
          createdAt: DateTime.utc(2026, 2, 1),
        ),
      );
      expect(same, isFalse);
      final best = (await repo.entriesFor(board)).single;
      expect(best.nickname, 'first');
      expect(best.createdAt, firstAt);
    });
  });

  group('difficulty independence', () {
    test('easy PB does not affect normal/hard', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: FixedBoardKeys.easy,
          time: 15,
          hints: 0,
          nickname: 'easy',
        ),
      );
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: FixedBoardKeys.normal,
          time: 40,
          hints: 1,
          nickname: 'normal',
        ),
      );
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: FixedBoardKeys.hard,
          time: 60,
          hints: 2,
          nickname: 'hard',
        ),
      );

      expect(
        (await repo.entriesFor(FixedBoardKeys.easy)).single.nickname,
        'easy',
      );
      expect(
        (await repo.entriesFor(FixedBoardKeys.normal)).single.nickname,
        'normal',
      );
      expect(
        (await repo.entriesFor(FixedBoardKeys.hard)).single.nickname,
        'hard',
      );
    });
  });

  group('admin vs public separation with new policy', () {
    test('admin PB sort/update does not pollute public ranking', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const board = FixedBoardKeys.easy;
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: board,
          time: 23,
          hints: 0,
          nickname: 'public',
        ),
      );
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: board,
          time: 10,
          hints: 0,
          nickname: 'admin',
          isAdminTest: true,
        ),
      );
      // Worse admin run must not overwrite admin PB, nor public.
      await repo.submit(
        _e(
          playerId: 'p',
          boardKey: board,
          time: 9,
          hints: 2,
          nickname: 'admin-worse',
          isAdminTest: true,
        ),
      );

      final public = await repo.entriesFor(board);
      final admin = await repo.adminTestEntriesFor(board);
      expect(public.single.nickname, 'public');
      expect(admin.single.nickname, 'admin');
      expect(admin.single.elapsedSeconds, 10);
    });
  });

  group('persistence across re-open', () {
    test('records survive new repository instance (app relaunch)', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      var repo = LeaderboardRepository(prefs);
      final id = await repo.ensurePlayerId();
      await repo.submit(
        _e(
          playerId: id,
          boardKey: FixedBoardKeys.easy,
          time: 23,
          hints: 0,
          nickname: 'persist',
        ),
      );

      // Simulate relaunch: same prefs backing store, new repo.
      prefs = await SharedPreferences.getInstance();
      repo = LeaderboardRepository(prefs);
      expect(await repo.ensurePlayerId(), id);
      final list = await repo.entriesFor(FixedBoardKeys.easy);
      expect(list.single.nickname, 'persist');
      expect(list.single.hintCount, 0);

      // Raw JSON still present under lb_fixed_easy.
      expect(prefs.getStringList('lb_fixed_easy'), isNotNull);
      expect(
        jsonDecode(prefs.getStringList('lb_fixed_easy')!.single)
            as Map<String, dynamic>,
        containsPair('nickname', 'persist'),
      );
    });
  });
}
