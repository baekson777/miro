import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_catalog.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_path.dart';
import 'package:blind_weekly_maze/features/maze/domain/fixed_maze_definition.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expected = <String, ({int size, int seed, GridPos start, GridPos exit, int shortest, String checksum})>{
    'EASY-001': (
      size: 15,
      seed: 1009,
      start: GridPos(0, 0),
      exit: GridPos(14, 14),
      shortest: 30,
      checksum: 'e28f730b',
    ),
    'NORMAL-001': (
      size: 21,
      seed: 2013,
      start: GridPos(0, 0),
      exit: GridPos(20, 20),
      shortest: 44,
      checksum: 'b3096800',
    ),
    'HARD-001': (
      size: 27,
      seed: 3045,
      start: GridPos(0, 0),
      exit: GridPos(26, 19),
      shortest: 59,
      checksum: '8fc021cc',
    ),
  };

  test('catalog loads three frozen mazes with valid checksums', () {
    expect(FixedMazeCatalog.allIds, expected.keys.toList());
    for (final id in FixedMazeCatalog.allIds) {
      final def = FixedMazeCatalog.definition(id);
      final exp = expected[id]!;
      expect(def.checksumValid, isTrue, reason: id);
      expect(def.checksum, exp.checksum, reason: id);
      expect(def.size, exp.size);
      expect(def.seedUsed, exp.seed);
      expect(def.start, exp.start);
      expect(def.exit, exp.exit);
      expect(def.generatorVersion,
          FixedMazeDefinition.generatorVersionGrowingTreeV1);
      expect(def.rulesVersion, FixedMazeDefinition.rulesVersionV1);
    }
  });

  test('snapshot walls match generator output at freeze seeds', () {
    const gen = DfsMazeGenerator();
    for (final id in FixedMazeCatalog.allIds) {
      final def = FixedMazeCatalog.definition(id);
      final exp = expected[id]!;
      final original = gen.generate(size: exp.size, seed: exp.seed);
      expect(def.wallsEqualToGrid(original), isTrue, reason: id);
    }
  });

  test('BFS shortest paths are 30 / 44 / 59', () {
    for (final id in FixedMazeCatalog.allIds) {
      final grid = FixedMazeCatalog.grid(id);
      final len = FixedMazePath.shortestLength(grid);
      expect(len, expected[id]!.shortest, reason: id);
      expect(len, greaterThan(0), reason: '$id reachable');
    }
  });

  test('reload is stable (idempotent walls)', () {
    for (final id in FixedMazeCatalog.allIds) {
      final a = FixedMazeCatalog.definition(id);
      final b = FixedMazeDefinition.fromJsonString(a.toJsonString());
      expect(b.checksum, a.checksum);
      expect(b.wallsEqualToGrid(a.toMazeGrid()), isTrue);
    }
  });

  test('checksum ignores JSON key order (canonical walls payload)', () {
    final def = FixedMazeCatalog.definition('EASY-001');
    final scrambled = {
      'rulesVersion': def.rulesVersion,
      'checksum': def.checksum,
      'cells': def.toJson()['cells'],
      'exit': {'col': def.exit.col, 'row': def.exit.row},
      'start': {'col': def.start.col, 'row': def.start.row},
      'generatorVersion': def.generatorVersion,
      'seedUsed': def.seedUsed,
      'size': def.size,
      'difficulty': def.difficulty,
      'mazeId': def.mazeId,
    };
    final loaded = FixedMazeDefinition.fromJson(scrambled);
    expect(loaded.checksumValid, isTrue);
    expect(loaded.checksum, def.checksum);
  });
}
