import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../data/dfs_maze_generator.dart';
import '../../data/fixed_maze_catalog.dart';
import '../../domain/collision.dart';
import '../../domain/difficulty.dart';
import '../../domain/fixed_maze_definition.dart';
import '../../domain/game_mode.dart';
import '../../domain/maze_cell.dart';
import '../../domain/maze_grid.dart';
import 'hint_controller.dart';
import 'timer_controller.dart';

enum GamePhase { ready, playing, cleared }

/// Continuous analog movement driven by [stick] + vsync [Ticker].
final class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    bool Function()? isAdminMode,
    MazeGenerator? generator,
  })  : _isAdminMode = isAdminMode ?? (() => false),
        _generator = generator ?? const DfsMazeGenerator() {
    timer = TimerController();
    hints = HintController(
      timer: timer,
      onAdPause: _pauseForAd,
      onAdResume: _resumeAfterAd,
      isAdminMode: _isAdminMode,
    );

    _maze = _createMaze();
    _tile = _maze.start;
    playerPos = ValueNotifier(MazeCollision.cellCenter(_tile));
    stick = ValueNotifier(Offset.zero);
    revealListenable = ValueNotifier(false);

    hints.addListener(_onHintsChanged);
  }

  final GameMode mode;
  final MazeGenerator _generator;
  final bool Function() _isAdminMode;

  late final TimerController timer;
  late final HintController hints;
  late final ValueNotifier<Offset> playerPos;
  late final ValueNotifier<Offset> stick;
  late final ValueNotifier<bool> revealListenable;
  late MazeGrid _maze;
  late GridPos _tile;

  /// Set only for [FixedChallengeMode] loads.
  String? _fixedMazeId;
  String? _fixedChecksum;
  bool _usedProceduralGenerator = false;

  GamePhase _phase = GamePhase.ready;
  bool _userPaused = false;
  bool _adPaused = false;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _tickerAttached = false;
  bool _moving = false;

  /// Current velocity in cells/second (smoothed toward stick target).
  double _velX = 0;
  double _velY = 0;

  /// Max speed in cells/second at full stick deflection.
  static const double maxSpeed = 5.8;

  /// How quickly velocity catches the stick target (higher = snappier).
  /// ~16 → near full speed in ~0.2s; reverse still has visible weight.
  static const double velocityResponse = 16.0;

  /// Ignore tiny residual stick noise after deadzone.
  static const double stickThreshold = 0.02;

  /// Collision / draw radius (cell-space) — shared with board painter.
  static const double playerRadius = MazeCollision.playerRadius;

  /// Exponential approach of [current] → [target] (frame-rate independent).
  static Offset approachVelocity(
    Offset current,
    Offset target,
    double dt, {
    double response = velocityResponse,
  }) {
    if (dt <= 0) return current;
    final t = 1.0 - exp(-response * dt);
    return Offset(
      current.dx + (target.dx - current.dx) * t,
      current.dy + (target.dy - current.dy) * t,
    );
  }

  MazeGrid get maze => _maze;
  GridPos get playerCell => _tile;
  GamePhase get phase => _phase;
  bool get isUserPaused => _userPaused;
  bool get canTogglePause => _phase == GamePhase.playing;
  bool get isAdminMode => _isAdminMode();
  bool get isFullReveal => hints.isRevealing || isAdminMode;
  int get visionRadius => 1;
  bool get isMoving => _moving;

  /// Non-null when this session loaded a frozen ranked maze.
  String? get fixedMazeId => _fixedMazeId;
  String? get fixedChecksum => _fixedChecksum;

  /// True when Practice/Weekly used [DfsMazeGenerator] (false for Fixed).
  bool get usedProceduralGenerator => _usedProceduralGenerator;

  MazeGrid _createMaze() {
    switch (mode) {
      case FixedChallengeMode(
          :final mazeId,
          :final difficulty,
          :final boardKey,
        ):
        final def = FixedMazeCatalog.definition(mazeId);
        _validateFixedDefinition(def, mazeId, difficulty, boardKey);
        final grid = def.toMazeGrid();
        if (grid.size != def.size ||
            grid.start != def.start ||
            grid.exit != def.exit ||
            !def.wallsEqualToGrid(grid)) {
          throw StateError(
            'Fixed maze snapshot materialization failed for $mazeId',
          );
        }
        _fixedMazeId = def.mazeId;
        _fixedChecksum = def.checksum;
        _usedProceduralGenerator = false;
        return grid;
      case PracticeMode(:final seed):
      case WeeklyChallengeMode(:final seed):
        _usedProceduralGenerator = true;
        _fixedMazeId = null;
        _fixedChecksum = null;
        return _generator.generate(size: mode.mazeSize, seed: seed);
    }
  }

  void _validateFixedDefinition(
    FixedMazeDefinition def,
    String mazeId,
    Difficulty difficulty,
    String boardKey,
  ) {
    if (def.mazeId != mazeId) {
      throw StateError(
        'Fixed maze id mismatch: mode=$mazeId dump=${def.mazeId}',
      );
    }
    if (def.size != difficulty.size) {
      throw StateError(
        'Fixed maze size mismatch for $mazeId: '
        'dump=${def.size} expected=${difficulty.size}',
      );
    }
    if (def.difficulty != difficulty.name) {
      throw StateError(
        'Fixed maze difficulty mismatch for $mazeId: '
        'dump=${def.difficulty} expected=${difficulty.name}',
      );
    }
    if (!def.checksumValid) {
      throw StateError('Fixed maze checksum invalid for $mazeId');
    }
    // boardKey is mode metadata; ensure known mapping stays consistent.
    final expectedBoard = switch (difficulty) {
      Difficulty.veryEasy => 'fixed_very_easy',
      Difficulty.easy => 'fixed_easy',
      Difficulty.normal => 'fixed_normal',
      Difficulty.hard => 'fixed_hard',
      Difficulty.veryHard => 'fixed_very_hard',
    };
    if (boardKey != expectedBoard) {
      throw StateError(
        'Fixed maze boardKey mismatch for $mazeId: '
        'mode=$boardKey expected=$expectedBoard',
      );
    }
  }

  void _onHintsChanged() {
    revealListenable.value = isFullReveal;
    notifyListeners();
  }

  void attachTicker(TickerProvider vsync) {
    if (_tickerAttached) return;
    _tickerAttached = true;
    _lastTick = Duration.zero;
    _ticker = vsync.createTicker(_onTick);
  }

  Future<void> start() async {
    if (_phase != GamePhase.ready) return;
    _phase = GamePhase.playing;
    await hints.preloadAd();
    timer.start();
    _ticker?.start();
    revealListenable.value = isFullReveal;
    notifyListeners();
  }

  void _clearVelocity() {
    _velX = 0;
    _velY = 0;
  }

  void _onTick(Duration elapsed) {
    if (_phase != GamePhase.playing || _userPaused || timer.isPaused) {
      _lastTick = elapsed;
      _moving = false;
      return;
    }

    final dtMs = _lastTick == Duration.zero
        ? 16.0
        : (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    // Cap spike frames so a hitch cannot tunnel through walls.
    final dt = (dtMs / 1000.0).clamp(0.0, 0.05);

    final v = stick.value;
    final mag = v.distance;
    // Release policy: immediate stop — no coasting inertia.
    if (mag < stickThreshold) {
      _clearVelocity();
      _moving = false;
      return;
    }

    // Target velocity from stick (unit dir × mag × maxSpeed).
    final inv = 1.0 / mag;
    final target = Offset(
      v.dx * inv * maxSpeed * mag.clamp(0.0, 1.0),
      v.dy * inv * maxSpeed * mag.clamp(0.0, 1.0),
    );
    final smoothed = approachVelocity(
      Offset(_velX, _velY),
      target,
      dt,
    );
    _velX = smoothed.dx;
    _velY = smoothed.dy;

    final delta = Offset(_velX * dt, _velY * dt);
    if (delta.dx * delta.dx + delta.dy * delta.dy < 1e-14) {
      _moving = true; // stick held, still spooling up
      return;
    }

    final from = playerPos.value;
    final next = MazeCollision.slideMoveStepped(
      _maze,
      from,
      delta,
      playerRadius,
    );

    if (next == from) {
      _moving = true;
      return;
    }

    _moving = true;
    playerPos.value = next;
    _tile = MazeCollision.cellOf(next);
    _checkClear();
  }

  void _checkClear() {
    if (_tile == _maze.exit) {
      _onClear();
    }
  }

  void pause() {
    if (!canTogglePause || _userPaused) return;
    _userPaused = true;
    stick.value = Offset.zero;
    _clearVelocity();
    _moving = false;
    timer.pause();
    notifyListeners();
  }

  void resume() {
    if (!canTogglePause || !_userPaused) return;
    _userPaused = false;
    _lastTick = Duration.zero; // avoid huge dt after pause
    if (!_adPaused) timer.resume();
    notifyListeners();
  }

  void togglePause() {
    if (_userPaused) {
      resume();
    } else {
      pause();
    }
  }

  void refreshAdminState() {
    hints.refreshLimits();
    revealListenable.value = isFullReveal;
    notifyListeners();
  }

  void _pauseForAd() {
    _adPaused = true;
    stick.value = Offset.zero;
    _clearVelocity();
    _moving = false;
    timer.pause();
    notifyListeners();
  }

  void _resumeAfterAd() {
    _adPaused = false;
    _lastTick = Duration.zero;
    if (!_userPaused) timer.resume();
    notifyListeners();
  }

  /// Discrete pad / test helpers — one short slide along [dir].
  void queueDir(GridPos dir) {
    if (_phase != GamePhase.playing || _userPaused || timer.isPaused) return;
    final delta = Offset(dir.col * 0.35, dir.row * 0.35);
    final next = MazeCollision.slideMoveStepped(
      _maze,
      playerPos.value,
      delta,
      playerRadius,
    );
    playerPos.value = next;
    _tile = MazeCollision.cellOf(next);
    _checkClear();
  }

  void moveUp() => queueDir(const GridPos(-1, 0));
  void moveDown() => queueDir(const GridPos(1, 0));
  void moveLeft() => queueDir(const GridPos(0, -1));
  void moveRight() => queueDir(const GridPos(0, 1));

  void _onClear() {
    if (_phase == GamePhase.cleared) return;
    timer.stop();
    stick.value = Offset.zero;
    _clearVelocity();
    _moving = false;
    // Snap visually to exit cell center for a clean finish frame.
    _tile = _maze.exit;
    playerPos.value = MazeCollision.cellCenter(_tile);
    _ticker?.stop();
    _phase = GamePhase.cleared;
    notifyListeners();
  }

  static int randomSeed([Random? rng]) =>
      (rng ?? Random()).nextInt(1 << 31);

  @override
  void dispose() {
    hints.removeListener(_onHintsChanged);
    _ticker?.dispose();
    hints.dispose();
    timer.dispose();
    playerPos.dispose();
    stick.dispose();
    revealListenable.dispose();
    super.dispose();
  }
}
