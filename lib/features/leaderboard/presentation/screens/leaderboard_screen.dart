import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/navigation/navigation_manager.dart';
import '../../../auth/presentation/guest_play_notice.dart';
import '../../../maze/data/weekly_seed_service.dart';
import '../../data/leaderboard_repository.dart';
import '../../domain/fixed_board_keys.dart';
import '../../domain/leaderboard_entry.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    this.weekId,
    this.initialBoardKey,
    this.adminTestsOnly = false,
  });

  final String? weekId;

  /// Optional fixed board deep-link.
  final String? initialBoardKey;

  /// When true, show admin playtest rows only (never mixed into public view).
  final bool adminTestsOnly;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum _BoardTab {
  fixedVeryEasy,
  fixedEasy,
  fixedNormal,
  fixedHard,
  fixedVeryHard,
  weekly,
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late _BoardTab _tab;
  late String _weekId;
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _weekId = widget.weekId ?? WeeklySeedService.weekIdFor();
    _tab = _resolveInitialTab();
    _future = _load();
  }

  _BoardTab _resolveInitialTab() {
    final board = widget.initialBoardKey;
    if (board == FixedBoardKeys.veryEasy) return _BoardTab.fixedVeryEasy;
    if (board == FixedBoardKeys.easy) return _BoardTab.fixedEasy;
    if (board == FixedBoardKeys.normal) return _BoardTab.fixedNormal;
    if (board == FixedBoardKeys.hard) return _BoardTab.fixedHard;
    if (board == FixedBoardKeys.veryHard) return _BoardTab.fixedVeryHard;
    if (widget.weekId != null && !widget.adminTestsOnly) {
      return _BoardTab.weekly;
    }
    return _BoardTab.fixedEasy;
  }

  String get _boardKey => switch (_tab) {
        _BoardTab.fixedVeryEasy => FixedBoardKeys.veryEasy,
        _BoardTab.fixedEasy => FixedBoardKeys.easy,
        _BoardTab.fixedNormal => FixedBoardKeys.normal,
        _BoardTab.fixedHard => FixedBoardKeys.hard,
        _BoardTab.fixedVeryHard => FixedBoardKeys.veryHard,
        _BoardTab.weekly => 'weekly_$_weekId',
      };

  String get _title {
    if (widget.adminTestsOnly) {
      return switch (_tab) {
        _BoardTab.fixedVeryEasy => '관리자 테스트 · 매우 쉬움',
        _BoardTab.fixedEasy => '관리자 테스트 · 쉬움',
        _BoardTab.fixedNormal => '관리자 테스트 · 중간',
        _BoardTab.fixedHard => '관리자 테스트 · 어려움',
        _BoardTab.fixedVeryHard => '관리자 테스트 · 매우 어려움',
        _BoardTab.weekly => '관리자 테스트',
      };
    }
    return switch (_tab) {
      _BoardTab.fixedVeryEasy => '순위표 · 매우 쉬움',
      _BoardTab.fixedEasy => '순위표 · 쉬움',
      _BoardTab.fixedNormal => '순위표 · 중간',
      _BoardTab.fixedHard => '순위표 · 어려움',
      _BoardTab.fixedVeryHard => '순위표 · 매우 어려움',
      _BoardTab.weekly => '순위표 · 주간 $_weekId',
    };
  }

  Iterable<_BoardTab> get _visibleTabs => widget.adminTestsOnly
      ? const [
          _BoardTab.fixedVeryEasy,
          _BoardTab.fixedEasy,
          _BoardTab.fixedNormal,
          _BoardTab.fixedHard,
          _BoardTab.fixedVeryHard,
        ]
      : _BoardTab.values;

  Future<List<LeaderboardEntry>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LeaderboardRepository(prefs);
    if (widget.adminTestsOnly) {
      return repo.adminTestEntriesFor(_boardKey);
    }
    return repo.entriesFor(_boardKey);
  }

  void _selectTab(_BoardTab tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _future = _load();
    });
  }

  void _onBack() {
    if (widget.adminTestsOnly) {
      NavigationManager.goAndClear(context, RoutePaths.adminMazePreview);
    } else {
      NavigationManager.toHome(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _onBack,
        ),
      ),
      body: Column(
        children: [
          if (widget.adminTestsOnly)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '관리자 테스트 기록만 표시 · 일반 랭킹과 분리됨',
                style: TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: GuestPlayNoticeBanner(
                message: GuestPlayNotice.leaderboard,
                compact: true,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _visibleTabs)
                  ChoiceChip(
                    label: Text(switch (t) {
                      _BoardTab.fixedVeryEasy =>
                        widget.adminTestsOnly ? '테스트 매우쉬움' : '매우 쉬움',
                      _BoardTab.fixedEasy =>
                        widget.adminTestsOnly ? '테스트 쉬움' : '쉬움',
                      _BoardTab.fixedNormal =>
                        widget.adminTestsOnly ? '테스트 중간' : '중간',
                      _BoardTab.fixedHard =>
                        widget.adminTestsOnly ? '테스트 어려움' : '어려움',
                      _BoardTab.fixedVeryHard =>
                        widget.adminTestsOnly ? '테스트 매우어려움' : '매우 어려움',
                      _BoardTab.weekly => '주간',
                    }),
                    selected: _tab == t,
                    onSelected: (_) => _selectTab(t),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return const Center(child: Text('아직 기록이 없습니다.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return ListTile(
                      leading: Text(
                        '${i + 1}위',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      title: Text(e.nickname),
                      subtitle: e.isAdminTestRecord
                          ? const Text(
                              '관리자 테스트',
                              style: TextStyle(
                                color: Color(0xFFFF8A80),
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: Text(
                        '${e.elapsedSeconds.toStringAsFixed(2)}초 '
                        '(힌트 ${e.hintCount}회)',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
