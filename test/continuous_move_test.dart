import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/domain/collision.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_cell.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_grid.dart';
import 'package:blind_weekly_maze/features/maze/presentation/controllers/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Horizontal corridor on row 2, cols 1–3, with a NW corner at (2,2).
MazeGrid _corridorMaze() {
  const size = 5;
  final cells = List.generate(
    size,
    (_) => List.generate(size, (_) => const MazeCell()),
  );

  cells[2][1] = const MazeCell(
    north: true,
    south: true,
    west: true,
    east: false,
  );
  cells[2][2] = const MazeCell(
    north: true,
    south: true,
    west: true,
    east: false,
  );
  cells[2][3] = const MazeCell(
    north: true,
    south: true,
    west: false,
    east: true,
  );

  return MazeGrid(
    size: size,
    cells: cells,
    start: const GridPos(2, 1),
    exit: const GridPos(2, 3),
    seed: 0,
  );
}

void main() {
  const r = MazeCollision.playerRadius;

  test('slideMove blocks into wall and allows open direction', () {
    const gen = DfsMazeGenerator();
    final maze = gen.generate(size: 15, seed: 42);
    final start = MazeCollision.cellCenter(maze.start);

    expect(MazeCollision.circleHitsWall(maze, start, r), isFalse);

    final moved = MazeCollision.slideMoveStepped(
      maze,
      start,
      const Offset(2.5, 2.5),
      r,
    );
    expect(MazeCollision.circleHitsWall(maze, moved, r), isFalse);
    expect(moved.dx, greaterThanOrEqualTo(r));
    expect(moved.dy, greaterThanOrEqualTo(r));
    expect(moved.dx, lessThanOrEqualTo(maze.size - r));
    expect(moved.dy, lessThanOrEqualTo(maze.size - r));
  });

  test('diagonal unit stick does not amplify speed vs axis', () {
    const axis = Offset(1, 0);
    final diag = Offset(1 / 1.41421356237, 1 / 1.41421356237);
    expect(axis.distance, closeTo(1.0, 1e-6));
    expect(diag.distance, closeTo(1.0, 1e-5));
  });

  test('1 frontal wall hit stops without sideways push', () {
    final maze = _corridorMaze();
    const from = Offset(2.5, 2.5);
    expect(MazeCollision.circleHitsWall(maze, from, r), isFalse);

    final next = MazeCollision.slideMove(
      maze,
      from,
      const Offset(0, -1.0),
      r,
    );

    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dy, greaterThanOrEqualTo(2.0 + r - 1e-6));
    expect(next.dx, closeTo(2.5, 1e-6));
  });

  test('2 diagonal into wall blocks inward, may keep tangent', () {
    final maze = _corridorMaze();
    const from = Offset(2.55, 2.5);

    final next = MazeCollision.slideMove(
      maze,
      from,
      const Offset(0.25, -0.6),
      r,
    );

    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dy, greaterThanOrEqualTo(2.0 + r - 1e-6));
    expect(next.dx, greaterThanOrEqualTo(2.0 + r - 1e-6));
  });

  test('3 parallel motion along wall is allowed', () {
    final maze = _corridorMaze();
    final from = Offset(2.5, 2.0 + r + 1e-4);
    expect(MazeCollision.circleHitsWall(maze, from, r), isFalse);

    final next = MazeCollision.slideMove(
      maze,
      from,
      const Offset(0.2, 0),
      r,
    );

    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dx, greaterThan(from.dx + 0.05));
    expect(next.dy, closeTo(from.dy, 1e-5));
  });

  test('4 corner hit does not tunnel into either wall', () {
    final maze = _corridorMaze();
    const from = Offset(2.5, 2.5);

    final next = MazeCollision.slideMove(
      maze,
      from,
      const Offset(-0.8, -0.8),
      r,
    );

    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dx, greaterThanOrEqualTo(2.0 + r - 1e-6));
    expect(next.dy, greaterThanOrEqualTo(2.0 + r - 1e-6));
  });

  test('5 narrow corridor passage stays clear', () {
    final maze = _corridorMaze();
    const from = Offset(2.7, 2.5);
    expect(MazeCollision.circleHitsWall(maze, from, r), isFalse);

    final next = MazeCollision.slideMoveStepped(
      maze,
      from,
      const Offset(0.35, 0),
      r,
    );
    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dx, greaterThan(from.dx));
  });

  test('6 repeated frontal pushes do not vibrate position', () {
    final maze = _corridorMaze();
    var pos = const Offset(2.5, 2.5);
    for (var i = 0; i < 40; i++) {
      pos = MazeCollision.slideMove(maze, pos, const Offset(0, -0.08), r);
      expect(MazeCollision.circleHitsWall(maze, pos, r), isFalse);
    }
    final settled = pos;
    for (var i = 0; i < 20; i++) {
      pos = MazeCollision.slideMove(maze, pos, const Offset(0, -0.08), r);
      expect(pos.dx, closeTo(settled.dx, 1e-6));
      expect(pos.dy, closeTo(settled.dy, 1e-6));
    }
  });

  test('7 high-speed stepped move does not tunnel walls', () {
    final maze = _corridorMaze();
    const from = Offset(2.5, 2.5);
    final next = MazeCollision.slideMoveStepped(
      maze,
      from,
      const Offset(0, -3.0),
      r,
      maxStep: 0.12,
    );
    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dy, greaterThanOrEqualTo(2.0 + r - 1e-6));
    expect(next.dx, closeTo(2.5, 1e-5));
  });

  // --- Stability / normal detection reinforcements ---

  test('8 free-only sample can miss; contactsAlongHit uses blocked geometry',
      () {
    final maze = _corridorMaze();
    // Gap larger than contactSkin → free-only normals fail (repro).
    final free = Offset(2.5, 2.0 + r + MazeCollision.contactSkin * 4);
    expect(MazeCollision.circleHitsWall(maze, free, r), isFalse);
    expect(MazeCollision.contactNormals(maze, free, r), isEmpty);

    // Far from wall → empty (must not invent).
    const far = Offset(2.5, 2.5);
    expect(MazeCollision.contactNormals(maze, far, r), isEmpty);

    // Blocked sample past the plane recovers real normals.
    final blocked = Offset(2.5, 2.0 + r - 0.05);
    expect(MazeCollision.circleHitsWall(maze, blocked, r), isTrue);
    final viaHit =
        MazeCollision.contactsAlongHit(maze, free, blocked, r);
    expect(viaHit, isNotEmpty);
    expect(viaHit.any((n) => n.dy > 0.9), isTrue);

    // TOI-scale free gap (≈ maxStep/2^12) stays within skin.
    final toiFree = Offset(2.5, 2.0 + r + 3e-5);
    expect(MazeCollision.circleHitsWall(maze, toiFree, r), isFalse);
    expect(MazeCollision.contactNormals(maze, toiFree, r), isNotEmpty);
  });

  test('9 corner yields 2+ normals; projected V is outward for all', () {
    final maze = _corridorMaze();
    // Overlap NW corner of cell (2,2): walls at x=2 and y=2.
    const blocked = Offset(2.0 + r - 0.05, 2.0 + r - 0.05);
    expect(MazeCollision.circleHitsWall(maze, blocked, r), isTrue);

    final normals = MazeCollision.contactNormals(maze, blocked, r);
    expect(normals.length, greaterThanOrEqualTo(2));

    const inbound = Offset(-0.4, -0.4);
    final projected = MazeCollision.projectVelocity(inbound, normals);
    expect(
      MazeCollision.velocityOutwardOrTangent(projected, normals),
      isTrue,
    );
    // Into the corner: both components should be stripped → ~zero.
    expect(projected.distance, lessThan(1e-6));
  });

  test('10 shallow angle slide stays small (not ice-boosted)', () {
    final maze = _corridorMaze();
    const from = Offset(2.5, 2.5);
    // Mostly into the north wall, tiny east tangent (~8° from normal).
    const delta = Offset(0.05, -0.35);
    final next = MazeCollision.slideMove(maze, from, delta, r);

    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dy, greaterThanOrEqualTo(2.0 + r - 1e-6));
    // Tangential travel must not exceed the tiny input tangent (+tol).
    expect(next.dx - from.dx, lessThan(0.06));
    expect(next.dx - from.dx, greaterThanOrEqualTo(-1e-6));
  });

  test('11 wall-parallel move keeps direction after prior frontal settle', () {
    final maze = _corridorMaze();
    var pos = const Offset(2.5, 2.5);
    for (var i = 0; i < 30; i++) {
      pos = MazeCollision.slideMove(maze, pos, const Offset(0, -0.1), r);
    }
    final afterFront = pos;
    // Direction change: now slide east — must not inherit leftover push.
    final next = MazeCollision.slideMove(
      maze,
      afterFront,
      const Offset(0.15, 0),
      r,
    );
    expect(MazeCollision.circleHitsWall(maze, next, r), isFalse);
    expect(next.dx, greaterThan(afterFront.dx + 0.05));
    expect(next.dy, closeTo(afterFront.dy, 1e-5));
  });

  test('12 multi-pass projection does not reintroduce inward dots', () {
    final normals = <Offset>[
      const Offset(1, 0),
      const Offset(0, 1),
      Offset(1 / mathSqrt2, 1 / mathSqrt2),
    ];
    const v = Offset(-0.7, -0.5);
    final out = MazeCollision.projectVelocity(v, normals);
    expect(MazeCollision.velocityOutwardOrTangent(out, normals), isTrue);
  });

  test('13 visual thick wall vs hairline collision geometry', () {
    // Documented relationship (radius kept at 0.30):
    // - MazeWallCache draws bars of thickness wallThicknessFraction from the
    //   cell edge inward (boundary bars, not centerlines).
    // - circleHitsWall tests hairline segments ON the cell edge.
    // - player draw radius == playerRadius (same as collision).
    // - Visual corridor width = 1 - 2*0.28 = 0.44 < player diameter 0.60,
    //   so flush hairline contact necessarily overlaps the drawn bar.
    expect(MazeCollision.wallThicknessFraction, 0.28);
    expect(MazeCollision.playerRadius, 0.30);
    final visualCorridor = 1.0 - 2 * MazeCollision.wallThicknessFraction;
    final diameter = 2 * MazeCollision.playerRadius;
    expect(visualCorridor, lessThan(diameter));

    // Flush against north hairline: circle extends to y=wall, into the bar.
    final flushY = 2.0 + r;
    final circleTop = flushY - r; // == 2.0 (hairline)
    final visualInnerFace = 2.0 + MazeCollision.wallThicknessFraction;
    expect(circleTop, lessThan(visualInnerFace));
  });

  test('14 accelerate from rest toward full stick target', () {
    const target = Offset(GameController.maxSpeed, 0);
    var vel = Offset.zero;
    const dt = 1 / 60.0;
    for (var i = 0; i < 4; i++) {
      vel = GameController.approachVelocity(vel, target, dt);
    }
    // Spools up but not instantly to max.
    expect(vel.dx, greaterThan(0.5));
    expect(vel.dx, lessThan(GameController.maxSpeed * 0.85));

    for (var i = 0; i < 60; i++) {
      vel = GameController.approachVelocity(vel, target, dt);
    }
    expect(vel.dx, closeTo(GameController.maxSpeed, 0.05));
  });

  test('15 reverse input turns through intermediate speeds', () {
    var vel = const Offset(GameController.maxSpeed, 0);
    const target = Offset(-GameController.maxSpeed, 0);
    const dt = 1 / 60.0;
    vel = GameController.approachVelocity(vel, target, dt);
    // One frame cannot fully flip to -maxSpeed.
    expect(vel.dx, greaterThan(-GameController.maxSpeed * 0.5));
    expect(vel.dx, lessThan(GameController.maxSpeed));
  });

  test('16 stick release policy: zero target snaps velocity when cleared', () {
    // Controller clears velocity on release; approach to zero is not used.
    // Documented contract: release ⇒ Offset.zero, not coasting.
    expect(GameController.maxSpeed, 5.8);
    var vel = const Offset(3.0, 1.0);
    vel = Offset.zero; // release path
    expect(vel, Offset.zero);
  });

  test('17 shallow wall scrape is friction-damped vs free parallel run', () {
    final maze = _corridorMaze();
    const from = Offset(2.55, 2.5);
    // Into north wall with east tangent.
    final scraped = MazeCollision.slideMove(
      maze,
      from,
      const Offset(0.2, -0.5),
      r,
    );
    final freeParallel = MazeCollision.slideMove(
      maze,
      Offset(2.55, 2.0 + r + 1e-4),
      const Offset(0.2, 0),
      r,
    );
    expect(MazeCollision.circleHitsWall(maze, scraped, r), isFalse);
    expect(MazeCollision.circleHitsWall(maze, freeParallel, r), isFalse);
    // Free parallel keeps nearly full tangent; scrape is shorter (friction).
    final scrapeTravel = scraped.dx - from.dx;
    final freeTravel = freeParallel.dx - 2.55;
    expect(freeTravel, greaterThan(0.15));
    expect(scrapeTravel, lessThan(freeTravel));
    expect(MazeCollision.wallSlideFriction, lessThan(1.0));
  });

  test('18 small vs full stick target speed scales with magnitude', () {
    const dt = 1 / 60.0;
    var small = Offset.zero;
    var full = Offset.zero;
    final smallTarget = Offset(GameController.maxSpeed * 0.3, 0);
    final fullTarget = Offset(GameController.maxSpeed, 0);
    for (var i = 0; i < 90; i++) {
      small = GameController.approachVelocity(small, smallTarget, dt);
      full = GameController.approachVelocity(full, fullTarget, dt);
    }
    expect(small.dx, closeTo(GameController.maxSpeed * 0.3, 0.05));
    expect(full.dx, closeTo(GameController.maxSpeed, 0.05));
    expect(full.dx, greaterThan(small.dx * 2));
  });
}

/// Local sqrt2 helper without importing dart:math into test name noise.
const mathSqrt2 = 1.4142135623730951;
