import 'package:equatable/equatable.dart';

/// Wall flags for a single grid cell. `true` = wall present.
final class MazeCell extends Equatable {
  const MazeCell({
    this.north = true,
    this.east = true,
    this.south = true,
    this.west = true,
    this.visited = false,
  });

  final bool north;
  final bool east;
  final bool south;
  final bool west;
  final bool visited;

  MazeCell copyWith({
    bool? north,
    bool? east,
    bool? south,
    bool? west,
    bool? visited,
  }) {
    return MazeCell(
      north: north ?? this.north,
      east: east ?? this.east,
      south: south ?? this.south,
      west: west ?? this.west,
      visited: visited ?? this.visited,
    );
  }

  @override
  List<Object?> get props => [north, east, south, west, visited];
}

final class GridPos extends Equatable {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  @override
  List<Object?> get props => [row, col];

  @override
  String toString() => '($row,$col)';
}
