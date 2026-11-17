import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_info.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/debug/admin_mode.dart';
import '../../../../core/debug/admin_mode_badge.dart';
import '../../../../core/debug/admin_mode_gesture.dart';
import '../../../../core/navigation/navigation_manager.dart';
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _adminPreviewTapsRequired = 7;
  static const _tapWindow = Duration(seconds: 3);

  int _versionTapCount = 0;
  DateTime? _firstVersionTapAt;

  void _onVersionTap() {
    final now = DateTime.now();
    if (_firstVersionTapAt == null ||
        now.difference(_firstVersionTapAt!) > _tapWindow) {
      _firstVersionTapAt = now;
      _versionTapCount = 1;
      return;
    }
    _versionTapCount += 1;
    if (_versionTapCount < _adminPreviewTapsRequired) return;

    _versionTapCount = 0;
    _firstVersionTapAt = null;
    NavigationManager.goAndClear(context, RoutePaths.adminMazePreview);
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminModeProvider);
    final showAdmin = AdminModeController.isAvailable && admin.isAdminMode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAdmin)
                const Align(
                  alignment: Alignment.centerRight,
                  child: AdminModeBadge(),
                ),
              const SizedBox(height: 28),
              AdminModeLongPress(
                child: Text(
                  '미로미로해',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 44,
                        height: 1.05,
                        letterSpacing: 1.0,
                      ),
                ),
              ),
              if (AdminModeController.isAvailable) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '관리자 모드',
                    style: TextStyle(color: Color(0xFFFF1744)),
                  ),
                  subtitle: const Text(
                    '디버그 전용 · 전체 미로 / 힌트 무제한',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  value: admin.isAdminMode,
                  activeThumbColor: const Color(0xFFFF1744),
                  onChanged: (v) => admin.setEnabled(v),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    NavigationManager.goAndClear(context, '/mode-select'),
                child: const Text('게임 시작'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    NavigationManager.goAndClear(context, '/leaderboard'),
                child: const Text('순위표'),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _onVersionTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    AppInfo.versionLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
