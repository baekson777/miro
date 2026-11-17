# Maze Game Diagnostic Report
생성일: 2026-11-15  
범위: 조이스틱 연동 · 플레이어 이동 끊김 분석용 코드 수집  
주의: 기존 소스 코드는 수정하지 않음. 민감 정보 없음. 확인하지 않은 항목은 **미확인**으로 표기.

---

## A. 프로젝트의 전체 폴더 구조 중 게임 관련 부분

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── debug/
│   ├── navigation/
│   └── theme/
└── features/
    ├── ads/
    ├── home/presentation/screens/
    ├── leaderboard/
    ├── security/
    └── maze/
        ├── data/
        │   ├── dfs_maze_generator.dart
        │   └── weekly_seed_service.dart
        ├── domain/
        │   ├── collision.dart
        │   ├── difficulty.dart
        │   ├── game_mode.dart
        │   ├── maze_cell.dart
        │   └── maze_grid.dart
        └── presentation/
            ├── controllers/
            │   ├── game_controller.dart
            │   ├── hint_controller.dart
            │   └── timer_controller.dart
            ├── screens/
            │   ├── game_screen.dart
            │   └── result_screen.dart
            └── widgets/
                ├── dpad_controls.dart   # 현재 GameScreen에서 미사용(고아 파일)
                ├── game_hud.dart
                ├── maze_board.dart
                ├── maze_wall_cache.dart
                └── virtual_joystick.dart
```

플랫폼: `android/`, `ios/` 존재. `web/` 폴더는 **없음**(워크스페이스 검색 기준).

---

## 조사 요약 (항목 1–5)

### 1. 조이스틱 입력 처리
| 항목 | 확인 내용 |
|------|-----------|
| 구현 파일 | `lib/features/maze/presentation/widgets/virtual_joystick.dart` |
| 입력 이벤트 | `Listener`: `onPointerDown` / `onPointerMove` / `onPointerUp` / `onPointerCancel` |
| 방향 계산 | `atan2` 각도 → ±45° 사분면으로 상하좌우 단위 벡터 스냅 |
| 데드존 | `deadZone = 0.28` (max travel 대비 비율) |
| 출력 | `ValueNotifier<Offset> vector` → `Offset.zero` 또는 `(±1,0)/(0,±1)` |
| 연결 | `GameScreen`이 `VirtualJoystick(vector: _controller.stick)` 전달 |

### 2. 플레이어 이동
| 항목 | 확인 내용 |
|------|-----------|
| 위치 | `GameController.playerPos` (`ValueNotifier<Offset>`, 셀 좌표 중심) |
| 논리 타일 | `_tile` (`GridPos`) |
| 속도 | 연속 속도 없음. 칸당 `stepSeconds = 0.11` 고정 시간 보간 |
| Delta Time | `_onTick`에서 `dt` 계산 후 `_moveT += dt / stepSeconds` |
| 대각선 | 조이스틱이 4방향만 출력; 컨트롤러도 주축 1개만 선택 |
| 충돌 | 이동 시작 시 `MazeCollision.canStep`만 사용. `slideMove`/`circleHitsWall`은 **현재 이동 루프에서 미호출** |

### 3. 게임 루프 및 렌더링
| 항목 | 확인 내용 |
|------|-----------|
| Ticker | `GameController.attachTicker` → `vsync.createTicker(_onTick)` |
| AnimationController | 플레이어 이동에는 **미사용** (`Curves.easeOutCubic`만 수동 적용) |
| Timer | `TimerController`: 스톱워치용 `Timer.periodic(10ms)` |
| CustomPainter | 벽 Picture, Fog/Player, Joystick knob |
| Rebuild | 이동 시 Scaffold 전체 setState 없음. `playerPos` → `ValueListenableBuilder`만 동적 레이어 갱신. HUD는 timer 10ms마다 `ListenableBuilder` 갱신 |

### 4. 게임 구조 · 패키지
- 맵: `MazeGrid` + `List<List<MazeCell>>` (N/E/S/W 벽 플래그)
- 상태 전달: Joystick → `stick` → Ticker → `playerPos` → `DynamicPlayerFogLayer`
- 직접 의존 (pubspec / lock): go_router 14.8.1, flutter_riverpod 2.6.1, google_mobile_ads 7.0.0, screen_protector 1.5.3, shared_preferences 2.5.6, timezone 0.10.1, equatable 2.1.0, uuid 4.6.0

### 5. 성능·입력 잠재 이슈 (코드 근거)
- HUD가 타이머 `notifyListeners`를 **10ms 주기**로 수신 → 위젯 트리 상단 빈번 rebuild 가능
- 이동 중 매 프레임 fog `Path` 재생성 + evenOdd 채우기
- 조이스틱 방향 변경마다 `HapticFeedback.selectionClick()`
- 칸 단위 스텝(0.11s)이라 연속 아날로그 이동 대비 "끊김"으로 체감될 수 있음(설계 특성)
- Flutter Web 실기기 실행 여부: **미확인** (`web/` 폴더 없음)
- 브라우저 마우스 vs 모바일 터치 실측 비교: **미확인** (코드상 동일 `Pointer` 이벤트 API 사용)

---

## D. 각 파일의 역할과 파일 간 연결 관계

```
GameScreen
  ├─ creates GameController
  ├─ attachTicker(this)
  ├─ VirtualJoystick(vector: controller.stick)
  ├─ MazeBoard(playerPos, revealListenable, maze)
  └─ GameHud(controller) ── Listenable.merge(hints, timer)

VirtualJoystick ──writes──> stick (ValueNotifier<Offset>)
GameController._onTick ──reads──> stick
  └─ _tryBeginStep / lerp ──writes──> playerPos
MazeBoard.DynamicPlayerFogLayer ──listens──> playerPos, revealListenable
MazeBoard.StaticMazeLayer ──bakes once──> ui.Picture (walls)
GameController ──uses──> MazeCollision.canStep, DfsMazeGenerator, MazeGrid
```

---

## E. 현재 코드에서 발견한 잠재적 문제점

1. **이동 모델이 칸 스냅 스텝**이라 프레임 보간은 있어도 "틱틱" 체감 가능 (`stepSeconds=0.11`).
2. **`collision.dart`의 slideMove 계열은 이동 루프에서 미사용** — 주석과 실제 경로 불일치, 혼란 가능.
3. **`TimerController` 100Hz notify** → `GameHud` 빈번 rebuild (플레이어 레이어와 별개이나 메인 스레드 부하).
4. **동적 레이어 fog Path 매 프레임 할당** — 이동 보간 동안 GC/CPU 비용.
5. **`dpad_controls.dart`는 GameScreen에서 미참조** — 고아 코드.
6. 조이스틱이 방향을 **변경될 때만** `vector`를 갱신 — 값은 유지되므로 홀드는 동작하나, 동일 방향 재진입 시 엣지 케이스 여부는 런타임 **미확인**.
7. Flutter Web 전용 이슈(포인터 캡처, 포커스 등)는 이 저장소에 web 타깃이 없어 **미확인**.

---

## F. 추가로 확인해야 할 파일

- `lib/features/maze/presentation/controllers/hint_controller.dart` (reveal/pause와 stick 클리어 연동)
- `lib/core/navigation/app_router.dart` (GameScreen 진입 extra)
- `lib/main.dart`, `lib/app.dart`
- Android/iOS 실기기 입력 로그 (터치 샘플링) — **미확인**
- `flutter run -d chrome` 가능 여부 및 프레임 프로파일 — **미확인**

---

## C. pubspec.yaml 전체 내용

```yaml
name: blind_weekly_maze
description: Weekly Maze — 2D wall/corridor time-attack maze with weekly challenge & practice modes.
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ^3.12.2

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

  # Navigation (stack-safe routing)
  go_router: ^14.8.1

  # State management
  flutter_riverpod: ^2.6.1

  # Rewarded ads for hint recharge (7.x+ required for Gradle 9)
  google_mobile_ads: ^7.0.0

  # OS-level screenshot / screen-record / app-switcher protection
  # Use ≥1.5.1 (1.4.4–1.4.13 had crash reports on some devices)
  screen_protector: ^1.5.1

  # Local persistence (nickname, local leaderboard cache)
  shared_preferences: ^2.5.3

  # Timezone-aware weekly seed (KST Monday 00:00)
  timezone: ^0.10.0

  # Immutable models
  equatable: ^2.0.7

  # UUID for local player id
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true

```

### pubspec.lock에서 확인된 직접 의존 해석 버전
- go_router: 14.8.1
- flutter_riverpod: 2.6.1
- google_mobile_ads: 7.0.0
- screen_protector: 1.5.3
- shared_preferences: 2.5.6
- timezone: 0.10.1
- equatable: 2.1.0
- uuid: 4.6.0
- cupertino_icons: 1.0.9

---

## B. 관련 Dart 파일의 전체 코드

### `lib/features/maze/presentation/widgets/virtual_joystick.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 4-way digital stick: deadzone + angle snap → Up/Down/Left/Right only.
///
/// Writes only [Offset.zero] or unit cardinals into [vector].
/// Clears to [Offset.zero] immediately on pointer up / cancel.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.vector,
    this.size = 128,
    /// Fraction of max travel ignored near center (anti-jitter).
    this.deadZone = 0.28,
  });

  /// Output: `Offset.zero` or one of (0,-1)/(0,1)/(-1,0)/(1,0).
  final ValueNotifier<Offset> vector;
  final double size;
  final double deadZone;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  final ValueNotifier<Offset> _knob = ValueNotifier(Offset.zero);
  int? _pointer;
  Offset _lastCardinal = Offset.zero;

  double get _radius => widget.size / 2;
  double get _travel => _radius * 0.55;

  /// Map raw drag to a single cardinal unit vector, or zero inside deadzone.
  Offset _snapToCardinal(Offset local) {
    final center = Offset(_radius, _radius);
    final raw = local - center;
    final dist = raw.distance;
    if (dist <= 0) return Offset.zero;

    final norm = (dist / _travel).clamp(0.0, 1.0);
    if (norm < widget.deadZone) return Offset.zero;

    // Angle: 0 = right, π/2 = down (Flutter Y+).
    final angle = math.atan2(raw.dy, raw.dx);
    final deg = angle * 180 / math.pi;

    // Four 90° sectors centered on axes (±45°).
    if (deg >= -45 && deg < 45) {
      return const Offset(1, 0); // Right
    }
    if (deg >= 45 && deg < 135) {
      return const Offset(0, 1); // Down
    }
    if (deg >= -135 && deg < -45) {
      return const Offset(0, -1); // Up
    }
    return const Offset(-1, 0); // Left (includes ±180)
  }

  void _applyLocal(Offset local) {
    final cardinal = _snapToCardinal(local);

    // Visual knob: park on snapped axis (or center if dead).
    if (cardinal == Offset.zero) {
      _knob.value = Offset.zero;
    } else {
      _knob.value = Offset(cardinal.dx * _travel, cardinal.dy * _travel);
    }

    if (cardinal != _lastCardinal) {
      _lastCardinal = cardinal;
      if (cardinal != Offset.zero) {
        HapticFeedback.selectionClick();
      }
      // Only notify when direction actually changes (or clears).
      widget.vector.value = cardinal;
    }
  }

  void _clearInput() {
    _pointer = null;
    _lastCardinal = Offset.zero;
    _knob.value = Offset.zero;
    // Immediate stop — no residual inertia into the grid mover.
    widget.vector.value = Offset.zero;
  }

  @override
  void dispose() {
    _knob.dispose();
    // Safety: never leave a stuck direction after dispose.
    widget.vector.value = Offset.zero;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          _applyLocal(e.localPosition);
        },
        onPointerMove: (e) {
          if (e.pointer != _pointer) return;
          _applyLocal(e.localPosition);
        },
        onPointerUp: (e) {
          if (e.pointer != _pointer) return;
          _clearInput();
        },
        onPointerCancel: (e) {
          if (e.pointer != _pointer) return;
          _clearInput();
        },
        child: ValueListenableBuilder<Offset>(
          valueListenable: _knob,
          builder: (context, knob, _) {
            return CustomPaint(
              painter: _JoystickPainter(
                knob: knob,
                active: knob.distance > 0.5,
                accent: accent,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knob,
    required this.active,
    required this.accent,
  });

  final Offset knob;
  final bool active;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.width / 2;

    canvas.drawCircle(center, baseR, Paint()..color = const Color(0xFF1A1A1F));
    canvas.drawCircle(
      center,
      baseR,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Cardinal guides
    final guide = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx, center.dy - baseR * 0.7),
      Offset(center.dx, center.dy + baseR * 0.7),
      guide,
    );
    canvas.drawLine(
      Offset(center.dx - baseR * 0.7, center.dy),
      Offset(center.dx + baseR * 0.7, center.dy),
      guide,
    );

    final knobCenter = center + knob;
    final knobR = baseR * 0.32;
    canvas.drawCircle(
      knobCenter,
      knobR,
      Paint()..color = active ? accent : const Color(0xFFE8C547),
    );
    canvas.drawCircle(
      knobCenter,
      knobR,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter old) {
    return old.knob != knob || old.active != active || old.accent != accent;
  }
}
```

### `lib/features/maze/presentation/controllers/game_controller.dart`

```dart
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../data/dfs_maze_generator.dart';
import '../../domain/collision.dart';
import '../../domain/game_mode.dart';
import '../../domain/maze_cell.dart';
import '../../domain/maze_grid.dart';
import 'hint_controller.dart';
import 'timer_controller.dart';

enum GamePhase { ready, playing, cleared }

/// Snappy & smooth tile steps: target cell locks immediately, short lerp, hard snap.
final class GameController extends ChangeNotifier {
  GameController({
    required this.mode,
    bool Function()? isAdminMode,
    DfsMazeGenerator? generator,
  })  : _isAdminMode = isAdminMode ?? (() => false),
        _generator = generator ?? const DfsMazeGenerator() {
    timer = TimerController();
    hints = HintController(
      timer: timer,
      onAdPause: _pauseForAd,
      onAdResume: _resumeAfterAd,
      isAdminMode: _isAdminMode,
    );

    _maze = _generator.generate(size: mode.mazeSize, seed: _resolveSeed());
    _tile = _maze.start;
    playerPos = ValueNotifier(MazeCollision.cellCenter(_tile));
    stick = ValueNotifier(Offset.zero);
    revealListenable = ValueNotifier(false);

    hints.addListener(_onHintsChanged);
  }

  final GameMode mode;
  final DfsMazeGenerator _generator;
  final bool Function() _isAdminMode;

  late final TimerController timer;
  late final HintController hints;
  late final ValueNotifier<Offset> playerPos;
  late final ValueNotifier<Offset> stick;
  late final ValueNotifier<bool> revealListenable;
  late MazeGrid _maze;
  late GridPos _tile;

  GamePhase _phase = GamePhase.ready;
  bool _userPaused = false;
  bool _adPaused = false;
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  bool _tickerAttached = false;

  /// In-flight step lerp 0→1.
  double _moveT = 0;
  bool _moving = false;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  /// Buffered cardinal intent (row, col deltas of -1/0/1).
  GridPos? _queuedDir;

  /// One tile transition duration — snappy but readable (~9 tiles/sec).
  static const double stepSeconds = 0.11;

  /// Accept stick if already a unit cardinal (joystick) or past threshold (keys).
  static const double stickThreshold = 0.25;

  MazeGrid get maze => _maze;
  GridPos get playerCell => _tile;
  GamePhase get phase => _phase;
  bool get isUserPaused => _userPaused;
  bool get canTogglePause => _phase == GamePhase.playing;
  bool get isAdminMode => _isAdminMode();
  bool get isFullReveal => hints.isRevealing || isAdminMode;
  int get visionRadius => 1;
  bool get isMoving => _moving;

  int _resolveSeed() {
    return switch (mode) {
      PracticeMode(:final seed) => seed,
      WeeklyChallengeMode(:final seed) => seed,
    };
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

  void _onTick(Duration elapsed) {
    if (_phase != GamePhase.playing || _userPaused || timer.isPaused) {
      _lastTick = elapsed;
      return;
    }

    final dtMs = _lastTick == Duration.zero
        ? 16.0
        : (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    final dt = (dtMs / 1000.0).clamp(0.0, 0.05);

    // Buffer cardinal intent while held; clear on release (finish current tile).
    final intent = _cardinalFromStick(stick.value);
    _queuedDir = intent;

    if (_moving) {
      _moveT += dt / stepSeconds;
      if (_moveT >= 1) {
        _finishStep();
      } else {
        // Snappy ease-out: fast start, soft land on tile center.
        final t = Curves.easeOutCubic.transform(_moveT.clamp(0.0, 1.0));
        playerPos.value = Offset(
          lerpDouble(_from.dx, _to.dx, t)!,
          lerpDouble(_from.dy, _to.dy, t)!,
        );
      }
    } else {
      _tryConsumeQueue();
    }
  }

  void _finishStep() {
    playerPos.value = _to; // exact center snap — no drift
    _moving = false;
    _moveT = 0;
    _checkClear();
    if (_phase == GamePhase.cleared) return;

    // Chain next tile immediately while stick held (no dead frame hitch).
    _tryConsumeQueue();
  }

  void _tryConsumeQueue() {
    final dir = _queuedDir;
    if (dir == null) return;
    // Wall ahead: stay snapped, no bounce — keep holding to retry next frame.
    _tryBeginStep(dir);
  }

  bool _tryBeginStep(GridPos dir) {
    final next = GridPos(_tile.row + dir.row, _tile.col + dir.col);
    if (!MazeCollision.canStep(_maze, _tile, next)) {
      return false;
    }

    _from = MazeCollision.cellCenter(_tile);
    _to = MazeCollision.cellCenter(next);
    _tile = next;
    _moveT = 0;
    _moving = true;
    playerPos.value = _from;
    return true;
  }

  /// Map stick (already 4-way from joystick, or analog from keys) → grid delta.
  GridPos? _cardinalFromStick(Offset v) {
    if (v.distance < stickThreshold) return null;
    // Prefer axis with larger component (stable for keyboard diagonals too).
    if (v.dx.abs() > v.dy.abs()) {
      return GridPos(0, v.dx > 0 ? 1 : -1);
    }
    if (v.dy.abs() > v.dx.abs()) {
      return GridPos(v.dy > 0 ? 1 : -1, 0);
    }
    // Exact diagonal rarity: prefer horizontal.
    return GridPos(0, v.dx >= 0 ? 1 : -1);
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
    _queuedDir = null;
    timer.pause();
    notifyListeners();
  }

  void resume() {
    if (!canTogglePause || !_userPaused) return;
    _userPaused = false;
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
    _queuedDir = null;
    timer.pause();
    notifyListeners();
  }

  void _resumeAfterAd() {
    _adPaused = false;
    if (!_userPaused) timer.resume();
    notifyListeners();
  }

  /// Discrete pad / test helpers — queue one cardinal step.
  void queueDir(GridPos dir) {
    if (_phase != GamePhase.playing || _userPaused || timer.isPaused) return;
    _queuedDir = dir;
    if (!_moving) _tryConsumeQueue();
  }

  void moveUp() => queueDir(const GridPos(-1, 0));
  void moveDown() => queueDir(const GridPos(1, 0));
  void moveLeft() => queueDir(const GridPos(0, -1));
  void moveRight() => queueDir(const GridPos(0, 1));

  void _onClear() {
    if (_phase == GamePhase.cleared) return;
    timer.stop();
    stick.value = Offset.zero;
    _queuedDir = null;
    _moving = false;
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
```

### `lib/features/maze/presentation/screens/game_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/admin_mode.dart';
import '../../../../core/debug/admin_mode_badge.dart';
import '../../../../core/navigation/navigation_manager.dart';
import '../../../security/screen_protect_service.dart';
import '../../domain/game_mode.dart';
import '../controllers/game_controller.dart';
import '../widgets/game_hud.dart';
import '../widgets/maze_board.dart';
import '../widgets/virtual_joystick.dart';
import 'result_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late final GameController _controller;
  bool _navigatedToResult = false;
  final Set<LogicalKeyboardKey> _held = {};

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      mode: widget.mode,
      isAdminMode: () {
        if (!AdminModeController.isAvailable) return false;
        return ref.read(adminModeProvider).isAdminMode;
      },
    );
    _controller.attachTicker(this);
    _controller.addListener(_onChromeChanged);
    ScreenProtectService.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.start();
      ref.read(adminModeProvider).addListener(_onAdminChanged);
    });
  }

  void _onAdminChanged() {
    if (!mounted) return;
    _controller.refreshAdminState();
  }

  void _onChromeChanged() {
    if (!mounted) return;
    if (_controller.phase == GamePhase.cleared && !_navigatedToResult) {
      _navigatedToResult = true;
      NavigationManager.toResult(
        context,
        extra: ResultArgs(
          mode: widget.mode,
          elapsedSeconds: _controller.timer.elapsedSeconds,
          hintCount: _controller.hints.usedTotal,
        ),
      );
      return;
    }
    setState(() {});
  }

  void _syncKeyboardStick() {
    var x = 0.0;
    var y = 0.0;
    if (_held.contains(LogicalKeyboardKey.arrowLeft) ||
        _held.contains(LogicalKeyboardKey.keyA)) {
      x -= 1;
    }
    if (_held.contains(LogicalKeyboardKey.arrowRight) ||
        _held.contains(LogicalKeyboardKey.keyD)) {
      x += 1;
    }
    if (_held.contains(LogicalKeyboardKey.arrowUp) ||
        _held.contains(LogicalKeyboardKey.keyW)) {
      y -= 1;
    }
    if (_held.contains(LogicalKeyboardKey.arrowDown) ||
        _held.contains(LogicalKeyboardKey.keyS)) {
      y += 1;
    }
    final v = Offset(x, y);
    _controller.stick.value =
        v.distance == 0 ? Offset.zero : Offset(v.dx / v.distance, v.dy / v.distance);
  }

  Future<void> _onHint() async {
    if (_controller.isUserPaused) return;
    await _controller.hints.useHint();
  }

  Future<void> _onWatchAd() async {
    if (_controller.isUserPaused) return;
    final ok = await _controller.hints.watchAdForHint();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오지 못했거나 보상을 받지 못했습니다.')),
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
        if (_controller.canTogglePause) {
          _controller.togglePause();
          return KeyEventResult.handled;
        }
      }
      if (_controller.isUserPaused) return KeyEventResult.handled;

      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        _held.add(key);
        _syncKeyboardStick();
        return KeyEventResult.handled;
      }
    }

    if (event is KeyUpEvent) {
      if (_held.remove(key)) {
        _syncKeyboardStick();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    try {
      ref.read(adminModeProvider).removeListener(_onAdminChanged);
    } catch (_) {}
    _controller.removeListener(_onChromeChanged);
    _controller.dispose();
    ScreenProtectService.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paused = _controller.isUserPaused;
    final adminOn = AdminModeController.isAvailable &&
        ref.watch(adminModeProvider).isAdminMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_controller.phase == GamePhase.playing && !paused) {
          _controller.pause();
          return;
        }
        if (paused) {
          _controller.resume();
          return;
        }
        NavigationManager.toHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(paused ? '일시정지' : '미로 탈출'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => NavigationManager.toHome(context),
          ),
          actions: [
            if (adminOn)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(child: AdminModeBadge()),
              ),
            if (_controller.canTogglePause)
              IconButton(
                tooltip: paused ? '계속하기' : '일시정지',
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                onPressed: _controller.togglePause,
              ),
          ],
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                children: [
                  GameHud(
                    controller: _controller,
                    onHint: _onHint,
                    onWatchAd: _onWatchAd,
                    onPause: _controller.togglePause,
                    isPaused: paused,
                    isAdminMode: adminOn,
                    onToggleAdmin: AdminModeController.isAvailable
                        ? () => ref.read(adminModeProvider).toggle()
                        : null,
                  ),
                  if (paused)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '일시정지 · ▶ 또는 일시정지 버튼으로 계속',
                        style: TextStyle(
                          color: Color(0xFFE8C547),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side =
                            constraints.maxWidth < constraints.maxHeight
                                ? constraints.maxWidth
                                : constraints.maxHeight;
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            // Static walls never depend on player; only reveal
                            // swaps fog via ValueListenable inside MazeBoard.
                            child: MazeBoard(
                              maze: _controller.maze,
                              playerPos: _controller.playerPos,
                              revealListenable: _controller.revealListenable,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  IgnorePointer(
                    ignoring: paused,
                    child: Opacity(
                      opacity: paused ? 0.4 : 1,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: VirtualJoystick(
                          size: 128,
                          vector: _controller.stick,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### `lib/features/maze/domain/collision.dart`

```dart
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'maze_cell.dart';
import 'maze_grid.dart';

/// Grid step checks + continuous circle / wall-segment sliding.
abstract final class MazeCollision {
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
    final abx = bx - ax;
    final aby = by - ay;
    final apx = p.dx - ax;
    final apy = p.dy - ay;
    final abLen2 = abx * abx + aby * aby;
    final t = abLen2 == 0
        ? 0.0
        : (apx * abx + apy * aby) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final cx = ax + abx * clamped;
    final cy = ay + aby * clamped;
    final dx = p.dx - cx;
    final dy = p.dy - cy;
    return dx * dx + dy * dy < radius * radius;
  }

  /// Axis-separated sliding: try full → X-only → Y-only.
  static Offset slideMove(
    MazeGrid maze,
    Offset from,
    Offset delta,
    double radius,
  ) {
    if (delta.dx == 0 && delta.dy == 0) return from;

    final full = Offset(from.dx + delta.dx, from.dy + delta.dy);
    if (!circleHitsWall(maze, full, radius)) return full;

    final onlyX = Offset(from.dx + delta.dx, from.dy);
    final xOk = !circleHitsWall(maze, onlyX, radius);
    final onlyY = Offset(from.dx, from.dy + delta.dy);
    final yOk = !circleHitsWall(maze, onlyY, radius);

    if (xOk && yOk) {
      // Prefer the larger intended axis so corner grazes feel natural.
      return delta.dx.abs() >= delta.dy.abs() ? onlyX : onlyY;
    }
    if (xOk) return onlyX;
    if (yOk) return onlyY;
    return from;
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
```

### `lib/features/maze/presentation/widgets/maze_board.dart`

```dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
class DynamicPlayerFogLayer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: playerPos,
      builder: (context, cellPos, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: revealListenable,
          builder: (context, reveal, _) {
            return CustomPaint(
              size: boardSize,
              painter: _FogPlayerPainter(
                maze: maze,
                boardSize: boardSize,
                cellPos: cellPos,
                reveal: reveal,
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
  });

  final MazeGrid maze;
  final Size boardSize;
  final Offset cellPos;
  final bool reveal;

  static const _fog = Color(0xFF000000);
  static const _exit = Color(0xFF00E676);
  static const _player = Color(0xFFFFB300);
  static const _ring = Color(0xFFFF6D00);
  static const _visionToPlayer = 2.35;

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
    final pixel = Offset(cellPos.dx * cell, cellPos.dy * cell);

    // Approximate wall thickness fraction used by cache (0.28).
    final wallT = (cell * 0.28).clamp(3.0, 16.0);
    final corridor = math.max(4.0, cell - wallT);
    final playerRadiusPx = (corridor * 0.34).clamp(3.5, cell * 0.36);
    final visionPx = playerRadiusPx * _visionToPlayer;

    final exit = maze.exit;
    final exitPixel = Offset(
      (exit.col + 0.5) * cell,
      (exit.row + 0.5) * cell,
    );
    final exitLit =
        reveal || (exitPixel - pixel).distance <= visionPx;

    if (exitLit) {
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
      final fog = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addOval(Rect.fromCircle(center: pixel, radius: visionPx));
      canvas.drawPath(fog, _fogPaint);
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
```

### `lib/features/maze/presentation/widgets/maze_wall_cache.dart`

```dart
import 'package:flutter/material.dart';

import '../../domain/maze_grid.dart';

/// Thick filled wall geometry — rebuilt only when maze or board size changes.
final class MazeWallCache {
  MazeWallCache._({
    required this.seed,
    required this.mazeSize,
    required this.boardSize,
    required this.walls,
    required this.wallWidth,
    required this.cellSize,
  });

  final int seed;
  final int mazeSize;
  final Size boardSize;

  /// Filled wall bars (not hairline strokes).
  final Path walls;
  final double wallWidth;
  final double cellSize;

  static MazeWallCache build({
    required MazeGrid maze,
    required Size boardSize,
  }) {
    final n = maze.size;
    final cellW = boardSize.width / n;
    final cellH = boardSize.height / n;
    final minCell = cellW < cellH ? cellW : cellH;
    // Dense partitions for large grids; corridors stay readable in tight vision.
    final t = (minCell * 0.28).clamp(3.0, 16.0);

    final walls = Path();

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final cell = maze.cells[r][c];
        final left = c * cellW;
        final top = r * cellH;
        final right = left + cellW;
        final bottom = top + cellH;

        // Thick bars centered on cell edges.
        if (cell.north) {
          walls.addRect(Rect.fromLTRB(left, top, right, top + t));
        }
        if (cell.south) {
          walls.addRect(Rect.fromLTRB(left, bottom - t, right, bottom));
        }
        if (cell.west) {
          walls.addRect(Rect.fromLTRB(left, top, left + t, bottom));
        }
        if (cell.east) {
          walls.addRect(Rect.fromLTRB(right - t, top, right, bottom));
        }
      }
    }

    // Outer frame (full border thickness).
    walls
      ..addRect(Rect.fromLTWH(0, 0, boardSize.width, t))
      ..addRect(Rect.fromLTWH(0, boardSize.height - t, boardSize.width, t))
      ..addRect(Rect.fromLTWH(0, 0, t, boardSize.height))
      ..addRect(Rect.fromLTWH(boardSize.width - t, 0, t, boardSize.height));

    return MazeWallCache._(
      seed: maze.seed,
      mazeSize: n,
      boardSize: boardSize,
      walls: walls,
      wallWidth: t,
      cellSize: minCell,
    );
  }

  bool matches(MazeGrid maze, Size size) =>
      seed == maze.seed && mazeSize == maze.size && boardSize == size;
}
```

### `lib/features/maze/presentation/controllers/timer_controller.dart`

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centisecond-precision stopwatch that supports ad-driven pause/resume.
final class TimerController extends ChangeNotifier {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _segmentStartedAt;
  bool _running = false;
  bool _paused = false;

  Duration get elapsed => _elapsed;
  bool get isRunning => _running && !_paused;
  bool get isPaused => _paused;

  /// Formatted as `12.45` (seconds with 2 decimal places).
  String get formatted {
    final totalCs = _elapsed.inMilliseconds ~/ 10;
    final whole = totalCs ~/ 100;
    final frac = (totalCs % 100).toString().padLeft(2, '0');
    return '$whole.$frac';
  }

  double get elapsedSeconds {
    final totalCs = _elapsed.inMilliseconds ~/ 10;
    return totalCs / 100.0;
  }

  void start() {
    if (_running) return;
    _running = true;
    _paused = false;
    _segmentStartedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (_paused || _segmentStartedAt == null) return;
      final delta = DateTime.now().difference(_segmentStartedAt!);
      _elapsed = _frozenElapsed + delta;
      notifyListeners();
    });
    notifyListeners();
  }

  Duration _frozenElapsed = Duration.zero;

  void pause() {
    if (!_running || _paused) return;
    if (_segmentStartedAt != null) {
      _frozenElapsed += DateTime.now().difference(_segmentStartedAt!);
      _elapsed = _frozenElapsed;
    }
    _paused = true;
    _segmentStartedAt = null;
    notifyListeners();
  }

  void resume() {
    if (!_running || !_paused) return;
    _paused = false;
    _segmentStartedAt = DateTime.now();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    if (_running && !_paused && _segmentStartedAt != null) {
      _frozenElapsed += DateTime.now().difference(_segmentStartedAt!);
      _elapsed = _frozenElapsed;
    }
    _running = false;
    _paused = false;
    _segmentStartedAt = null;
    notifyListeners();
  }

  void reset() {
    stop();
    _elapsed = Duration.zero;
    _frozenElapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
```

### `lib/features/maze/presentation/widgets/game_hud.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../core/debug/admin_mode_badge.dart';
import '../controllers/game_controller.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.controller,
    required this.onHint,
    required this.onWatchAd,
    required this.onPause,
    required this.isPaused,
    this.isAdminMode = false,
    this.onToggleAdmin,
  });

  final GameController controller;
  final VoidCallback onHint;
  final VoidCallback onWatchAd;
  final VoidCallback onPause;
  final bool isPaused;
  final bool isAdminMode;
  final VoidCallback? onToggleAdmin;

  @override
  Widget build(BuildContext context) {
    final hints = controller.hints;
    final timer = controller.timer;

    return ListenableBuilder(
      listenable: Listenable.merge([hints, timer]),
      builder: (context, _) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.mode.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAdminMode) ...[
                  const AdminModeBadge(),
                  const SizedBox(width: 6),
                ],
                IconButton.filledTonal(
                  tooltip: isPaused ? '계속하기' : '일시정지',
                  onPressed: controller.canTogglePause ? onPause : null,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                ),
                const SizedBox(width: 4),
                Text(
                  '${timer.formatted}초',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isPaused ? const Color(0xFFE8C547) : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: !isPaused && hints.canUseHint ? onHint : null,
                    child: Text(
                      isAdminMode
                          ? '힌트 (무제한)'
                          : '힌트 (${hints.remaining})',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: !isPaused &&
                            (isAdminMode || hints.canWatchAdForHint)
                        ? onWatchAd
                        : null,
                    child: Text(
                      isAdminMode
                          ? '광고 스킵 (관리자)'
                          : hints.canWatchAdForHint
                              ? '광고로 힌트 (+${hints.adsRemaining})'
                              : '광고 한도 소진',
                    ),
                  ),
                ),
              ],
            ),
            if (onToggleAdmin != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onToggleAdmin,
                  child: Text(
                    isAdminMode ? '관리자 모드 끄기' : '관리자 모드',
                    style: TextStyle(
                      color: isAdminMode
                          ? const Color(0xFFFF1744)
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (hints.isRevealing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '전체 미로 공개 중 (3초)…',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              )
            else if (isAdminMode)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '관리자: 전체 미로 상시 표시',
                  style: TextStyle(color: Color(0xFFFF1744), fontSize: 12),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '초밀착 시야 · 힌트/관리자만 전체 공개',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

### `lib/features/maze/presentation/widgets/dpad_controls.dart`

```dart
import 'package:flutter/material.dart';

class DpadControls extends StatelessWidget {
  const DpadControls({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback onTap) {
      return IconButton.filledTonal(
        onPressed: onTap,
        iconSize: 32,
        style: IconButton.styleFrom(
          minimumSize: const Size(64, 64),
        ),
        icon: Icon(icon),
      );
    }

    return Column(
      children: [
        btn(Icons.keyboard_arrow_up, onUp),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            btn(Icons.keyboard_arrow_left, onLeft),
            const SizedBox(width: 64),
            btn(Icons.keyboard_arrow_right, onRight),
          ],
        ),
        btn(Icons.keyboard_arrow_down, onDown),
      ],
    );
  }
}
```

### `lib/features/maze/domain/maze_cell.dart`

```dart
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
```

### `lib/features/maze/domain/maze_grid.dart`

```dart
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
```

### `lib/features/maze/domain/difficulty.dart`

```dart
enum Difficulty {
  /// Dense 15×15 — never a trivial corridor.
  easy(label: '하', size: 15),
  normal(label: '중', size: 21),
  hard(label: '상', size: 27);

  const Difficulty({required this.label, required this.size});

  final String label;
  final int size;
}
```

### `lib/features/maze/domain/game_mode.dart`

```dart
import 'difficulty.dart';

sealed class GameMode {
  const GameMode();

  String get displayName;
  int get mazeSize;
  String get seedKey;
}

/// Practice: random seed every round, selectable difficulty.
final class PracticeMode extends GameMode {
  const PracticeMode({
    required this.difficulty,
    required this.seed,
  });

  final Difficulty difficulty;
  final int seed;

  @override
  String get displayName => '연습 · ${difficulty.label}';

  @override
  int get mazeSize => difficulty.size;

  @override
  String get seedKey => 'practice_${difficulty.name}_$seed';
}

/// Weekly challenge: one shared maze for all players that week (KST).
final class WeeklyChallengeMode extends GameMode {
  const WeeklyChallengeMode({
    required this.weekId,
    required this.seed,
    this.mazeSizeOverride = 21,
  });

  /// e.g. "2026-W46"
  final String weekId;
  final int seed;

  /// Fixed weekly size (중-tier density by default).
  final int mazeSizeOverride;

  @override
  String get displayName => '주간 챌린지 · $weekId';

  @override
  int get mazeSize => mazeSizeOverride;

  @override
  String get seedKey => 'weekly_$weekId';
}
```

### `lib/features/maze/data/dfs_maze_generator.dart`

```dart
import 'dart:collection';
import 'dart:math';

import '../domain/maze_cell.dart';
import '../domain/maze_grid.dart';

/// Complex perfect-maze generator (Growing Tree / Prim-biased).
///
/// Unlike classic recursive DFS (long corridors), this prefers picking a
/// **random** frontier cell so the maze grows bushy branches and dense
/// dead ends ("fake paths"). Exit is placed at the BFS-farthest cell
/// from start for a long unique solution path.
///
/// Same [seed] + [size] ⇒ identical maze on every client.
final class DfsMazeGenerator {
  const DfsMazeGenerator();

  /// Probability of picking a random frontier cell (Prim-like).
  /// Remaining chance picks the newest cell (DFS-like tendril).
  static const double _randomFrontierBias = 0.88;

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
```

