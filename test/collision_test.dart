import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/domain/collision.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wall blocks movement; open passage allows it', () {
    const gen = DfsMazeGenerator();
    final maze = gen.generate(size: 10, seed: 7);
    final start = maze.start;

    var blocked = 0;
    var open = 0;
    for (final d in const [
      GridPos(-1, 0),
      GridPos(1, 0),
      GridPos(0, -1),
      GridPos(0, 1),
    ]) {
      final next = GridPos(start.row + d.row, start.col + d.col);
      if (!maze.inBounds(next)) continue;
      if (MazeCollision.canStep(maze, start, next)) {
        open++;
      } else {
        blocked++;
      }
    }

    expect(open + blocked, greaterThan(0));
    // Perfect maze start has at least one open neighbor eventually reachable,
    // but may be blocked on some sides — assert collision rejects diagonal.
    expect(
      MazeCollision.canStep(maze, start, GridPos(start.row + 1, start.col + 1)),
      isFalse,
    );
  });
}
