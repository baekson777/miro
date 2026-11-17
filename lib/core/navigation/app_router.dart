import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_maze_preview_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/home/presentation/screens/mode_select_screen.dart';
import '../../features/home/presentation/screens/my_info_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/legal/domain/legal_document.dart';
import '../../features/legal/presentation/screens/legal_document_screen.dart';
import '../../features/maze/domain/game_mode.dart';
import '../../features/maze/presentation/screens/game_screen.dart';
import '../../features/maze/presentation/screens/result_screen.dart';
import '../constants/route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myInfo,
                name: 'myInfo',
                builder: (context, state) => const MyInfoScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: 'privacyPolicy',
        builder: (context, state) => const LegalDocumentScreen(
          type: LegalDocumentType.privacyPolicy,
        ),
      ),
      GoRoute(
        path: RoutePaths.terms,
        name: 'terms',
        builder: (context, state) => const LegalDocumentScreen(
          type: LegalDocumentType.terms,
        ),
      ),
      GoRoute(
        path: RoutePaths.accountDeletion,
        name: 'accountDeletion',
        builder: (context, state) => const LegalDocumentScreen(
          type: LegalDocumentType.accountDeletion,
        ),
      ),
      GoRoute(
        path: RoutePaths.modeSelect,
        name: 'modeSelect',
        builder: (context, state) => const ModeSelectScreen(),
      ),
      GoRoute(
        path: RoutePaths.game,
        name: 'game',
        builder: (context, state) {
          final mode = state.extra;
          if (mode is! GameMode) {
            return const Scaffold(
              body: Center(child: Text('Invalid game mode')),
            );
          }
          // routeInstanceKey remounts FixedChallenge retries (session suffix)
          // while seedKey stays stable for rankings.
          return GameScreen(
            key: ValueKey(mode.routeInstanceKey),
            mode: mode,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.result,
        name: 'result',
        builder: (context, state) {
          final args = state.extra;
          if (args is! ResultArgs) {
            return const Scaffold(
              body: Center(child: Text('Invalid result')),
            );
          }
          return ResultScreen(args: args);
        },
      ),
      GoRoute(
        path: RoutePaths.leaderboard,
        name: 'leaderboard',
        builder: (context, state) {
          final weekId = state.uri.queryParameters['week'];
          final board = state.uri.queryParameters['board'];
          final admin = state.uri.queryParameters['admin'] == '1';
          return LeaderboardScreen(
            weekId: weekId,
            initialBoardKey: board,
            adminTestsOnly: admin,
          );
        },
      ),
      GoRoute(
        path: RoutePaths.adminMazePreview,
        name: 'adminMazePreview',
        builder: (context, state) => const AdminMazePreviewScreen(),
      ),
    ],
  );
});
