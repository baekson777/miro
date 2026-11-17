import 'dart:convert';

import 'package:blind_weekly_maze/core/constants/route_paths.dart';
import 'package:blind_weekly_maze/features/admin/presentation/screens/admin_maze_preview_screen.dart';
import 'package:blind_weekly_maze/features/leaderboard/data/leaderboard_repository.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/fixed_board_keys.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_catalog.dart';
import 'package:blind_weekly_maze/features/maze/domain/game_mode.dart';
import 'package:blind_weekly_maze/features/maze/presentation/controllers/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LeaderboardEntry _public({
  required String playerId,
  required String boardKey,
  required String mazeId,
  required double time,
  String nickname = 'user',
}) {
  return LeaderboardEntry(
    playerId: playerId,
    nickname: nickname,
    elapsedSeconds: time,
    hintCount: 0,
    boardKey: boardKey,
    mazeId: mazeId,
    rulesVersion: FixedBoardKeys.currentRulesVersion,
  );
}

LeaderboardEntry _admin({
  required String playerId,
  required FixedChallengeMode mode,
  required double time,
  String nickname = 'admin',
  int hints = 0,
}) {
  return LeaderboardEntry(
    playerId: playerId,
    nickname: nickname,
    elapsedSeconds: time,
    hintCount: hints,
    boardKey: mode.boardKey,
    mazeId: mode.mazeId,
    rulesVersion: mode.rulesVersion,
    isAdminTest: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('admin playtest mode', () {
    test('factories mark isAdminTest and keep catalog mazeIds', () {
      final easy = FixedChallengeMode.easy(isAdminTest: true, sessionId: '1');
      final normal =
          FixedChallengeMode.normal(isAdminTest: true, sessionId: '1');
      final hard = FixedChallengeMode.hard(isAdminTest: true, sessionId: '1');

      expect(easy.isAdminTest, isTrue);
      expect(easy.mazeId, FixedMazeCatalog.easy001);
      expect(easy.boardKey, FixedBoardKeys.easy);
      expect(normal.mazeId, FixedMazeCatalog.normal001);
      expect(hard.mazeId, FixedMazeCatalog.hard001);
      expect(easy.withFreshSession().isAdminTest, isTrue);
    });

    test('GameController loads same snapshot for admin and public fixed mode',
        () {
      final public = GameController(
        mode: FixedChallengeMode.easy(sessionId: 'p'),
      );
      final admin = GameController(
        mode: FixedChallengeMode.easy(sessionId: 'a', isAdminTest: true),
      );
      expect(admin.fixedMazeId, public.fixedMazeId);
      expect(admin.fixedChecksum, public.fixedChecksum);
      expect(admin.maze.start, public.maze.start);
      expect(admin.maze.exit, public.maze.exit);
      expect(admin.usedProceduralGenerator, isFalse);
      public.dispose();
      admin.dispose();
    });
  });

  group('ranking separation', () {
    test('admin submit does not appear in public entriesFor', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.easy(isAdminTest: true, sessionId: '1');

      await repo.submit(
        _public(
          playerId: 'u1',
          boardKey: FixedBoardKeys.easy,
          mazeId: 'EASY-001',
          time: 20,
          nickname: 'public-user',
        ),
      );
      await repo.submit(
        _admin(playerId: 'u1', mode: mode, time: 10, nickname: 'admin-tester'),
      );

      final public = await repo.entriesFor(FixedBoardKeys.easy);
      final admin = await repo.adminTestEntriesFor(FixedBoardKeys.easy);

      expect(public.map((e) => e.nickname), ['public-user']);
      expect(admin.map((e) => e.nickname), ['admin-tester']);
      expect(public.single.isAdminTestRecord, isFalse);
      expect(admin.single.isAdminTestRecord, isTrue);
      // Same storage key — data coexists.
      expect(prefs.containsKey('lb_fixed_easy'), isTrue);
      expect(await repo.rawEntriesFor(FixedBoardKeys.easy), hasLength(2));
    });

    test('legacy public JSON without isAdminTest stays public', () async {
      final legacy = _public(
        playerId: 'legacy',
        boardKey: FixedBoardKeys.normal,
        mazeId: 'NORMAL-001',
        time: 33,
        nickname: 'legacy-user',
      );
      final json = legacy.toJson()..remove('isAdminTest');
      SharedPreferences.setMockInitialValues({
        'lb_fixed_normal': [jsonEncode(json)],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);

      final parsed = LeaderboardEntry.fromJson(json);
      expect(parsed.isAdminTest, isNull);
      expect(parsed.isAdminTestRecord, isFalse);

      final public = await repo.entriesFor(FixedBoardKeys.normal);
      final admin = await repo.adminTestEntriesFor(FixedBoardKeys.normal);
      expect(public.single.nickname, 'legacy-user');
      expect(admin, isEmpty);
    });

    test('admin and public scores for same playerId coexist', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.hard(isAdminTest: true, sessionId: '1');
      await repo.submit(
        _public(
          playerId: 'same',
          boardKey: FixedBoardKeys.hard,
          mazeId: 'HARD-001',
          time: 50,
        ),
      );
      await repo.submit(_admin(playerId: 'same', mode: mode, time: 40));
      expect(await repo.entriesFor(FixedBoardKeys.hard), hasLength(1));
      expect(await repo.adminTestEntriesFor(FixedBoardKeys.hard), hasLength(1));
    });

    test('admin ranking sorts by hints ASC then time ASC', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.easy(isAdminTest: true, sessionId: '1');
      await repo.submit(
        _admin(playerId: 'a', mode: mode, time: 12, hints: 2, nickname: 'a'),
      );
      await repo.submit(
        _admin(playerId: 'b', mode: mode, time: 11, hints: 5, nickname: 'b'),
      );
      await repo.submit(
        _admin(playerId: 'c', mode: mode, time: 12, hints: 0, nickname: 'c'),
      );
      final list = await repo.adminTestEntriesFor(FixedBoardKeys.easy);
      expect(list.map((e) => e.nickname).toList(), ['c', 'a', 'b']);
    });

    test('existing public rows survive admin submits (no wipe)', () async {
      SharedPreferences.setMockInitialValues({
        'lb_fixed_easy': [
          jsonEncode(
            _public(
              playerId: 'keep',
              boardKey: FixedBoardKeys.easy,
              mazeId: 'EASY-001',
              time: 18,
              nickname: 'keep-me',
            ).toJson(),
          ),
        ],
        'lb_weekly_2026-W46': [
          jsonEncode(
            LeaderboardEntry(
              playerId: 'w',
              nickname: 'week',
              elapsedSeconds: 9,
              hintCount: 0,
              boardKey: 'weekly_2026-W46',
            ).toJson(),
          ),
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      await repo.submit(
        _admin(
          playerId: 'admin',
          mode: FixedChallengeMode.easy(isAdminTest: true, sessionId: '1'),
          time: 7,
        ),
      );

      expect(
        (await repo.entriesFor(FixedBoardKeys.easy)).single.nickname,
        'keep-me',
      );
      expect(
        (await repo.entriesFor('weekly_2026-W46')).single.nickname,
        'week',
      );
      expect(prefs.getStringList('lb_weekly_2026-W46'), isNotNull);
    });
  });

  group('admin preview UI actions', () {
    testWidgets('shows play and exit controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminMazePreviewScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('이 미로 플레이하기'), findsOneWidget);
      expect(find.text('관리자 모드 나가기'), findsWidgets);
      expect(find.text('관리자 테스트 랭킹 보기'), findsOneWidget);
      expect(RoutePaths.adminMazePreview, '/admin/maze-preview');
    });
  });
}
