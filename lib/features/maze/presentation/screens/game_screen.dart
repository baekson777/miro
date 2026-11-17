import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/debug/admin_mode.dart';
import '../../../../core/debug/admin_mode_badge.dart';
import '../../../../core/navigation/navigation_manager.dart';
import '../../../../core/ui/top_toast.dart';
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

  bool get _isAdminPlaytest => switch (widget.mode) {
        FixedChallengeMode(:final isAdminTest) => isAdminTest,
        _ => false,
      };

  void _returnToAdminPreview() {
    // Abort in-progress admin test — no result / ranking submit.
    NavigationManager.goAndClear(context, RoutePaths.adminMazePreview);
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
      TopToast.show(context, '광고를 불러오지 못했거나 보상을 받지 못했습니다.');
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
    final adminPlaytest = _isAdminPlaytest;

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
        if (adminPlaytest) {
          _returnToAdminPreview();
        } else {
          NavigationManager.toHome(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            paused
                ? '일시정지'
                : adminPlaytest
                    ? '관리자 테스트'
                    : '미로 탈출',
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: adminPlaytest
                ? _returnToAdminPreview
                : () => NavigationManager.toHome(context),
          ),
          actions: [
            if (adminPlaytest)
              TextButton(
                onPressed: _returnToAdminPreview,
                child: const Text('관리자 모드로 돌아가기'),
              ),
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
