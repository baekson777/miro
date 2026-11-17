import 'dart:collection';

import '../domain/maze_cell.dart';
import '../domain/maze_grid.dart';

/// BFS helpers for fixed-maze validation (not used by gameplay loop yet).
abstract final class FixedMazePath {
  static List<GridPos> _neighbors(MazeGrid maze, GridPos p) {
    final cell = maze.cellAt(p);
    final out = <GridPos>[];
    if (!cell.north) out.add(GridPos(p.row - 1, p.col));
    if (!cell.south) out.add(GridPos(p.row + 1, p.col));
    if (!cell.west) out.add(GridPos(p.row, p.col - 1));
    if (!cell.east) out.add(GridPos(p.row, p.col + 1));
    return out;
  }

  /// Shortest path length in steps, or -1 if unreachable.
  static int shortestLength(MazeGrid maze) {
    final path = shortestPath(maze);
    if (path == null) return -1;
    return path.length - 1;
  }

  /// Cells from start to exit inclusive along a BFS shortest path, or null.
  static List<GridPos>? shortestPath(MazeGrid maze) {
    final n = maze.size;
    final dist = List.generate(n, (_) => List.filled(n, -1));
    final parent = List.generate(n, (_) => List<GridPos?>.filled(n, null));
    final q = Queue<GridPos>()..add(maze.start);
    dist[maze.start.row][maze.start.col] = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      if (cur == maze.exit) {
        final path = <GridPos>[];
        GridPos? step = cur;
        while (step != null) {
          path.add(step);
          if (step == maze.start) break;
          step = parent[step.row][step.col];
        }
        return path.reversed.toList();
      }
      for (final nb in _neighbors(maze, cur)) {
        if (dist[nb.row][nb.col] >= 0) continue;
        dist[nb.row][nb.col] = dist[cur.row][cur.col] + 1;
        parent[nb.row][nb.col] = cur;
        q.add(nb);
      }
    }
    return null;
  }
}
