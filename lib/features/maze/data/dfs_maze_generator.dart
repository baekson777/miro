import 'dart:collection';
import 'dart:math';

import '../domain/maze_cell.dart';
import '../domain/maze_grid.dart';

/// Procedural maze generation contract (practice / weekly).
abstract interface class MazeGenerator {
  MazeGrid generate({required int size, required int seed});
}

/// Complex perfect-maze generator (Growing Tree / Prim-biased).
///
/// Unlike classic recursive DFS (long corridors), this prefers picking a
/// **random** frontier cell so the maze grows bushy branches and dense
/// dead ends ("fake paths"). Exit is placed at the BFS-farthest cell
/// from start for a long unique solution path.
///
/// Same [seed] + [size] ⇒ identical maze on every client.
final class DfsMazeGenerator implements MazeGenerator {
  const DfsMazeGenerator();

  /// Probability of picking a random frontier cell (Prim-like).
  /// Remaining chance picks the newest cell (DFS-like tendril).
  static const double _randomFrontierBias = 0.88;

  @override
  MazeGrid generate({required int size, required int seed}) {
    assert(size >= 5, 'Maze size must be >= 5');

    final rng = Random(seed);
    final cells = List.generate(
      size,
      (_) => List.generate(size, (_) => const MazeCell()),
    );

    final start = const GridPos(0, 0);
    _growingTreeCarve(cells, start, rng, size);

    final exit = _farthestCell(cells, start, size);

    // Clear visited flags (used only during carve / BFS bookkeeping).
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        cells[r][c] = cells[r][c].copyWith(visited: false);
      }
    }

    return MazeGrid(
      size: size,
      cells: cells,
      start: start,
      exit: exit,
      seed: seed,
    );
  }

  /// Growing Tree: high random bias → many short dead-end spurs.
  void _growingTreeCarve(
    List<List<MazeCell>> cells,
    GridPos start,
    Random rng,
    int size,
  ) {
    cells[start.row][start.col] =
        cells[start.row][start.col].copyWith(visited: true);

    final frontier = <GridPos>[start];

    while (frontier.isNotEmpty) {
      final index = rng.nextDouble() < _randomFrontierBias
          ? rng.nextInt(frontier.length)
          : frontier.length - 1;
      final current = frontier[index];

      final neighbors = <({GridPos pos, _Dir dir})>[];
      for (final dir in _Dir.values) {
        final nr = current.row + dir.dRow;
        final nc = current.col + dir.dCol;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        if (cells[nr][nc].visited) continue;
        neighbors.add((pos: GridPos(nr, nc), dir: dir));
      }

      if (neighbors.isEmpty) {
        frontier.removeAt(index);
        continue;
      }

      final pick = neighbors[rng.nextInt(neighbors.length)];
      final next = pick.pos;
      final dir = pick.dir;

      cells[current.row][current.col] =
          _removeWall(cells[current.row][current.col], dir);
      cells[next.row][next.col] =
          _removeWall(cells[next.row][next.col], dir.opposite)
              .copyWith(visited: true);

      frontier.add(next);
    }
  }

  /// BFS diameter from [start] — maximizes solution length / confusion.
  GridPos _farthestCell(
    List<List<MazeCell>> cells,
    GridPos start,
    int size,
  ) {
    final dist = List.generate(size, (_) => List.filled(size, -1));
    final q = Queue<GridPos>()..add(start);
    dist[start.row][start.col] = 0;
    var farthest = start;
    var best = 0;

    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final d = dist[cur.row][cur.col];
      if (d > best) {
        best = d;
        farthest = cur;
      }

      final cell = cells[cur.row][cur.col];
      void tryGo(int r, int c, bool open) {
        if (!open) return;
        if (r < 0 || r >= size || c < 0 || c >= size) return;
        if (dist[r][c] >= 0) return;
        dist[r][c] = d + 1;
        q.add(GridPos(r, c));
      }

      tryGo(cur.row - 1, cur.col, !cell.north);
      tryGo(cur.row + 1, cur.col, !cell.south);
      tryGo(cur.row, cur.col - 1, !cell.west);
      tryGo(cur.row, cur.col + 1, !cell.east);
    }

    return farthest;
  }

  MazeCell _removeWall(MazeCell cell, _Dir dir) {
    return switch (dir) {
      _Dir.north => cell.copyWith(north: false),
      _Dir.east => cell.copyWith(east: false),
      _Dir.south => cell.copyWith(south: false),
      _Dir.west => cell.copyWith(west: false),
    };
  }

  /// Counts cells with exactly one open passage (dead ends). For tests.
  static int countDeadEnds(MazeGrid maze) {
    var n = 0;
    for (var r = 0; r < maze.size; r++) {
      for (var c = 0; c < maze.size; c++) {
        final cell = maze.cells[r][c];
        var open = 0;
        if (!cell.north) open++;
        if (!cell.south) open++;
        if (!cell.west) open++;
        if (!cell.east) open++;
        if (open == 1) n++;
      }
    }
    return n;
  }
}

enum _Dir {
  north(-1, 0),
  east(0, 1),
  south(1, 0),
  west(0, -1);

  const _Dir(this.dRow, this.dCol);

  final int dRow;
  final int dCol;

  _Dir get opposite => switch (this) {
        _Dir.north => _Dir.south,
        _Dir.south => _Dir.north,
        _Dir.east => _Dir.west,
        _Dir.west => _Dir.east,
      };
}
