import 'package:equatable/equatable.dart';

import 'collision.dart';
import 'maze_cell.dart';

final class MazeGrid extends Equatable {
  const MazeGrid({
    required this.size,
    required this.cells,
    required this.start,
    required this.exit,
    required this.seed,
  });

  final int size;
  final List<List<MazeCell>> cells;
  final GridPos start;
  final GridPos exit;
  final int seed;

  MazeCell cellAt(GridPos pos) => cells[pos.row][pos.col];

  bool inBounds(GridPos pos) =>
      pos.row >= 0 && pos.row < size && pos.col >= 0 && pos.col < size;

  bool canMove(GridPos from, GridPos to) =>
      MazeCollision.canStep(this, from, to);

  @override
  List<Object?> get props => [size, seed, start, exit];
}
