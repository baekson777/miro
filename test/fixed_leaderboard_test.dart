import 'dart:convert';

import 'package:blind_weekly_maze/features/leaderboard/data/leaderboard_repository.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/fixed_board_keys.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:blind_weekly_maze/features/maze/domain/difficulty.dart';
import 'package:blind_weekly_maze/features/maze/domain/fixed_maze_definition.dart';
import 'package:blind_weekly_maze/features/maze/domain/game_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LeaderboardEntry _entry({
  required String playerId,
  required String boardKey,
  required double time,
  int hints = 0,
  String nickname = 'p',
  String? mazeId,
  String? rulesVersion,
}) {
  return LeaderboardEntry(
    playerId: playerId,
    nickname: nickname,
    elapsedSeconds: time,
    hintCount: hints,
    boardKey: boardKey,
    createdAt: DateTime.utc(2026, 11, 15),
    mazeId: mazeId,
    rulesVersion: rulesVersion,
  );
}

LeaderboardEntry _fixedSubmit({
  required FixedChallengeMode mode,
  required String playerId,
  required double time,
  int hints = 0,
  String nickname = 'runner',
}) {
  return _entry(
    playerId: playerId,
    boardKey: mode.boardKey,
    time: time,
    hints: hints,
    nickname: nickname,
    mazeId: mode.mazeId,
    rulesVersion: mode.rulesVersion,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('LeaderboardEntry JSON compat', () {
    test('legacy JSON without mazeId/rulesVersion parses', () {
      final json = <String, dynamic>{
        'playerId': 'a',
        'nickname': 'old',
        'elapsedSeconds': 12.34,
        'hintCount': 1,
        'boardKey': 'weekly_2026-W46',
        'createdAt': '2026-11-01T00:00:00.000Z',
      };
      final e = LeaderboardEntry.fromJson(json);
      expect(e.mazeId, isNull);
      expect(e.rulesVersion, isNull);
      expect(e.boardKey, 'weekly_2026-W46');
      expect(e.elapsedSeconds, 12.34);
    });

    test('mazeId/rulesVersion round-trip', () {
      final e = _entry(
        playerId: 'b',
        boardKey: FixedBoardKeys.easy,
        time: 9.5,
        mazeId: 'EASY-001',
        rulesVersion: FixedMazeDefinition.rulesVersionV1,
      );
      final again = LeaderboardEntry.fromJson(e.toJson());
      expect(again.mazeId, 'EASY-001');
      expect(again.rulesVersion, 'rules_v1');
      expect(again.boardKey, FixedBoardKeys.easy);
    });
  });

  group('Fixed board submit / storage keys', () {
    test('easy → lb_fixed_easy', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.easy(sessionId: '1');
      await repo.submit(_fixedSubmit(mode: mode, playerId: 'u1', time: 30));

      expect(prefs.containsKey(FixedBoardKeys.prefsKey(FixedBoardKeys.easy)), isTrue);
      expect(prefs.containsKey('lb_fixed_easy'), isTrue);
      final list = await repo.entriesFor(FixedBoardKeys.easy);
      expect(list, hasLength(1));
      expect(list.first.mazeId, 'EASY-001');
      expect(list.first.rulesVersion, 'rules_v1');
      expect(list.first.boardKey, 'fixed_easy');
    });

    test('normal → lb_fixed_normal', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.normal(sessionId: '1');
      await repo.submit(_fixedSubmit(mode: mode, playerId: 'u1', time: 40));

      expect(prefs.containsKey('lb_fixed_normal'), isTrue);
      final list = await repo.entriesFor(FixedBoardKeys.normal);
      expect(list.single.mazeId, 'NORMAL-001');
      expect(list.single.boardKey, 'fixed_normal');
    });

    test('hard → lb_fixed_hard', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.hard(sessionId: '1');
      await repo.submit(_fixedSubmit(mode: mode, playerId: 'u1', time: 55));

      expect(prefs.containsKey('lb_fixed_hard'), isTrue);
      final list = await repo.entriesFor(FixedBoardKeys.hard);
      expect(list.single.mazeId, 'HARD-001');
      expect(list.single.boardKey, 'fixed_hard');
    });

    test('three fixed boards do not mix', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      await repo.submit(
        _fixedSubmit(
          mode: FixedChallengeMode.easy(sessionId: '1'),
          playerId: 'e',
          time: 10,
          nickname: 'easy-runner',
        ),
      );
      await repo.submit(
        _fixedSubmit(
          mode: FixedChallengeMode.normal(sessionId: '1'),
          playerId: 'n',
          time: 20,
          nickname: 'normal-runner',
        ),
      );
      await repo.submit(
        _fixedSubmit(
          mode: FixedChallengeMode.hard(sessionId: '1'),
          playerId: 'h',
          time: 30,
          nickname: 'hard-runner',
        ),
      );

      final easy = await repo.entriesFor(FixedBoardKeys.easy);
      final normal = await repo.entriesFor(FixedBoardKeys.normal);
      final hard = await repo.entriesFor(FixedBoardKeys.hard);

      expect(easy.map((e) => e.nickname), ['easy-runner']);
      expect(normal.map((e) => e.nickname), ['normal-runner']);
      expect(hard.map((e) => e.nickname), ['hard-runner']);
      expect(easy.single.mazeId, 'EASY-001');
      expect(normal.single.mazeId, 'NORMAL-001');
      expect(hard.single.mazeId, 'HARD-001');
    });
  });

  group('Legacy weekly / practice preservation', () {
    test('existing weekly key and data stay intact after fixed submit', () async {
      const weeklyKey = 'weekly_2026-W46';
      final legacy = _entry(
        playerId: 'w1',
        boardKey: weeklyKey,
        time: 11.1,
        nickname: 'weekly-hero',
      );
      SharedPreferences.setMockInitialValues({
        LeaderboardRepository.storageKey(weeklyKey): [
          jsonEncode(legacy.toJson()),
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);

      await repo.submit(
        _fixedSubmit(
          mode: FixedChallengeMode.easy(sessionId: '1'),
          playerId: 'f1',
          time: 9,
        ),
      );

      expect(prefs.getStringList('lb_weekly_2026-W46'), isNotNull);
      final weekly = await repo.entriesFor(weeklyKey);
      expect(weekly, hasLength(1));
      expect(weekly.single.nickname, 'weekly-hero');
      expect(weekly.single.mazeId, isNull);
    });

    test('existing practice key and data stay intact after fixed submit',
        () async {
      const practiceKey = 'practice_easy_42';
      final legacy = _entry(
        playerId: 'p1',
        boardKey: practiceKey,
        time: 8.8,
        nickname: 'practice-hero',
      );
      SharedPreferences.setMockInitialValues({
        LeaderboardRepository.storageKey(practiceKey): [
          jsonEncode(legacy.toJson()),
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);

      await repo.submit(
        _fixedSubmit(
          mode: FixedChallengeMode.normal(sessionId: '1'),
          playerId: 'f1',
          time: 15,
        ),
      );

      expect(prefs.getStringList('lb_practice_easy_42'), isNotNull);
      final practice = await repo.entriesFor(practiceKey);
      expect(practice.single.nickname, 'practice-hero');
      expect(prefs.containsKey('lb_fixed_normal'), isTrue);
    });
  });

  group('Fairness validation', () {
    test('wrong mazeId on fixed board is rejected', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      await expectLater(
        repo.submit(
          _entry(
            playerId: 'x',
            boardKey: FixedBoardKeys.easy,
            time: 1,
            mazeId: 'HARD-001',
            rulesVersion: FixedBoardKeys.currentRulesVersion,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(prefs.containsKey('lb_fixed_easy'), isFalse);
    });

    test('missing mazeId/rulesVersion on fixed board is rejected', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      await expectLater(
        repo.submit(
          _entry(
            playerId: 'x',
            boardKey: FixedBoardKeys.easy,
            time: 1,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('wrong rulesVersion is hidden from current ranking view', () async {
      final prefs = await SharedPreferences.getInstance();
      // Bypass validate by writing raw prefs (simulates old rules snapshot).
      final stale = _entry(
        playerId: 'old',
        boardKey: FixedBoardKeys.easy,
        time: 5,
        mazeId: 'EASY-001',
        rulesVersion: 'rules_v0',
        nickname: 'stale',
      );
      final current = _entry(
        playerId: 'new',
        boardKey: FixedBoardKeys.easy,
        time: 6,
        mazeId: 'EASY-001',
        rulesVersion: FixedBoardKeys.currentRulesVersion,
        nickname: 'fresh',
      );
      await prefs.setStringList('lb_fixed_easy', [
        jsonEncode(stale.toJson()),
        jsonEncode(current.toJson()),
      ]);

      final repo = LeaderboardRepository(prefs);
      final visible = await repo.entriesFor(FixedBoardKeys.easy);
      expect(visible.map((e) => e.nickname), ['fresh']);
      final raw = await repo.rawEntriesFor(FixedBoardKeys.easy);
      expect(raw, hasLength(2));
    });

    test('wrong mazeId stored under board is filtered out of view', () async {
      final prefs = await SharedPreferences.getInstance();
      final wrong = _entry(
        playerId: 'bad',
        boardKey: FixedBoardKeys.easy,
        time: 3,
        mazeId: 'NORMAL-001',
        rulesVersion: FixedBoardKeys.currentRulesVersion,
        nickname: 'intruder',
      );
      await prefs.setStringList('lb_fixed_easy', [jsonEncode(wrong.toJson())]);
      final repo = LeaderboardRepository(prefs);
      expect(await repo.entriesFor(FixedBoardKeys.easy), isEmpty);
    });
  });

  group('Sort order', () {
    test('hints ASC then time ASC', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.easy(sessionId: '1');
      await repo.submit(
        _fixedSubmit(mode: mode, playerId: 'a', time: 10, hints: 2, nickname: 'a'),
      );
      await repo.submit(
        _fixedSubmit(mode: mode, playerId: 'b', time: 9, hints: 5, nickname: 'b'),
      );
      await repo.submit(
        _fixedSubmit(mode: mode, playerId: 'c', time: 10, hints: 0, nickname: 'c'),
      );

      final list = await repo.entriesFor(FixedBoardKeys.easy);
      // 0 hints (c) → 2 hints (a) → 5 hints (b)
      expect(list.map((e) => e.nickname).toList(), ['c', 'a', 'b']);
    });
  });

  group('Practice / Weekly submit regression', () {
    test('PracticeMode still uses seedKey board without maze fields', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = PracticeMode(difficulty: Difficulty.easy, seed: 99);
      await repo.submit(
        _entry(
          playerId: 'p',
          boardKey: mode.seedKey,
          time: 7,
          nickname: 'prac',
        ),
      );
      expect(mode.seedKey, 'practice_easy_99');
      expect(prefs.containsKey('lb_practice_easy_99'), isTrue);
      expect(prefs.containsKey('lb_fixed_easy'), isFalse);
      final list = await repo.entriesFor(mode.seedKey);
      expect(list.single.mazeId, isNull);
      expect(list.single.rulesVersion, isNull);
    });

    test('WeeklyChallengeMode still uses weekly_ board', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      const weekId = '2026-W46';
      final mode = WeeklyChallengeMode(weekId: weekId, seed: 1);
      await repo.submit(
        _entry(
          playerId: 'w',
          boardKey: mode.seedKey,
          time: 12,
          nickname: 'week',
        ),
      );
      expect(mode.seedKey, 'weekly_2026-W46');
      expect(prefs.containsKey('lb_weekly_2026-W46'), isTrue);
      for (final k in FixedBoardKeys.all) {
        expect(prefs.containsKey(FixedBoardKeys.prefsKey(k)), isFalse);
      }
    });
  });

  group('ResultScreen-style fixed entry builder contract', () {
    test('FixedChallengeMode maps boardKey/mazeId/rulesVersion correctly', () {
      for (final mode in [
        FixedChallengeMode.easy(sessionId: 's'),
        FixedChallengeMode.normal(sessionId: 's'),
        FixedChallengeMode.hard(sessionId: 's'),
      ]) {
        final entry = _fixedSubmit(mode: mode, playerId: 'u', time: 1);
        expect(entry.boardKey, mode.boardKey);
        expect(entry.mazeId, mode.mazeId);
        expect(entry.rulesVersion, FixedMazeDefinition.rulesVersionV1);
        LeaderboardRepository.validateForSubmit(entry);
      }
    });
  });

  group('Guest device-only personal best', () {
    test('saveDeviceBest does not appear on public ranking', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.easy(sessionId: 's');
      final entry = _fixedSubmit(
        mode: mode,
        playerId: 'guest-device',
        time: 10,
        nickname: 'guest',
      );

      final saved = await repo.saveDeviceBest(entry);
      expect(saved, isTrue);
      expect(prefs.containsKey(LeaderboardRepository.storageKey(mode.boardKey)), isFalse);
      expect(
        prefs.containsKey(
          LeaderboardRepository.deviceBestKey(mode.boardKey),
        ),
        isTrue,
      );

      final public = await repo.entriesFor(mode.boardKey);
      expect(public, isEmpty);

      final device = await repo.deviceBestFor(mode.boardKey);
      expect(device?.nickname, 'guest');
      expect(device?.elapsedSeconds, 10);
    });

    test('device best keeps better PB only', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = LeaderboardRepository(prefs);
      final mode = FixedChallengeMode.normal(sessionId: 's');
      await repo.saveDeviceBest(
        _fixedSubmit(mode: mode, playerId: 'g', time: 20, hints: 1),
      );
      final worse = await repo.saveDeviceBest(
        _fixedSubmit(mode: mode, playerId: 'g', time: 25, hints: 1),
      );
      final better = await repo.saveDeviceBest(
        _fixedSubmit(mode: mode, playerId: 'g', time: 18, hints: 0),
      );
      expect(worse, isFalse);
      expect(better, isTrue);
      final device = await repo.deviceBestFor(mode.boardKey);
      expect(device?.hintCount, 0);
      expect(device?.elapsedSeconds, 18);
    });
  });
}
