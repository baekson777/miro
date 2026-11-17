import 'package:flutter/material.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/navigation/navigation_manager.dart';
import '../../../leaderboard/domain/fixed_board_keys.dart';
import '../../../maze/data/fixed_maze_catalog.dart';
import '../../../maze/data/fixed_maze_path.dart';
import '../../../maze/domain/fixed_maze_definition.dart';
import '../../../maze/domain/game_mode.dart';
import '../../../maze/domain/maze_cell.dart';
import '../../../maze/domain/maze_grid.dart';
import '../widgets/admin_maze_preview_board.dart';

/// Hidden admin surface: inspect frozen ranked mazes and run playtests.
class AdminMazePreviewScreen extends StatefulWidget {
  const AdminMazePreviewScreen({super.key});

  @override
  State<AdminMazePreviewScreen> createState() => _AdminMazePreviewScreenState();
}

class _AdminMazePreviewScreenState extends State<AdminMazePreviewScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <({String label, String mazeId, String boardKey})>[
    (
      label: '매우 쉬움',
      mazeId: FixedMazeCatalog.veryEasy001,
      boardKey: FixedBoardKeys.veryEasy,
    ),
    (
      label: '쉬움',
      mazeId: FixedMazeCatalog.easy001,
      boardKey: FixedBoardKeys.easy,
    ),
    (
      label: '중간',
      mazeId: FixedMazeCatalog.normal001,
      boardKey: FixedBoardKeys.normal,
    ),
    (
      label: '어려움',
      mazeId: FixedMazeCatalog.hard001,
      boardKey: FixedBoardKeys.hard,
    ),
    (
      label: '매우 어려움',
      mazeId: FixedMazeCatalog.veryHard001,
      boardKey: FixedBoardKeys.veryHard,
    ),
  ];

  late final TabController _tabController;
  late final List<_PreviewModel> _models;
  bool _showPath = false;
  final _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _models = [
      for (final t in _tabs) _PreviewModel.load(t.mazeId, t.boardKey),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _showPath = false;
        _transform.value = Matrix4.identity();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _exitAdminMode() {
    NavigationManager.toHome(context);
  }

  void _playCurrent(FixedChallengeMode mode) {
    NavigationManager.replace(context, RoutePaths.game, extra: mode);
  }

  void _openAdminRanking(String boardKey) {
    NavigationManager.goAndClear(
      context,
      '${RoutePaths.leaderboard}?board=$boardKey&admin=1',
    );
  }

  FixedChallengeMode _modeFor(String mazeId) {
    return switch (mazeId) {
      FixedMazeCatalog.veryEasy001 =>
        FixedChallengeMode.veryEasy(isAdminTest: true),
      FixedMazeCatalog.easy001 =>
        FixedChallengeMode.easy(isAdminTest: true),
      FixedMazeCatalog.normal001 =>
        FixedChallengeMode.normal(isAdminTest: true),
      FixedMazeCatalog.hard001 =>
        FixedChallengeMode.hard(isAdminTest: true),
      FixedMazeCatalog.veryHard001 =>
        FixedChallengeMode.veryHard(isAdminTest: true),
      _ => throw StateError('Unknown admin mazeId: $mazeId'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitAdminMode();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 · 미로 미리보기'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: '관리자 모드 나가기',
            onPressed: _exitAdminMode,
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: [for (final t in _tabs) Tab(text: t.label)],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            for (final model in _models) _buildTab(context, model),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, _PreviewModel model) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.5,
              maxScale: 6,
              boundaryMargin: const EdgeInsets.all(48),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: AdminMazePreviewBoard(
                    maze: model.grid,
                    pathCells: model.pathCells,
                    showPath: _showPath,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => _playCurrent(_modeFor(model.def.mazeId)),
                child: const Text('이 미로 플레이하기'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => setState(() => _showPath = !_showPath),
                      child: Text(_showPath ? '최단 경로 숨기기' : '최단 경로 표시'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '배율 초기화',
                    onPressed: () =>
                        setState(() => _transform.value = Matrix4.identity()),
                    icon: const Icon(Icons.fit_screen),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _openAdminRanking(model.boardKey),
                child: const Text('관리자 테스트 랭킹 보기'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _exitAdminMode,
                child: const Text('관리자 모드 나가기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DefaultTextStyle(
              style: theme.textTheme.bodyMedium!.copyWith(
                color: Colors.white70,
                height: 1.45,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _meta('mazeId', model.def.mazeId),
                  _meta('boardKey', model.boardKey),
                  _meta('크기', '${model.def.size}×${model.def.size}'),
                  _meta(
                    '시작',
                    '(${model.def.start.row}, ${model.def.start.col})',
                  ),
                  _meta(
                    '출구',
                    '(${model.def.exit.row}, ${model.def.exit.col})',
                  ),
                  _meta('BFS 최단 경로', '${model.shortestLength}'),
                  _meta('checksum', model.def.checksum),
                  _meta('rulesVersion', model.def.rulesVersion),
                  Text(
                    '파란점=시작 · 초록점=출구'
                    '${_showPath ? ' · 하늘색=최단경로' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PreviewModel {
  _PreviewModel({
    required this.def,
    required this.boardKey,
    required this.grid,
    required this.pathCells,
    required this.shortestLength,
  });

  final FixedMazeDefinition def;
  final String boardKey;
  final MazeGrid grid;
  final List<GridPos> pathCells;
  final int shortestLength;

  factory _PreviewModel.load(String mazeId, String boardKey) {
    final def = FixedMazeCatalog.definition(mazeId);
    final grid = def.toMazeGrid();
    final path = FixedMazePath.shortestPath(grid) ?? const <GridPos>[];
    final len = path.isEmpty ? -1 : path.length - 1;
    return _PreviewModel(
      def: def,
      boardKey: boardKey,
      grid: grid,
      pathCells: path,
      shortestLength: len,
    );
  }
}
