import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/navigation/navigation_manager.dart';
import '../../../../core/ui/top_toast.dart';
import '../../../auth/data/game_nickname_service.dart';
import '../../../auth/domain/nickname_rules.dart';
import '../../../auth/presentation/auth_session.dart';
import '../../../auth/presentation/guest_play_notice.dart';
import '../../../leaderboard/data/leaderboard_repository.dart';
import '../../../leaderboard/domain/leaderboard_entry.dart';
import '../../../maze/data/weekly_seed_service.dart';
import '../../../maze/domain/fixed_maze_definition.dart';
import '../../../maze/domain/game_mode.dart';
import '../../../maze/presentation/controllers/game_controller.dart';

final class ResultArgs {
  const ResultArgs({
    required this.mode,
    required this.elapsedSeconds,
    required this.hintCount,
  });

  final GameMode mode;
  final double elapsedSeconds;
  final int hintCount;
}

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.args});

  final ResultArgs args;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _nickCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LeaderboardRepository(prefs);
    // Game nickname is player-registered only — never Kakao profile name.
    final nick = repo.nickname;
    if (!mounted) return;
    if (nick != null && nick.isNotEmpty) {
      _nickCtrl.text = nick;
    }
  }

  bool get _adminTest => switch (widget.args.mode) {
        FixedChallengeMode(:final isAdminTest) => isAdminTest,
        _ => false,
      };

  /// Admin playtests keep local ranking without Kakao.
  /// Everyone else needs login for 순위표; guests save device-only.
  bool get _canSubmitRanking {
    if (_adminTest) return true;
    return ref.watch(authSessionProvider).isLoggedIn;
  }

  /// Returns `true` when the record was saved (or already saved).
  Future<bool> _submit({bool showToast = true}) async {
    if (_submitted) return true;
    final session = ref.read(authSessionProvider);
    final loggedIn = session.isLoggedIn;
    final toRanking = _adminTest || loggedIn;

    final formatError = NicknameRules.validate(_nickCtrl.text);
    if (formatError != null) {
      TopToast.show(context, formatError);
      return false;
    }

    late final String name;
    try {
      // Ranking (non-admin) requires a globally unique nick tied to Kakao id.
      name = await GameNicknameService().save(
        nickname: _nickCtrl.text,
        kakaoId: (loggedIn && !_adminTest) ? session.user!.id : null,
      );
    } on NicknameTakenException {
      if (!mounted) return false;
      TopToast.show(context, '이미 사용 중인 닉네임입니다. 다른 이름을 입력해 주세요.');
      return false;
    } on ArgumentError catch (e) {
      if (!mounted) return false;
      TopToast.show(context, e.message?.toString() ?? '닉네임을 확인해 주세요.');
      return false;
    } catch (e) {
      if (!mounted) return false;
      TopToast.show(context, '닉네임 확인 실패: $e');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final repo = LeaderboardRepository(prefs);

    final playerId = loggedIn
        ? (session.rankingPlayerId ?? await repo.ensurePlayerId())
        : await repo.ensurePlayerId();
    final entry = _buildEntry(playerId: playerId, nickname: name);

    if (toRanking) {
      await repo.submit(entry);
    } else {
      await repo.saveDeviceBest(entry);
    }

    setState(() => _submitted = true);
    if (!mounted) return true;
    _nickCtrl.text = name;
    if (showToast) {
      TopToast.show(
        context,
        _adminTest
            ? '관리자 테스트 랭킹에 기록되었습니다.'
            : toRanking
                ? GuestPlayNotice.savedRanking
                : GuestPlayNotice.savedDeviceOnly,
      );
    }
    return true;
  }

  Future<void> _saveThenRetry() async {
    final ok = await _submit();
    if (!ok || !mounted) return;
    _retry();
  }

  Future<void> _goToRanking() async {
    // Best-effort save so ranking reflects this clear when possible.
    if (!_submitted) {
      await _submit(showToast: false);
    }
    if (!mounted) return;
    _toLeaderboard();
  }

  LeaderboardEntry _buildEntry({
    required String playerId,
    required String nickname,
  }) {
    final mode = widget.args.mode;
    final createdAt = DateTime.now().toUtc();
    return switch (mode) {
      FixedChallengeMode(
        :final boardKey,
        :final mazeId,
        :final rulesVersion,
        :final isAdminTest,
      ) =>
        LeaderboardEntry(
          playerId: playerId,
          nickname: nickname,
          elapsedSeconds: widget.args.elapsedSeconds,
          hintCount: widget.args.hintCount,
          boardKey: boardKey,
          createdAt: createdAt,
          mazeId: mazeId,
          rulesVersion: rulesVersion.isEmpty
              ? FixedMazeDefinition.rulesVersionV1
              : rulesVersion,
          isAdminTest: isAdminTest ? true : null,
        ),
      PracticeMode() || WeeklyChallengeMode() => LeaderboardEntry(
          playerId: playerId,
          nickname: nickname,
          elapsedSeconds: widget.args.elapsedSeconds,
          hintCount: widget.args.hintCount,
          boardKey: mode.seedKey,
          createdAt: createdAt,
        ),
    };
  }

  void _retry() {
    final mode = widget.args.mode;
    final next = switch (mode) {
      PracticeMode(:final difficulty) => PracticeMode(
          difficulty: difficulty,
          seed: GameController.randomSeed(Random()),
        ),
      WeeklyChallengeMode(:final weekId, :final mazeSizeOverride) =>
        WeeklyChallengeMode(
          weekId: weekId,
          seed: WeeklySeedService.seedFromWeekId(weekId),
          mazeSizeOverride: mazeSizeOverride,
        ),
      FixedChallengeMode() => mode.withFreshSession(),
    };
    NavigationManager.retryGame(context, extra: next);
  }

  void _toLeaderboard() {
    final path = switch (widget.args.mode) {
      WeeklyChallengeMode(:final weekId) => '/leaderboard?week=$weekId',
      FixedChallengeMode(:final boardKey, :final isAdminTest) => isAdminTest
          ? '${RoutePaths.leaderboard}?board=$boardKey&admin=1'
          : '${RoutePaths.leaderboard}?board=$boardKey',
      PracticeMode() => RoutePaths.leaderboard,
    };
    NavigationManager.goAndClear(context, path);
  }

  void _backToAdminPreview() {
    NavigationManager.goAndClear(context, RoutePaths.adminMazePreview);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final adminTest = _adminTest;
    final canRank = _canSubmitRanking;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (adminTest) {
          _backToAdminPreview();
        } else {
          NavigationManager.toHome(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(adminTest ? '관리자 클리어!' : '클리어!'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  a.mode.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (adminTest) ...[
                  const SizedBox(height: 8),
                  Text(
                    '이 기록은 관리자 테스트 랭킹에만 반영됩니다.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFFF8A80),
                        ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  GuestPlayNoticeBanner(
                    message: canRank
                        ? GuestPlayNotice.resultLoggedIn
                        : GuestPlayNotice.resultGuest,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '${a.elapsedSeconds.toStringAsFixed(2)}초',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '힌트 ${a.hintCount}회',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _nickCtrl,
                  decoration: InputDecoration(
                    labelText: adminTest
                        ? '닉네임 (관리자 테스트)'
                        : canRank
                            ? '닉네임 (직접 입력)'
                            : '닉네임 (기기 저장용)',
                    hintText: '카카오 이름과 별개로 등록합니다',
                    border: const OutlineInputBorder(),
                  ),
                  enabled: !_submitted,
                  textInputAction: TextInputAction.done,
                ),
                if (_submitted) ...[
                  const SizedBox(height: 8),
                  Text(
                    canRank ? '기록 완료' : '기기 저장 완료',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: _goToRanking,
                  child: Text(adminTest ? '관리자 테스트 순위 보러가기' : '순위 보러가기'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: _saveThenRetry,
                  child: const Text('저장 후 다시 하기'),
                ),
                if (adminTest) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _backToAdminPreview,
                    child: const Text('관리자 모드로 돌아가기'),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => NavigationManager.toHome(context),
                  child: const Text('메인으로'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
