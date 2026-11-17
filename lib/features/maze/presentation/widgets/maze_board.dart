import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/collision.dart';
import '../../domain/maze_grid.dart';
import 'maze_wall_cache.dart';

/// Layered board:
/// - [StaticMazeLayer] walls — painted once, [RepaintBoundary] isolated
/// - [DynamicPlayerFogLayer] — [ValueListenableBuilder] on player [Offset] only
class MazeBoard extends StatelessWidget {
  const MazeBoard({
    super.key,
    required this.maze,
    required this.playerPos,
    required this.revealListenable,
  });

  final MazeGrid maze;
  final ValueNotifier<Offset> playerPos;
  final ValueListenable<bool> revealListenable;

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
                    key: ValueKey('walls-${maze.seed}-${maze.size}-$boardSize'),
                    maze: maze,
                    boardSize: size,
                  ),
                ),
                RepaintBoundary(
                  child: DynamicPlayerFogLayer(
                    maze: maze,
                    boardSize: size,
                    playerPos: playerPos,
                    revealListenable: revealListenable,
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

/// Walls + floor recorded into a [ui.Picture] once per maze/size.
class StaticMazeLayer extends StatefulWidget {
  const StaticMazeLayer({
    super.key,
    required this.maze,
    required this.boardSize,
  });

  final MazeGrid maze;
  final Size boardSize;

  @override
  State<StaticMazeLayer> createState() => _StaticMazeLayerState();
}

class _StaticMazeLayerState extends State<StaticMazeLayer> {
  ui.Picture? _picture;
  MazeWallCache? _cache;

  static final _floorPaint = Paint()..color = const Color(0xFF050508);
  static final _wallPaint = Paint()
    ..color = const Color(0xFFF5F5F5)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  void initState() {
    super.initState();
    _bake();
  }

  @override
  void didUpdateWidget(covariant StaticMazeLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maze.seed != widget.maze.seed ||
        oldWidget.maze.size != widget.maze.size ||
        oldWidget.boardSize != widget.boardSize) {
      _picture?.dispose();
      _picture = null;
      _bake();
    }
  }

  void _bake() {
    _cache = MazeWallCache.build(
      maze: widget.maze,
      boardSize: widget.boardSize,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = widget.boardSize;
    canvas.drawRect(Offset.zero & size, _floorPaint);
    canvas.drawPath(_cache!.walls, _wallPaint);
    _picture = recorder.endRecording();
  }

  @override
  void dispose() {
    _picture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: widget.boardSize,
      painter: _PicturePainter(_picture),
      isComplex: true,
      willChange: false,
    );
  }
}

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.picture);

  final ui.Picture? picture;

  @override
  void paint(Canvas canvas, Size size) {
    final pic = picture;
    if (pic != null) canvas.drawPicture(pic);
  }

  @override
  bool shouldRepaint(covariant _PicturePainter old) => old.picture != picture;
}

/// Player + fog + exit — rebuilds only when [playerPos] / reveal changes.
class DynamicPlayerFogLayer extends StatefulWidget {
  const DynamicPlayerFogLayer({
    super.key,
    required this.maze,
    required this.boardSize,
    required this.playerPos,
    required this.revealListenable,
  });

  final MazeGrid maze;
  final Size boardSize;
  final ValueNotifier<Offset> playerPos;
  final ValueListenable<bool> revealListenable;

  @override
  State<DynamicPlayerFogLayer> createState() => _DynamicPlayerFogLayerState();
}

class _DynamicPlayerFogLayerState extends State<DynamicPlayerFogLayer> {
  /// Reused across frames to avoid allocating a new Path every tick.
  final Path _fogPath = Path()..fillType = PathFillType.evenOdd;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: widget.playerPos,
      builder: (context, cellPos, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: widget.revealListenable,
          builder: (context, reveal, _) {
            return CustomPaint(
              size: widget.boardSize,
              painter: _FogPlayerPainter(
                maze: widget.maze,
                boardSize: widget.boardSize,
                cellPos: cellPos,
                reveal: reveal,
                fogPath: _fogPath,
              ),
              isComplex: false,
              willChange: true,
            );
          },
        );
      },
    );
  }
}

class _FogPlayerPainter extends CustomPainter {
  _FogPlayerPainter({
    required this.maze,
    required this.boardSize,
    required this.cellPos,
    required this.reveal,
    required this.fogPath,
  });

  final MazeGrid maze;
  final Size boardSize;
  final Offset cellPos;
  final bool reveal;
  final Path fogPath;

  static const _fog = Color(0xFF000000);
  static const _exit = Color(0xFF00E676);
  static const _player = Color(0xFFFFB300);
  static const _ring = Color(0xFFFF6D00);

  static final _fogPaint = Paint()..color = _fog;
  static final _exitPaint = Paint()..color = _exit;
  static final _playerPaint = Paint()..color = _player;
  static final _ringPaint = Paint()
    ..color = _ring
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final n = maze.size;
    final cell = boardSize.width / n;
    // Same cell-space radius as [MazeCollision.playerRadius] → visual = physics.
    final playerRadiusPx = MazeCollision.playerRadius * cell;
    final visionPx = playerRadiusPx * MazeCollision.visionToPlayer;
    final pixel = Offset(cellPos.dx * cell, cellPos.dy * cell);

    final exit = maze.exit;
    final exitPixel = Offset(
      (exit.col + 0.5) * cell,
      (exit.row + 0.5) * cell,
    );
    final exitLit = reveal || (exitPixel - pixel).distance <= visionPx;

    if (exitLit) {
      final corridor =
          math.max(4.0, cell * (1.0 - MazeCollision.wallThicknessFraction));
      final side = corridor * 0.72;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: exitPixel, width: side, height: side),
          Radius.circular(side * 0.18),
        ),
        _exitPaint,
      );
    }

    if (!reveal) {
      fogPath
        ..reset()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: pixel, radius: visionPx));
      canvas.drawPath(fogPath, _fogPaint);
    }

    canvas.drawCircle(pixel, playerRadiusPx, _playerPaint);
    canvas.drawCircle(pixel, playerRadiusPx, _ringPaint);
  }

  @override
  bool shouldRepaint(covariant _FogPlayerPainter old) {
    return old.cellPos != cellPos ||
        old.reveal != reveal ||
        old.maze.seed != maze.seed ||
        old.boardSize != boardSize;
  }
}
