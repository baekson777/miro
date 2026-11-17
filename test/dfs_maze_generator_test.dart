import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/data/weekly_seed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DfsMazeGenerator', () {
    test('same seed + size → identical wall layout', () {
      const gen = DfsMazeGenerator();
      final a = gen.generate(size: 15, seed: 42);
      final b = gen.generate(size: 15, seed: 42);

      expect(a.size, b.size);
      expect(a.start, b.start);
      expect(a.exit, b.exit);
      for (var r = 0; r < a.size; r++) {
        for (var c = 0; c < a.size; c++) {
          expect(a.cells[r][c], b.cells[r][c], reason: 'cell ($r,$c)');
        }
      }
    });

    test('different seeds diverge', () {
      const gen = DfsMazeGenerator();
      final a = gen.generate(size: 15, seed: 1);
      final b = gen.generate(size: 15, seed: 2);
      var same = true;
      for (var r = 0; r < a.size && same; r++) {
        for (var c = 0; c < a.size && same; c++) {
          if (a.cells[r][c] != b.cells[r][c]) same = false;
        }
      }
      expect(same, isFalse);
    });

    test('dense dead ends on 15×15', () {
      const gen = DfsMazeGenerator();
      final maze = gen.generate(size: 15, seed: 7);
      final dead = DfsMazeGenerator.countDeadEnds(maze);
      // Prim-biased growing tree should produce many cul-de-sacs.
      expect(dead, greaterThanOrEqualTo(20));
      expect(maze.exit, isNot(maze.start));
    });
  });

  group('WeeklySeedService', () {
    test('week id format YYYY-Www', () {
      WeeklySeedService.ensureInitialized();
      final id = WeeklySeedService.weekIdFor(DateTime.utc(2026, 11, 9));
      expect(id, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('same week id → same seed', () {
      final s1 = WeeklySeedService.seedFromWeekId('2026-W46');
      final s2 = WeeklySeedService.seedFromWeekId('2026-W46');
      expect(s1, s2);
    });
  });
}
