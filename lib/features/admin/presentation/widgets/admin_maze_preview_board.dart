import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../maze/domain/maze_cell.dart';
import '../../../maze/domain/maze_grid.dart';
import '../../../maze/presentation/widgets/maze_board.dart';

/// Admin-only full-maze view. Reuses [StaticMazeLayer] wall baking; never used
/// by the player [MazeBoard] fog/player stack.
class AdminMazePreviewBoard extends StatelessWidget {
  const AdminMazePreviewBoard({
    super.key,
    required this.maze,
    required this.pathCells,
    required this.showPath,
  });

  final MazeGrid maze;
  final List<GridPos> pathCells;
  final bool showPath;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final boardSize = side.isFinite && side > 0 ? side : 320.0;
        final size = Size(boardSize, boardSize);

        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: StaticMazeLayer(
                    key: ValueKey(
                      'admin-walls-${maze.seed}-${maze.size}-$boardSize',
                    ),
                    maze: maze,
                    boardSize: size,
                  ),
                ),
                CustomPaint(
                  size: size,
                  painter: _AdminMarkersPainter(
                    maze: maze,
                    boardSize: size,
                    pathCells: showPath ? pathCells : const [],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminMarkersPainter extends CustomPainter {
  _AdminMarkersPainter({
    required this.maze,
    required this.boardSize,
    required this.pathCells,
  });

  final MazeGrid maze;
  final Size boardSize;
  final List<GridPos> pathCells;

  static final _pathPaint = Paint()
    ..color = const Color(0x664FC3F7)
    ..style = PaintingStyle.fill;
  static final _startPaint = Paint()..color = const Color(0xFF42A5F5);
  static final _exitPaint = Paint()..color = const Color(0xFF00E676);
  static final _startBorder = Paint()
    ..color = const Color(0xFF90CAF9)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final _exitBorder = Paint()
    ..color = const Color(0xFF69F0AE)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final n = maze.size;
    final cell = boardSize.width / n;

    for (final p in pathCells) {
      canvas.drawRect(
        Rect.fromLTWH(p.col * cell, p.row * cell, cell, cell),
        _pathPaint,
      );
    }

    void marker(GridPos pos, Paint fill, Paint border) {
      final center = Offset((pos.col + 0.5) * cell, (pos.row + 0.5) * cell);
      final r = cell * 0.28;
      canvas.drawCircle(center, r, fill);
      canvas.drawCircle(center, r, border);
    }

    marker(maze.start, _startPaint, _startBorder);
    marker(maze.exit, _exitPaint, _exitBorder);
  }

  @override
  bool shouldRepaint(covariant _AdminMarkersPainter old) {
    return old.maze.seed != maze.seed ||
        old.maze.size != maze.size ||
        old.boardSize != boardSize ||
        !listEquals(old.pathCells, pathCells);
  }
}

bool listEquals(List<GridPos> a, List<GridPos> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
