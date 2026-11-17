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
            // Timer text only — avoids rebuilding hint buttons every tick.
            ListenableBuilder(
              listenable: timer,
              builder: (context, _) {
                return Text(
                  '${timer.formatted}초',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isPaused ? const Color(0xFFE8C547) : null,
                      ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: hints,
          builder: (context, _) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed:
                            !isPaused && hints.canUseHint ? onHint : null,
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
        ),
        if (onToggleAdmin != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggleAdmin,
              child: Text(
                isAdminMode ? '관리자 모드 끄기' : '관리자 모드',
                style: TextStyle(
                  color:
                      isAdminMode ? const Color(0xFFFF1744) : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
