import 'package:flutter/material.dart';

import '../../domain/maze_grid.dart';

/// Thick filled wall geometry — rebuilt only when maze or board size changes.
final class MazeWallCache {
  MazeWallCache._({
    required this.seed,
    required this.mazeSize,
    required this.boardSize,
    required this.walls,
    required this.wallWidth,
    required this.cellSize,
  });

  final int seed;
  final int mazeSize;
  final Size boardSize;

  /// Filled wall bars (not hairline strokes).
  final Path walls;
  final double wallWidth;
  final double cellSize;

  static MazeWallCache build({
    required MazeGrid maze,
    required Size boardSize,
  }) {
    final n = maze.size;
    final cellW = boardSize.width / n;
    final cellH = boardSize.height / n;
    final minCell = cellW < cellH ? cellW : cellH;
    // Dense partitions for large grids; corridors stay readable in tight vision.
    final t = (minCell * 0.28).clamp(3.0, 16.0);

    final walls = Path();

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final cell = maze.cells[r][c];
        final left = c * cellW;
        final top = r * cellH;
        final right = left + cellW;
        final bottom = top + cellH;

        // Thick bars centered on cell edges.
        if (cell.north) {
          walls.addRect(Rect.fromLTRB(left, top, right, top + t));
        }
        if (cell.south) {
          walls.addRect(Rect.fromLTRB(left, bottom - t, right, bottom));
        }
        if (cell.west) {
          walls.addRect(Rect.fromLTRB(left, top, left + t, bottom));
        }
        if (cell.east) {
          walls.addRect(Rect.fromLTRB(right - t, top, right, bottom));
        }
      }
    }

    // Outer frame (full border thickness).
    walls
      ..addRect(Rect.fromLTWH(0, 0, boardSize.width, t))
      ..addRect(Rect.fromLTWH(0, boardSize.height - t, boardSize.width, t))
      ..addRect(Rect.fromLTWH(0, 0, t, boardSize.height))
      ..addRect(Rect.fromLTWH(boardSize.width - t, 0, t, boardSize.height));

    return MazeWallCache._(
      seed: maze.seed,
      mazeSize: n,
      boardSize: boardSize,
      walls: walls,
      wallWidth: t,
      cellSize: minCell,
    );
  }

  bool matches(MazeGrid maze, Size size) =>
      seed == maze.seed && mazeSize == maze.size && boardSize == size;
}
