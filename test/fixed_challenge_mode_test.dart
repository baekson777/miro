import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_catalog.dart';
import 'package:blind_weekly_maze/features/maze/data/weekly_seed_service.dart';
import 'package:blind_weekly_maze/features/maze/domain/difficulty.dart';
import 'package:blind_weekly_maze/features/maze/domain/fixed_maze_definition.dart';
import 'package:blind_weekly_maze/features/maze/domain/game_mode.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_grid.dart';
import 'package:blind_weekly_maze/features/maze/presentation/controllers/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CountingGenerator implements MazeGenerator {
  int calls = 0;

  @override
  MazeGrid generate({required int size, required int seed}) {
    calls += 1;
    return const DfsMazeGenerator().generate(size: size, seed: seed);
  }
}

void main() {
  const expectedChecksum = <String, String>{
    'VERY_EASY-001': '9b9728a3',
    'EASY-001': 'e28f730b',
    'NORMAL-001': 'b3096800',
    'HARD-001': '8fc021cc',
    'VERY_HARD-001': '172e0733',
  };

  group('FixedChallengeMode factories', () {
    test('five difficulties map to correct mazeId and boardKey', () {
      final veryEasy = FixedChallengeMode.veryEasy(sessionId: 's1');
      final easy = FixedChallengeMode.easy(sessionId: 's1');
      final normal = FixedChallengeMode.normal(sessionId: 's1');
      final hard = FixedChallengeMode.hard(sessionId: 's1');
      final veryHard = FixedChallengeMode.veryHard(sessionId: 's1');

      expect(veryEasy.mazeId, 'VERY_EASY-001');
      expect(veryEasy.boardKey, 'fixed_very_easy');
      expect(veryEasy.difficulty, Difficulty.veryEasy);

      expect(easy.mazeId, 'EASY-001');
      expect(easy.boardKey, 'fixed_easy');
      expect(easy.difficulty, Difficulty.easy);
      expect(easy.seedKey, 'fixed_easy');
      expect(easy.routeInstanceKey, 'fixed_easy#s1');
      expect(easy.rulesVersion, FixedMazeDefinition.rulesVersionV1);

      expect(normal.mazeId, 'NORMAL-001');
      expect(normal.boardKey, 'fixed_normal');
      expect(normal.seedKey, 'fixed_normal');

      expect(hard.mazeId, 'HARD-001');
      expect(hard.boardKey, 'fixed_hard');
      expect(hard.seedKey, 'fixed_hard');

      expect(veryHard.mazeId, 'VERY_HARD-001');
      expect(veryHard.boardKey, 'fixed_very_hard');
      expect(veryHard.difficulty, Difficulty.veryHard);
    });

    test('withFreshSession keeps mazeId, changes routeInstanceKey', () {
      final a = FixedChallengeMode.easy(sessionId: 'a');
      final b = a.withFreshSession();
      expect(b.mazeId, a.mazeId);
      expect(b.boardKey, a.boardKey);
      expect(b.seedKey, a.seedKey);
      expect(b.routeInstanceKey, isNot(a.routeInstanceKey));
    });
  });

  group('GameController fixed load', () {
    test('loads correct mazeId / checksum for each difficulty', () {
      for (final factory in [
        FixedChallengeMode.veryEasy,
        FixedChallengeMode.easy,
        FixedChallengeMode.normal,
        FixedChallengeMode.hard,
        FixedChallengeMode.veryHard,
      ]) {
        final mode = factory(sessionId: 't');
        final gen = _CountingGenerator();
        final c = GameController(mode: mode, generator: gen);
        expect(c.fixedMazeId, mode.mazeId);
        expect(c.fixedChecksum, expectedChecksum[mode.mazeId]);
        expect(c.usedProceduralGenerator, isFalse);
        expect(gen.calls, 0, reason: 'DfsMazeGenerator must not run for ${mode.mazeId}');
        expect(c.maze.size, mode.mazeSize);
        final def = FixedMazeCatalog.definition(mode.mazeId);
        expect(c.maze.start, def.start);
        expect(c.maze.exit, def.exit);
        expect(def.wallsEqualToGrid(c.maze), isTrue);
        c.dispose();
      }
    });

    test('restart with same mazeId yields identical checksum and walls', () {
      final firstMode = FixedChallengeMode.normal(sessionId: '1');
      final first = GameController(mode: firstMode);
      final checksum1 = first.fixedChecksum!;
      final snap1 = FixedMazeDefinition.fromMazeGrid(
        maze: first.maze,
        mazeId: first.fixedMazeId!,
        difficulty: firstMode.difficulty.name,
      );

      final retryMode = firstMode.withFreshSession();
      expect(retryMode.mazeId, firstMode.mazeId);
      final second = GameController(mode: retryMode);
      expect(second.fixedChecksum, checksum1);
      expect(second.fixedMazeId, first.fixedMazeId);
      expect(snap1.wallsEqualToGrid(second.maze), isTrue);
      expect(second.maze.start, first.maze.start);
      expect(second.maze.exit, first.maze.exit);

      first.dispose();
      second.dispose();
    });

    test('ResultScreen-style retry keeps checksum for all difficulties', () {
      for (final factory in [
        FixedChallengeMode.veryEasy,
        FixedChallengeMode.easy,
        FixedChallengeMode.normal,
        FixedChallengeMode.hard,
        FixedChallengeMode.veryHard,
      ]) {
        final mode = factory(sessionId: 'r1');
        final a = GameController(mode: mode);
        final retry = mode.withFreshSession();
        final b = GameController(mode: retry);
        expect(b.fixedMazeId, a.fixedMazeId);
        expect(b.fixedChecksum, a.fixedChecksum);
        expect(b.fixedChecksum, expectedChecksum[mode.mazeId]);
        a.dispose();
        b.dispose();
      }
    });

    test('unknown mazeId throws (no silent fallback)', () {
      final bad = FixedChallengeMode(
        difficulty: Difficulty.easy,
        mazeId: 'EASY-999',
        boardKey: 'fixed_easy',
        sessionId: 'x',
      );
      expect(
        () => GameController(mode: bad),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Practice / Weekly regression', () {
    test('PracticeMode still uses DfsMazeGenerator', () {
      final gen = _CountingGenerator();
      final mode = PracticeMode(difficulty: Difficulty.easy, seed: 42);
      final c = GameController(mode: mode, generator: gen);
      expect(gen.calls, 1);
      expect(c.usedProceduralGenerator, isTrue);
      expect(c.fixedMazeId, isNull);
      expect(c.maze.seed, 42);
      expect(c.maze.size, 15);
      c.dispose();
    });

    test('WeeklyChallengeMode still uses DfsMazeGenerator', () {
      final gen = _CountingGenerator();
      final weekId = WeeklySeedService.weekIdFor();
      final seed = WeeklySeedService.seedFromWeekId(weekId);
      final mode = WeeklyChallengeMode(weekId: weekId, seed: seed);
      final c = GameController(mode: mode, generator: gen);
      expect(gen.calls, 1);
      expect(c.usedProceduralGenerator, isTrue);
      expect(c.maze.seed, seed);
      expect(c.maze.size, 21);
      c.dispose();
    });

    test('PracticeMode seedKey and Weekly seedKey unchanged', () {
      final p = PracticeMode(difficulty: Difficulty.normal, seed: 7);
      expect(p.seedKey, 'practice_normal_7');
      expect(p.routeInstanceKey, p.seedKey);

      final w = WeeklyChallengeMode(weekId: '2026-W46', seed: 1);
      expect(w.seedKey, 'weekly_2026-W46');
      expect(w.routeInstanceKey, w.seedKey);
    });
  });
}
