import 'package:blind_weekly_maze/app.dart';
import 'package:blind_weekly_maze/core/constants/app_info.dart';
import 'package:blind_weekly_maze/core/constants/route_paths.dart';
import 'package:blind_weekly_maze/features/admin/presentation/screens/admin_maze_preview_screen.dart';
import 'package:blind_weekly_maze/features/admin/presentation/widgets/admin_maze_preview_board.dart';
import 'package:blind_weekly_maze/features/leaderboard/domain/fixed_board_keys.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_catalog.dart';
import 'package:blind_weekly_maze/features/maze/data/fixed_maze_path.dart';
import 'package:blind_weekly_maze/features/maze/domain/fixed_maze_definition.dart';
import 'package:blind_weekly_maze/features/maze/domain/maze_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expected = <String, ({
    String boardKey,
    int size,
    GridPos start,
    GridPos exit,
    int shortest,
    String checksum,
  })>{
    'VERY_EASY-001': (
      boardKey: FixedBoardKeys.veryEasy,
      size: 11,
      start: GridPos(0, 0),
      exit: GridPos(10, 10),
      shortest: 22,
      checksum: '9b9728a3',
    ),
    'EASY-001': (
      boardKey: FixedBoardKeys.easy,
      size: 15,
      start: GridPos(0, 0),
      exit: GridPos(14, 14),
      shortest: 30,
      checksum: 'e28f730b',
    ),
    'NORMAL-001': (
      boardKey: FixedBoardKeys.normal,
      size: 21,
      start: GridPos(0, 0),
      exit: GridPos(20, 20),
      shortest: 44,
      checksum: 'b3096800',
    ),
    'HARD-001': (
      boardKey: FixedBoardKeys.hard,
      size: 27,
      start: GridPos(0, 0),
      exit: GridPos(26, 19),
      shortest: 59,
      checksum: '8fc021cc',
    ),
    'VERY_HARD-001': (
      boardKey: FixedBoardKeys.veryHard,
      size: 33,
      start: GridPos(0, 0),
      exit: GridPos(32, 32),
      shortest: 80,
      checksum: '172e0733',
    ),
  };

  group('admin preview data from FixedMazeCatalog', () {
    test('each difficulty matches frozen snapshot metadata', () {
      for (final id in FixedMazeCatalog.allIds) {
        final exp = expected[id]!;
        final def = FixedMazeCatalog.definition(id);
        final grid = def.toMazeGrid();
        final path = FixedMazePath.shortestPath(grid)!;

        expect(def.mazeId, id);
        expect(def.size, exp.size);
        expect(def.start, exp.start);
        expect(def.exit, exp.exit);
        expect(def.checksum, exp.checksum);
        expect(def.checksumValid, isTrue);
        expect(def.rulesVersion, FixedMazeDefinition.rulesVersionV1);
        expect(FixedBoardKeys.mazeIdFor(exp.boardKey), id);

        expect(grid.start, exp.start);
        expect(grid.exit, exp.exit);
        expect(grid.size, exp.size);

        expect(FixedMazePath.shortestLength(grid), exp.shortest);
        expect(path.length - 1, exp.shortest);
        expect(path.first, exp.start);
        expect(path.last, exp.exit);
      }
    });

    test('shortestPath length equals shortestLength helper', () {
      for (final id in FixedMazeCatalog.allIds) {
        final grid = FixedMazeCatalog.grid(id);
        final path = FixedMazePath.shortestPath(grid)!;
        expect(path.length - 1, FixedMazePath.shortestLength(grid));
      }
    });
  });

  group('admin preview UI', () {
    testWidgets('screen shows tabs and catalog fields for easy', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminMazePreviewScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('매우 쉬움'), findsOneWidget);
      expect(find.text('쉬움'), findsOneWidget);
      expect(find.text('중간'), findsOneWidget);
      expect(find.text('어려움'), findsOneWidget);
      expect(find.text('매우 어려움'), findsOneWidget);
      expect(find.byType(AdminMazePreviewBoard), findsOneWidget);
      expect(find.text('VERY_EASY-001'), findsOneWidget);
      expect(find.text('fixed_very_easy'), findsOneWidget);
      expect(find.text('9b9728a3'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('rules_v1'), findsOneWidget);

      await tester.tap(find.text('최단 경로 표시'));
      await tester.pump();
      expect(find.text('최단 경로 숨기기'), findsOneWidget);
    });

    testWidgets('hard tab shows HARD-001 checksum and path length',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdminMazePreviewScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('어려움'));
      await tester.pumpAndSettle();

      expect(find.text('HARD-001'), findsOneWidget);
      expect(find.text('fixed_hard'), findsOneWidget);
      expect(find.text('8fc021cc'), findsOneWidget);
      expect(find.text('59'), findsOneWidget);
      expect(find.text('(26, 19)'), findsOneWidget);
    });

    testWidgets('home version 7-tap opens admin preview', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: BlindWeeklyMazeApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppInfo.versionLabel), findsOneWidget);
      expect(find.byType(AdminMazePreviewScreen), findsNothing);

      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text(AppInfo.versionLabel));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.byType(AdminMazePreviewScreen), findsOneWidget);
      expect(find.text('관리자 · 미로 미리보기'), findsOneWidget);
    });
  });

  test('admin preview route path is stable', () {
    expect(RoutePaths.adminMazePreview, '/admin/maze-preview');
  });
}
