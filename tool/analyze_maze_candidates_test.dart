// Analysis-only. Run: flutter test tool/analyze_maze_candidates_test.dart
// Does not modify game runtime behavior.

import 'dart:collection';
import 'dart:io';

import 'package:blind_weekly_maze/features/maze/data/dfs_maze_generator.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_cell.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_grid.dart';
import 'package:flutter_test/flutter_test.dart';

final class MazeMetrics {
  MazeMetrics({
    required this.seed,
    required this.size,
    required this.start,
    required this.exit,
    required this.shortestLen,
    required this.turnsOnPath,
    required this.junctionCount,
    required this.deadEndCount,
    required this.avgDeadEndDepth,
    required this.maxDeadEndDepth,
    required this.detourPenaltySum,
    required this.branchOffPathCount,
    required this.avgBranchDetour,
  });

  final int seed;
  final int size;
  final GridPos start;
  final GridPos exit;
  final int shortestLen;
  final int turnsOnPath;
  final int junctionCount;
  final int deadEndCount;
  final double avgDeadEndDepth;
  final int maxDeadEndDepth;
  final int detourPenaltySum;
  final int branchOffPathCount;
  final double avgBranchDetour;
}

int openDegree(MazeCell c) {
  var n = 0;
  if (!c.north) n++;
  if (!c.south) n++;
  if (!c.west) n++;
  if (!c.east) n++;
  return n;
}

List<GridPos> openNeighbors(MazeGrid maze, GridPos p) {
  final cell = maze.cellAt(p);
  final out = <GridPos>[];
  if (!cell.north) out.add(GridPos(p.row - 1, p.col));
  if (!cell.south) out.add(GridPos(p.row + 1, p.col));
  if (!cell.west) out.add(GridPos(p.row, p.col - 1));
  if (!cell.east) out.add(GridPos(p.row, p.col + 1));
  return out;
}

String posKey(GridPos p) => '${p.row},${p.col}';

({int length, List<GridPos> path}) shortestPath(MazeGrid maze) {
  final n = maze.size;
  final dist = List.generate(n, (_) => List.filled(n, -1));
  final parent = List.generate(n, (_) => List<GridPos?>.filled(n, null));
  final q = Queue<GridPos>()..add(maze.start);
  dist[maze.start.row][maze.start.col] = 0;

  while (q.isNotEmpty) {
    final cur = q.removeFirst();
    if (cur == maze.exit) break;
    for (final nb in openNeighbors(maze, cur)) {
      if (dist[nb.row][nb.col] >= 0) continue;
      dist[nb.row][nb.col] = dist[cur.row][cur.col] + 1;
      parent[nb.row][nb.col] = cur;
      q.add(nb);
    }
  }

  final len = dist[maze.exit.row][maze.exit.col];
  if (len < 0) return (length: -1, path: <GridPos>[]);

  final path = <GridPos>[];
  GridPos? cur = maze.exit;
  while (cur != null) {
    path.add(cur);
    if (cur == maze.start) break;
    cur = parent[cur.row][cur.col];
  }
  return (length: len, path: path.reversed.toList());
}

int countTurns(List<GridPos> path) {
  if (path.length < 3) return 0;
  var turns = 0;
  for (var i = 1; i < path.length - 1; i++) {
    final dr1 = path[i].row - path[i - 1].row;
    final dc1 = path[i].col - path[i - 1].col;
    final dr2 = path[i + 1].row - path[i].row;
    final dc2 = path[i + 1].col - path[i].col;
    if (dr1 != dr2 || dc1 != dc2) turns++;
  }
  return turns;
}

int deadEndDepthFromLeaf(MazeGrid maze, GridPos leaf) {
  var depth = 0;
  var prev = leaf;
  var cur = leaf;
  while (true) {
    final deg = openDegree(maze.cellAt(cur));
    if (deg >= 3) break;
    if (cur == maze.start || cur == maze.exit) break;
    final nbs = openNeighbors(maze, cur);
    GridPos? next;
    for (final nb in nbs) {
      if (nb != prev) {
        next = nb;
        break;
      }
    }
    if (next == null) break;
    prev = cur;
    cur = next;
    depth++;
    if (depth > maze.size * maze.size) break;
  }
  return depth;
}

List<GridPos> findDeadEnds(MazeGrid maze) {
  final out = <GridPos>[];
  for (var r = 0; r < maze.size; r++) {
    for (var c = 0; c < maze.size; c++) {
      final p = GridPos(r, c);
      if (p == maze.start || p == maze.exit) continue;
      if (openDegree(maze.cellAt(p)) == 1) out.add(p);
    }
  }
  return out;
}

int spurLength(MazeGrid maze, GridPos branchStart, GridPos avoid) {
  final q = Queue<GridPos>()..add(branchStart);
  final dist = <String, int>{posKey(branchStart): 0};
  var maxD = 0;
  while (q.isNotEmpty) {
    final cur = q.removeFirst();
    final d = dist[posKey(cur)]!;
    if (d > maxD) maxD = d;
    for (final nb in openNeighbors(maze, cur)) {
      if (nb == avoid) continue;
      final k = posKey(nb);
      if (dist.containsKey(k)) continue;
      dist[k] = d + 1;
      q.add(nb);
    }
  }
  return maxD;
}

MazeMetrics analyze(MazeGrid maze) {
  final sp = shortestPath(maze);
  final path = sp.path;
  final pathSet = path.map(posKey).toSet();

  var junctions = 0;
  for (var r = 0; r < maze.size; r++) {
    for (var c = 0; c < maze.size; c++) {
      if (openDegree(maze.cells[r][c]) >= 3) junctions++;
    }
  }

  final deadEnds = findDeadEnds(maze);
  var depthSum = 0;
  var maxDepth = 0;
  for (final leaf in deadEnds) {
    final d = deadEndDepthFromLeaf(maze, leaf);
    depthSum += d;
    if (d > maxDepth) maxDepth = d;
  }

  var detourSum = 0;
  var branchCount = 0;
  for (var i = 0; i < path.length; i++) {
    final cur = path[i];
    final prev = i > 0 ? path[i - 1] : null;
    final next = i + 1 < path.length ? path[i + 1] : null;
    for (final nb in openNeighbors(maze, cur)) {
      if (nb == prev || nb == next) continue;
      if (pathSet.contains(posKey(nb))) continue;
      final spur = spurLength(maze, nb, cur);
      detourSum += 2 * (spur + 1);
      branchCount++;
    }
  }

  return MazeMetrics(
    seed: maze.seed,
    size: maze.size,
    start: maze.start,
    exit: maze.exit,
    shortestLen: sp.length,
    turnsOnPath: countTurns(path),
    junctionCount: junctions,
    deadEndCount: deadEnds.length,
    avgDeadEndDepth: deadEnds.isEmpty ? 0.0 : depthSum / deadEnds.length,
    maxDeadEndDepth: maxDepth,
    detourPenaltySum: detourSum,
    branchOffPathCount: branchCount,
    avgBranchDetour: branchCount == 0 ? 0.0 : detourSum / branchCount,
  );
}

double pct(Iterable<num> values, double p) {
  final a = values.map((e) => e.toDouble()).toList()..sort();
  if (a.isEmpty) return 0;
  final i = ((a.length - 1) * p).clamp(0, a.length - 1);
  final lo = i.floor();
  final hi = i.ceil();
  if (lo == hi) return a[lo];
  final t = i - lo;
  return a[lo] * (1 - t) + a[hi] * t;
}

final class PoolStats {
  PoolStats(List<MazeMetrics> list)
      : lenP25 = pct(list.map((e) => e.shortestLen), 0.25),
        lenP50 = pct(list.map((e) => e.shortestLen), 0.50),
        lenP75 = pct(list.map((e) => e.shortestLen), 0.75),
        turnP25 = pct(list.map((e) => e.turnsOnPath), 0.25),
        turnP50 = pct(list.map((e) => e.turnsOnPath), 0.50),
        turnP75 = pct(list.map((e) => e.turnsOnPath), 0.75),
        juncP25 = pct(list.map((e) => e.junctionCount), 0.25),
        juncP50 = pct(list.map((e) => e.junctionCount), 0.50),
        juncP75 = pct(list.map((e) => e.junctionCount), 0.75),
        maxDepP25 = pct(list.map((e) => e.maxDeadEndDepth), 0.25),
        maxDepP50 = pct(list.map((e) => e.maxDeadEndDepth), 0.50),
        maxDepP75 = pct(list.map((e) => e.maxDeadEndDepth), 0.75),
        detP25 = pct(list.map((e) => e.avgBranchDetour), 0.25),
        detP50 = pct(list.map((e) => e.avgBranchDetour), 0.50),
        detP75 = pct(list.map((e) => e.avgBranchDetour), 0.75),
        detSumP95 = pct(list.map((e) => e.detourPenaltySum), 0.95);

  final double lenP25, lenP50, lenP75;
  final double turnP25, turnP50, turnP75;
  final double juncP25, juncP50, juncP75;
  final double maxDepP25, maxDepP50, maxDepP75;
  final double detP25, detP50, detP75;
  final double detSumP95;
}

double band(num v, num p25, num p50, num p75, String prefer) {
  switch (prefer) {
    case 'low':
      if (v <= p25) return 10;
      if (v <= p50) return 6;
      if (v <= p75) return 2;
      return -4;
    case 'lowmid':
      if (v >= p25 && v <= p50) return 10;
      if (v < p25) return 5;
      if (v <= p75) return 4;
      return -2;
    case 'mid':
      if (v >= p25 && v <= p75) return 10;
      if ((v - p50).abs() <= (p75 - p25)) return 5;
      return -3;
    case 'highmid':
      if (v >= p50 && v <= p75) return 10;
      if (v > p75 && v <= p75 + (p75 - p50)) return 6;
      if (v >= p25) return 3;
      return -2;
    case 'high':
      if (v >= p75) return 10;
      if (v >= p50) return 6;
      if (v >= p25) return 2;
      return -4;
    default:
      return 0;
  }
}

double scoreEasy(MazeMetrics m, PoolStats s) {
  var score = 0.0;
  score += band(m.shortestLen, s.lenP25, s.lenP50, s.lenP75, 'lowmid');
  score += band(m.turnsOnPath, s.turnP25, s.turnP50, s.turnP75, 'low');
  score += band(m.junctionCount, s.juncP25, s.juncP50, s.juncP75, 'lowmid');
  score +=
      band(m.maxDeadEndDepth, s.maxDepP25, s.maxDepP50, s.maxDepP75, 'low');
  score += band(m.avgBranchDetour, s.detP25, s.detP50, s.detP75, 'lowmid');
  if (m.shortestLen < m.size) score -= 50;
  return score;
}

double scoreNormal(MazeMetrics m, PoolStats s) {
  var score = 0.0;
  score += band(m.shortestLen, s.lenP25, s.lenP50, s.lenP75, 'mid');
  score += band(m.turnsOnPath, s.turnP25, s.turnP50, s.turnP75, 'mid');
  score += band(m.junctionCount, s.juncP25, s.juncP50, s.juncP75, 'mid');
  score +=
      band(m.maxDeadEndDepth, s.maxDepP25, s.maxDepP50, s.maxDepP75, 'mid');
  score += band(m.avgBranchDetour, s.detP25, s.detP50, s.detP75, 'mid');
  return score;
}

double scoreHard(MazeMetrics m, PoolStats s) {
  var score = 0.0;
  score += band(m.shortestLen, s.lenP25, s.lenP50, s.lenP75, 'highmid');
  score += band(m.turnsOnPath, s.turnP25, s.turnP50, s.turnP75, 'high');
  score += band(m.junctionCount, s.juncP25, s.juncP50, s.juncP75, 'high');
  score +=
      band(m.maxDeadEndDepth, s.maxDepP25, s.maxDepP50, s.maxDepP75, 'high');
  score += band(m.avgBranchDetour, s.detP25, s.detP50, s.detP75, 'highmid');
  if (m.detourPenaltySum > s.detSumP95) score -= 15;
  return score;
}

String row(MazeMetrics m) =>
    '| ${m.seed} | ${m.size} | ${m.shortestLen} | ${m.turnsOnPath} | '
    '${m.junctionCount} | ${m.deadEndCount} | '
    '${m.avgDeadEndDepth.toStringAsFixed(2)} | ${m.maxDeadEndDepth} | '
    '${m.detourPenaltySum} | ${m.avgBranchDetour.toStringAsFixed(1)} | '
    '${m.start} → ${m.exit} |';

const tableHeader =
    '| seed | size | 최단경로 | 방향전환 | 갈림길 | 막다른길 | '
    '막다른평균깊이 | 최심막다른 | 우회합(왕복) | 평균우회 | start→exit |';

void main() {
  test('analyze fixed maze candidates and write report', () {
    const gen = DfsMazeGenerator();
    const nCandidates = 50;
    final tiers = <String, int>{'하': 15, '중': 21, '상': 27};
    final buf = StringBuffer();
    final finals = <String, MazeMetrics>{};
    final allByTier = <String, List<MazeMetrics>>{};

    buf.writeln('# 고정 미로 후보 분석 보고서');
    buf.writeln();
    buf.writeln('생성 시각: ${DateTime.now().toIso8601String()}');
    buf.writeln();
    buf.writeln(
        '생성기: `DfsMazeGenerator` Growing Tree (`_randomFrontierBias=0.88`)');
    buf.writeln('후보 수: 난이도별 $nCandidates개');
    buf.writeln('시드: 하=`1000..1049`, 중=`2000..2049`, 상=`3000..3049`');
    buf.writeln();
    buf.writeln('## 지표 정의');
    buf.writeln();
    buf.writeln('1. **최단 경로 길이**: start→exit BFS 스텝 수');
    buf.writeln('2. **방향 전환**: 최단 경로 위 진행 방향 변경 횟수');
    buf.writeln('3. **갈림길**: 통로 차수 ≥ 3인 셀 수');
    buf.writeln('4. **막다른 길**: 통로 차수 = 1 (start/exit 제외)');
    buf.writeln('5. **막다른 평균 깊이**: 잎→첫 갈림길(또는 start/exit) 거리 평균');
    buf.writeln('6. **최심 막다른 깊이**: 위 깊이의 최댓값');
    buf.writeln(
        '7. **우회 거리**: 최단경로에서 분기한 가지의 `(spur+1)×2` 합 (잘못 들어갔다 나오는 왕복 비용)');
    buf.writeln();
    buf.writeln('## 플레이 조건 검토 (게임 코드 미변경)');
    buf.writeln();
    buf.writeln('- `playerRadius = 0.30`, 벽 두께 비율 `0.28`');
    buf.writeln(
        '- 충돌은 셀 엣지 헤어라인; Growing Tree 통로는 1셀 폭 → 중심 이동 가능');
    buf.writeln(
        '- 시각 통로 `0.44` < 지름 `0.60` → 벽 밀착 시 그래픽 겹침은 엔진 특성(후보와 무관)');
    buf.writeln('- 특수 협로 없음 → 현재 연속 이동으로 통과 가능');
    buf.writeln();

    for (final e in tiers.entries) {
      final label = e.key;
      final size = e.value;
      final offset = switch (label) {
        '하' => 1000,
        '중' => 2000,
        _ => 3000,
      };

      final metrics = <MazeMetrics>[];
      for (var i = 0; i < nCandidates; i++) {
        final seed = offset + i;
        final maze = gen.generate(size: size, seed: seed);
        final m = analyze(maze);
        expect(m.shortestLen, greaterThan(0),
            reason: 'seed $seed must be solvable');
        expect(maze.start, const GridPos(0, 0));
        metrics.add(m);
      }
      allByTier[label] = metrics;

      final stats = PoolStats(metrics);
      final scored = metrics.map((m) {
        final s = switch (label) {
          '하' => scoreEasy(m, stats),
          '중' => scoreNormal(m, stats),
          _ => scoreHard(m, stats),
        };
        return (m: m, score: s);
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final top3 = scored.take(3).toList();
      finals[label] = top3.first.m;

      buf.writeln('## 난이도 $label ($size×$size)');
      buf.writeln();
      buf.writeln(
          '풀 통계 n=${metrics.length}: 최단 P25/P50/P75='
          '${stats.lenP25.toStringAsFixed(1)}/'
          '${stats.lenP50.toStringAsFixed(1)}/'
          '${stats.lenP75.toStringAsFixed(1)}; '
          '전환P50=${stats.turnP50.toStringAsFixed(1)}; '
          '갈림P50=${stats.juncP50.toStringAsFixed(1)}; '
          '최심P50=${stats.maxDepP50.toStringAsFixed(1)}; '
          '평균우회P50=${stats.detP50.toStringAsFixed(1)}');
      buf.writeln();
      buf.writeln('### 추천 후보 Top 3');
      buf.writeln();
      buf.writeln(tableHeader);
      buf.writeln('|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|');
      for (final t in top3) {
        buf.writeln(row(t.m));
      }
      buf.writeln();

      for (var i = 0; i < top3.length; i++) {
        final m = top3[i].m;
        final reason = switch (label) {
          '하' => i == 0
              ? '최단·전환·깊은 함정이 하위~중하로 직관적이나, 우회합 ${m.detourPenaltySum}으로 기록 단축 여지 유지.'
              : '하 적합 지표 유사, 점수 ${top3[i].score.toStringAsFixed(1)} 차순위.',
          '중' => i == 0
              ? '최단·갈림·막다른 깊이가 풀 중앙대 — 판단형 난이도 균형.'
              : '중 중앙대 근접 (score ${top3[i].score.toStringAsFixed(1)}).',
          _ => i == 0
              ? '전환·갈림·최심 막다른 상위권 + 우회합이 P95 폭주 회피.'
              : '상 고난도 후보 (score ${top3[i].score.toStringAsFixed(1)}).',
        };
        buf.writeln('- **${i + 1}순위 seed `${m.seed}`** (score '
            '${top3[i].score.toStringAsFixed(1)}): $reason');
      }
      buf.writeln();
      buf.writeln('### 최종 추천 1개');
      buf.writeln();
      final best = top3.first.m;
      buf.writeln('- **seed `${best.seed}`**, **${best.size}×${best.size}**');
      buf.writeln('- start **${best.start}**, exit **${best.exit}**');
      buf.writeln(
          '- 재현: `DfsMazeGenerator().generate(size: ${best.size}, seed: ${best.seed})`');
      buf.writeln();
    }

    buf.writeln('## 최종 선정 요약');
    buf.writeln();
    buf.writeln(
        '| 난이도 | size | seed | start | exit | 최단 | 전환 | 갈림 | 막다른 | 최심 | 우회합 |');
    buf.writeln('|---|---:|---:|---|---|---:|---:|---:|---:|---:|---:|');
    for (final e in finals.entries) {
      final m = e.value;
      buf.writeln('| ${e.key} | ${m.size} | ${m.seed} | ${m.start} | ${m.exit} | '
          '${m.shortestLen} | ${m.turnsOnPath} | ${m.junctionCount} | '
          '${m.deadEndCount} | ${m.maxDeadEndDepth} | ${m.detourPenaltySum} |');
    }
    buf.writeln();
    buf.writeln('## 향후 고정 데이터 저장 작업');
    buf.writeln();
    buf.writeln('1. 선정 seed로 MazeGrid 생성 → 셀 벽 JSON/Dart const 직렬화');
    buf.writeln('2. mazeId + start/exit/size/seed 메타 고정');
    buf.writeln('3. boardKey를 난이도별 고정 키로 랭킹 분리');
    buf.writeln('4. GameController 고정 로더 전환 (생성기는 검증용 유지)');
    buf.writeln('5. CI에서 최단경로·도달 불변 테스트');
    buf.writeln('6. 맵 변경 시 새 mazeId + 랭킹 리셋');
    buf.writeln();
    buf.writeln('## 전체 후보 표 (난이도별 50)');
    buf.writeln();
    for (final e in allByTier.entries) {
      buf.writeln('### ${e.key}');
      buf.writeln();
      buf.writeln(tableHeader);
      buf.writeln('|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|');
      for (final m in e.value) {
        buf.writeln(row(m));
      }
      buf.writeln();
    }

    final out = File('maze_fixed_candidates_report.md');
    out.writeAsStringSync(buf.toString());
    // ignore: avoid_print
    print('Wrote ${out.absolute.path}');
    for (final e in finals.entries) {
      final m = e.value;
      // ignore: avoid_print
      print('${e.key}: seed=${m.seed} ${m.start}->${m.exit} '
          'len=${m.shortestLen} turns=${m.turnsOnPath} '
          'junc=${m.junctionCount} dead=${m.deadEndCount} '
          'maxDep=${m.maxDeadEndDepth} detour=${m.detourPenaltySum}');
    }

    expect(finals.length, 3);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
