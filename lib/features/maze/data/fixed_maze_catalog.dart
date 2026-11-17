import '../domain/fixed_maze_definition.dart';
import '../domain/maze_grid.dart';
import 'fixed_mazes/fixed_maze_snapshots.dart';

/// Loads frozen ranked mazes from embedded snapshots (not the generator).
abstract final class FixedMazeCatalog {
  static const veryEasy001 = 'VERY_EASY-001';
  static const easy001 = 'EASY-001';
  static const normal001 = 'NORMAL-001';
  static const hard001 = 'HARD-001';
  static const veryHard001 = 'VERY_HARD-001';

  static const allIds = <String>[
    veryEasy001,
    easy001,
    normal001,
    hard001,
    veryHard001,
  ];

  static FixedMazeDefinition definition(String mazeId) {
    final raw = FixedMazeSnapshots.jsonFor(mazeId);
    if (raw == null) {
      throw StateError('Unknown fixed mazeId: $mazeId');
    }
    final def = FixedMazeDefinition.fromJsonString(raw);
    if (!def.checksumValid) {
      throw StateError('Checksum mismatch for $mazeId');
    }
    if (def.mazeId != mazeId) {
      throw StateError('mazeId mismatch: expected $mazeId got ${def.mazeId}');
    }
    return def;
  }

  static MazeGrid grid(String mazeId) => definition(mazeId).toMazeGrid();
}
