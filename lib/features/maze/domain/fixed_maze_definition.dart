import 'dart:convert';

import 'maze_cell.dart';
import 'maze_grid.dart';

/// Frozen maze snapshot for ranked fixed challenges.
///
/// Runtime play should load this dump — do **not** regenerate from [seedUsed]
/// once the generator may change.
final class FixedMazeDefinition {
  const FixedMazeDefinition({
    required this.mazeId,
    required this.difficulty,
    required this.size,
    required this.seedUsed,
    required this.generatorVersion,
    required this.start,
    required this.exit,
    required this.cells,
    required this.checksum,
    required this.rulesVersion,
  });

  static const String generatorVersionGrowingTreeV1 =
      'growing_tree_v1_bias0.88';
  static const String rulesVersionV1 = 'rules_v1';

  final String mazeId;
  final String difficulty; // easy | normal | hard
  final int size;
  final int seedUsed;
  final String generatorVersion;
  final GridPos start;
  final GridPos exit;

  /// Wall flags only: [row][col] = {n,e,s,w}. No visited.
  final List<List<FixedMazeCellWalls>> cells;
  final String checksum;
  final String rulesVersion;

  /// Canonical payload for checksum (order-stable, whitespace-free).
  static String canonicalPayload({
    required int size,
    required GridPos start,
    required GridPos exit,
    required List<List<FixedMazeCellWalls>> cells,
  }) {
    final buf = StringBuffer()
      ..write(size)
      ..write('|')
      ..write(start.row)
      ..write(',')
      ..write(start.col)
      ..write('|')
      ..write(exit.row)
      ..write(',')
      ..write(exit.col)
      ..write('|');
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (r != 0 || c != 0) buf.write(';');
        buf.write(cells[r][c].canonical);
      }
    }
    return buf.toString();
  }

  /// FNV-1a 32-bit hex (8 chars) over [canonicalPayload].
  static String computeChecksum({
    required int size,
    required GridPos start,
    required GridPos exit,
    required List<List<FixedMazeCellWalls>> cells,
  }) {
    final payload = canonicalPayload(
      size: size,
      start: start,
      exit: exit,
      cells: cells,
    );
    const prime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  factory FixedMazeDefinition.fromMazeGrid({
    required MazeGrid maze,
    required String mazeId,
    required String difficulty,
    String generatorVersion = generatorVersionGrowingTreeV1,
    String rulesVersion = rulesVersionV1,
  }) {
    final walls = List.generate(
      maze.size,
      (r) => List.generate(
        maze.size,
        (c) {
          final cell = maze.cells[r][c];
          return FixedMazeCellWalls(
            north: cell.north,
            east: cell.east,
            south: cell.south,
            west: cell.west,
          );
        },
      ),
    );
    final checksum = computeChecksum(
      size: maze.size,
      start: maze.start,
      exit: maze.exit,
      cells: walls,
    );
    return FixedMazeDefinition(
      mazeId: mazeId,
      difficulty: difficulty,
      size: maze.size,
      seedUsed: maze.seed,
      generatorVersion: generatorVersion,
      start: maze.start,
      exit: maze.exit,
      cells: walls,
      checksum: checksum,
      rulesVersion: rulesVersion,
    );
  }

  /// Rebuild a [MazeGrid] from this snapshot (seed field = [seedUsed] meta).
  MazeGrid toMazeGrid() {
    final gridCells = List.generate(
      size,
      (r) => List.generate(
        size,
        (c) {
          final w = cells[r][c];
          return MazeCell(
            north: w.north,
            east: w.east,
            south: w.south,
            west: w.west,
          );
        },
      ),
    );
    return MazeGrid(
      size: size,
      cells: gridCells,
      start: start,
      exit: exit,
      seed: seedUsed,
    );
  }

  bool get checksumValid {
    final expected = computeChecksum(
      size: size,
      start: start,
      exit: exit,
      cells: cells,
    );
    return expected == checksum;
  }

  /// True if every wall flag matches [other] (ignores visited).
  bool wallsEqualToGrid(MazeGrid other) {
    if (other.size != size) return false;
    if (other.start != start || other.exit != exit) return false;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final a = cells[r][c];
        final b = other.cells[r][c];
        if (a.north != b.north ||
            a.east != b.east ||
            a.south != b.south ||
            a.west != b.west) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'mazeId': mazeId,
        'difficulty': difficulty,
        'size': size,
        'seedUsed': seedUsed,
        'generatorVersion': generatorVersion,
        'start': {'row': start.row, 'col': start.col},
        'exit': {'row': exit.row, 'col': exit.col},
        'cells': [
          for (final row in cells)
            [
              for (final cell in row) cell.toJson(),
            ],
        ],
        'checksum': checksum,
        'rulesVersion': rulesVersion,
      };

  factory FixedMazeDefinition.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int;
    final startMap = json['start'] as Map<String, dynamic>;
    final exitMap = json['exit'] as Map<String, dynamic>;
    final rawCells = json['cells'] as List<dynamic>;
    final cells = List.generate(size, (r) {
      final row = rawCells[r] as List<dynamic>;
      return List.generate(size, (c) {
        return FixedMazeCellWalls.fromJson(row[c] as Map<String, dynamic>);
      });
    });
    return FixedMazeDefinition(
      mazeId: json['mazeId'] as String,
      difficulty: json['difficulty'] as String,
      size: size,
      seedUsed: json['seedUsed'] as int,
      generatorVersion: json['generatorVersion'] as String,
      start: GridPos(startMap['row'] as int, startMap['col'] as int),
      exit: GridPos(exitMap['row'] as int, exitMap['col'] as int),
      cells: cells,
      checksum: json['checksum'] as String,
      rulesVersion: json['rulesVersion'] as String,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory FixedMazeDefinition.fromJsonString(String source) =>
      FixedMazeDefinition.fromJson(
        jsonDecode(source) as Map<String, dynamic>,
      );
}

final class FixedMazeCellWalls {
  const FixedMazeCellWalls({
    required this.north,
    required this.east,
    required this.south,
    required this.west,
  });

  final bool north;
  final bool east;
  final bool south;
  final bool west;

  /// Fixed order n,e,s,w as 0/1 — used in checksum canonical form.
  String get canonical =>
      '${north ? 1 : 0}${east ? 1 : 0}${south ? 1 : 0}${west ? 1 : 0}';

  Map<String, dynamic> toJson() => {
        'n': north,
        'e': east,
        's': south,
        'w': west,
      };

  factory FixedMazeCellWalls.fromJson(Map<String, dynamic> json) {
    return FixedMazeCellWalls(
      north: json['n'] as bool,
      east: json['e'] as bool,
      south: json['s'] as bool,
      west: json['w'] as bool,
    );
  }
}
