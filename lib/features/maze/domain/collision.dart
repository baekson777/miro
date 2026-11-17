import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'maze_cell.dart';
import 'maze_grid.dart';

/// Grid step checks + continuous circle / wall-segment sliding.
///
/// Collision walls are **hairline segments on cell edges** (not the thick
/// [wallThicknessFraction] bars drawn by [MazeWallCache]). With
/// [playerRadius] 0.30 and visual thickness 0.28, a flush contact against a
/// hairline overlaps the drawn wall bar — that is geometric, not a slide bug.
abstract final class MazeCollision {
  /// Matches [MazeWallCache] wall thickness fraction (`cell * 0.28`).
  static const double wallThicknessFraction = 0.28;

  /// Player collision / draw radius in cell-space (fits thick-wall corridors).
  static const double playerRadius = 0.30;

  /// Vision hole radius relative to [playerRadius] (same as board painter).
  static const double visionToPlayer = 2.35;

  /// Binary-search iterations in [_slideMoveOnce] (error ≈ step / 2^this).
  static const int _toiIterations = 12;

  /// Extra reach beyond [radius] when collecting contacts.
  /// Sized above binary-search residual for a typical [maxStep] 0.12:
  /// `0.12 / 2^12 ≈ 3e-5`, so `2e-4` keeps the free TOI sample in range.
  static const double contactSkin = 2e-4;

  /// After a wall hit, keep this fraction of the tangential (projected) delta.
  /// 1.0 = ice slide; lower = more "grip" without disabling parallel runs
  /// that never hit (open free move is unchanged).
  static const double wallSlideFriction = 0.42;

  /// Discrete orthogonal step through an open passage.
  static bool canStep(MazeGrid maze, GridPos from, GridPos to) {
    if (!maze.inBounds(from) || !maze.inBounds(to)) return false;

    final dr = to.row - from.row;
    final dc = to.col - from.col;
    if ((dr.abs() + dc.abs()) != 1) return false;

    final cell = maze.cellAt(from);
    final neighbor = maze.cellAt(to);

    if (dr == -1) return !cell.north && !neighbor.south;
    if (dr == 1) return !cell.south && !neighbor.north;
    if (dc == -1) return !cell.west && !neighbor.east;
    if (dc == 1) return !cell.east && !neighbor.west;
    return false;
  }

  static int chebyshev(GridPos a, GridPos b) {
    final dr = (a.row - b.row).abs();
    final dc = (a.col - b.col).abs();
    return dr > dc ? dr : dc;
  }

  static bool inVision(GridPos player, GridPos cell, int radius) =>
      chebyshev(player, cell) <= radius;

  /// Cell-space center of [pos] → `(col + 0.5, row + 0.5)`.
  static Offset cellCenter(GridPos pos) =>
      Offset(pos.col + 0.5, pos.row + 0.5);

  static GridPos cellOf(Offset p) =>
      GridPos(p.dy.floor(), p.dx.floor());

  /// True if a circle at [p] (cell-space) with [radius] hits any wall.
  static bool circleHitsWall(MazeGrid maze, Offset p, double radius) {
    final n = maze.size;
    if (p.dx < radius ||
        p.dy < radius ||
        p.dx > n - radius ||
        p.dy > n - radius) {
      return true; // outer bounds
    }

    final c0 = (p.dx - radius).floor().clamp(0, n - 1);
    final c1 = (p.dx + radius).floor().clamp(0, n - 1);
    final r0 = (p.dy - radius).floor().clamp(0, n - 1);
    final r1 = (p.dy + radius).floor().clamp(0, n - 1);

    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final cell = maze.cells[r][c];
        final left = c.toDouble();
        final top = r.toDouble();
        final right = left + 1;
        final bottom = top + 1;

        if (cell.north && _hitsSegment(p, radius, left, top, right, top)) {
          return true;
        }
        if (cell.south &&
            _hitsSegment(p, radius, left, bottom, right, bottom)) {
          return true;
        }
        if (cell.west && _hitsSegment(p, radius, left, top, left, bottom)) {
          return true;
        }
        if (cell.east &&
            _hitsSegment(p, radius, right, top, right, bottom)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _hitsSegment(
    Offset p,
    double radius,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final closest = _closestOnSegment(p.dx, p.dy, ax, ay, bx, by);
    final dx = p.dx - closest.$1;
    final dy = p.dy - closest.$2;
    return dx * dx + dy * dy < radius * radius;
  }

  static (double, double) _closestOnSegment(
    double px,
    double py,
    double ax,
    double ay,
    double bx,
    double by,
  ) {
    final abx = bx - ax;
    final aby = by - ay;
    final apx = px - ax;
    final apy = py - ay;
    final abLen2 = abx * abx + aby * aby;
    final t = abLen2 == 0 ? 0.0 : (apx * abx + apy * aby) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    return (ax + abx * clamped, ay + aby * clamped);
  }

  /// Wall→player unit normals for surfaces the circle is touching at [p].
  ///
  /// Only returns normals from real geometry (segments / bounds). Never invents
  /// a fallback normal when nothing is in range.
  static List<Offset> contactNormals(
    MazeGrid maze,
    Offset p,
    double radius, {
    double skin = contactSkin,
  }) {
    final normals = <Offset>[];
    final touchR = radius + skin;
    final touchR2 = touchR * touchR;
    final n = maze.size;

    void addNormal(double nx, double ny) {
      final len = math.sqrt(nx * nx + ny * ny);
      if (len < 1e-8) return;
      final ux = nx / len;
      final uy = ny / len;
      for (final existing in normals) {
        if (existing.dx * ux + existing.dy * uy > 0.99) return;
      }
      normals.add(Offset(ux, uy));
    }

    void considerSegment(double ax, double ay, double bx, double by) {
      final closest = _closestOnSegment(p.dx, p.dy, ax, ay, bx, by);
      final dx = p.dx - closest.$1;
      final dy = p.dy - closest.$2;
      final d2 = dx * dx + dy * dy;
      if (d2 >= touchR2) return;
      if (d2 < 1e-12) {
        // Center on segment: geometric perpendicular from segment axes.
        if ((bx - ax).abs() >= (by - ay).abs()) {
          addNormal(0, p.dy >= ay ? 1 : -1);
        } else {
          addNormal(p.dx >= ax ? 1 : -1, 0);
        }
        return;
      }
      addNormal(dx, dy);
    }

    if (p.dx <= touchR) addNormal(1, 0);
    if (p.dx >= n - touchR) addNormal(-1, 0);
    if (p.dy <= touchR) addNormal(0, 1);
    if (p.dy >= n - touchR) addNormal(0, -1);

    final c0 = (p.dx - touchR).floor().clamp(0, n - 1);
    final c1 = (p.dx + touchR).floor().clamp(0, n - 1);
    final r0 = (p.dy - touchR).floor().clamp(0, n - 1);
    final r1 = (p.dy + touchR).floor().clamp(0, n - 1);

    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final cell = maze.cells[r][c];
        final left = c.toDouble();
        final top = r.toDouble();
        final right = left + 1;
        final bottom = top + 1;

        if (cell.north) considerSegment(left, top, right, top);
        if (cell.south) considerSegment(left, bottom, right, bottom);
        if (cell.west) considerSegment(left, top, left, bottom);
        if (cell.east) considerSegment(right, top, right, bottom);
      }
    }
    return normals;
  }

  /// Collect contacts from known free + blocked samples along a hit ray.
  ///
  /// Prefer the first blocked sample (guaranteed overlap/hit), then the last
  /// free sample with [contactSkin]. Does not invent normals.
  static List<Offset> contactsAlongHit(
    MazeGrid maze,
    Offset freePos,
    Offset blockedPos,
    double radius,
  ) {
    // Blocked side is the most reliable geometric contact.
    final fromBlocked = contactNormals(maze, blockedPos, radius);
    if (fromBlocked.isNotEmpty) return fromBlocked;

    final fromFree = contactNormals(maze, freePos, radius);
    if (fromFree.isNotEmpty) return fromFree;

    // Midpoint between free and blocked — still real geometry, no invention.
    final mid = Offset(
      (freePos.dx + blockedPos.dx) * 0.5,
      (freePos.dy + blockedPos.dy) * 0.5,
    );
    return contactNormals(maze, mid, radius, skin: contactSkin * 4);
  }

  /// Project [v] so `dot(v, n) >= -eps` for every [normals] (Gauss–Seidel).
  ///
  /// Sequential single-pass projection can re-introduce inward motion against
  /// an earlier plane at corners; this re-applies until stable or capped.
  static Offset projectVelocity(
    Offset v,
    List<Offset> normals, {
    int maxPasses = 4,
    double eps = 1e-9,
  }) {
    var vx = v.dx;
    var vy = v.dy;
    for (var pass = 0; pass < maxPasses; pass++) {
      var changed = false;
      for (final n in normals) {
        final into = vx * n.dx + vy * n.dy;
        if (into < -eps) {
          vx -= n.dx * into;
          vy -= n.dy * into;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return Offset(vx, vy);
  }

  /// True when [v] does not point into any of [normals].
  static bool velocityOutwardOrTangent(
    Offset v,
    List<Offset> normals, {
    double eps = 1e-8,
  }) {
    for (final n in normals) {
      if (v.dx * n.dx + v.dy * n.dy < -eps) return false;
    }
    return true;
  }

  /// Move with normal-projection sliding. Large deltas are sub-stepped so
  /// thin wall segments cannot be tunneled in a single jump.
  static Offset slideMove(
    MazeGrid maze,
    Offset from,
    Offset delta,
    double radius, {
    double maxStep = 0.12,
  }) {
    return slideMoveStepped(
      maze,
      from,
      delta,
      radius,
      maxStep: maxStep,
    );
  }

  /// Sub-stepped [delta]; each step uses [_slideMoveOnce].
  static Offset slideMoveStepped(
    MazeGrid maze,
    Offset from,
    Offset delta,
    double radius, {
    double maxStep = 0.12,
  }) {
    final len = delta.distance;
    if (len <= 1e-9) return from;
    if (len <= maxStep) {
      return _slideMoveOnce(maze, from, delta, radius);
    }

    final steps = (len / maxStep).ceil();
    final inv = 1.0 / steps;
    final step = Offset(delta.dx * inv, delta.dy * inv);
    var pos = from;
    for (var i = 0; i < steps; i++) {
      pos = _slideMoveOnce(maze, pos, step, radius);
    }
    return pos;
  }

  /// One small step: TOI along delta, then clip remaining against contacts.
  static Offset _slideMoveOnce(
    MazeGrid maze,
    Offset from,
    Offset delta,
    double radius,
  ) {
    if (delta.dx == 0 && delta.dy == 0) return from;

    final full = Offset(from.dx + delta.dx, from.dy + delta.dy);
    if (!circleHitsWall(maze, full, radius)) return full;

    // Binary search: last free [atWall] and first known hit [firstHit].
    var lo = 0.0;
    var hi = 1.0;
    var atWall = from;
    var firstHit = full;
    for (var i = 0; i < _toiIterations; i++) {
      final mid = (lo + hi) * 0.5;
      final p = Offset(from.dx + delta.dx * mid, from.dy + delta.dy * mid);
      if (!circleHitsWall(maze, p, radius)) {
        atWall = p;
        lo = mid;
      } else {
        firstHit = p;
        hi = mid;
      }
    }

    final remT = 1.0 - lo;
    if (remT <= 1e-6) return atWall;

    final pre = Offset(delta.dx * remT, delta.dy * remT);

    // Geometry-based contacts (blocked sample), not a fixed 1e-3 nudge.
    final normals = contactsAlongHit(maze, atWall, firstHit, radius);
    if (normals.isEmpty) {
      // No reliable contact — keep last free pose (do not invent a normal).
      return atWall;
    }

    var remaining = projectVelocity(pre, normals);
    if (!velocityOutwardOrTangent(remaining, normals)) {
      return atWall;
    }

    // Wall friction: only when projection actually removed inward motion
    // (a real scrape). Pure tangent that never hits skips this path entirely.
    final removedInto = pre.dx * pre.dx + pre.dy * pre.dy -
        (remaining.dx * remaining.dx + remaining.dy * remaining.dy);
    if (removedInto > 1e-12) {
      remaining = Offset(
        remaining.dx * wallSlideFriction,
        remaining.dy * wallSlideFriction,
      );
    }

    if (remaining.dx * remaining.dx + remaining.dy * remaining.dy < 1e-12) {
      return atWall;
    }

    final slid = Offset(atWall.dx + remaining.dx, atWall.dy + remaining.dy);
    if (!circleHitsWall(maze, slid, radius)) {
      return slid;
    }

    // Corner: sliding along one plane may still hit the other — re-TOI the
    // remaining tangential move without inventing new normals.
    var lo2 = 0.0;
    var hi2 = 1.0;
    var best = atWall;
    for (var i = 0; i < _toiIterations; i++) {
      final mid = (lo2 + hi2) * 0.5;
      final p = Offset(
        atWall.dx + remaining.dx * mid,
        atWall.dy + remaining.dy * mid,
      );
      if (!circleHitsWall(maze, p, radius)) {
        best = p;
        lo2 = mid;
      } else {
        hi2 = mid;
      }
    }
    return best;
  }

  /// Nudge out of walls if overlapping after a resize / snap.
  static Offset resolvePenetration(
    MazeGrid maze,
    Offset p,
    double radius,
  ) {
    if (!circleHitsWall(maze, p, radius)) return p;
    const probes = <Offset>[
      Offset(0.02, 0),
      Offset(-0.02, 0),
      Offset(0, 0.02),
      Offset(0, -0.02),
      Offset(0.04, 0.04),
      Offset(-0.04, 0.04),
      Offset(0.04, -0.04),
      Offset(-0.04, -0.04),
    ];
    for (final d in probes) {
      final n = Offset(p.dx + d.dx, p.dy + d.dy);
      if (!circleHitsWall(maze, n, radius)) return n;
    }
    return p;
  }

  static double distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
