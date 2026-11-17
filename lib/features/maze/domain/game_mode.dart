import 'difficulty.dart';
import 'fixed_maze_definition.dart';

sealed class GameMode {
  const GameMode();

  String get displayName;
  int get mazeSize;

  /// Leaderboard / persistence key (stable across retries for fixed modes).
  String get seedKey;

  /// Widget remount key for `/game` (may include session nonce).
  String get routeInstanceKey => seedKey;
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

  /// Fixed weekly size (중간-tier density by default).
  final int mazeSizeOverride;

  @override
  String get displayName => '주간 챌린지 · $weekId';

  @override
  int get mazeSize => mazeSizeOverride;

  @override
  String get seedKey => 'weekly_$weekId';
}

/// Ranked fixed maze: same dump for every player / every retry.
final class FixedChallengeMode extends GameMode {
  const FixedChallengeMode({
    required this.difficulty,
    required this.mazeId,
    required this.boardKey,
    this.rulesVersion = FixedMazeDefinition.rulesVersionV1,
    this.sessionId = '0',
    this.isAdminTest = false,
  });

  final Difficulty difficulty;
  final String mazeId;
  final String boardKey;
  final String rulesVersion;

  /// Changes on each entry/retry so [routeInstanceKey] remounts GameScreen.
  final String sessionId;

  /// When true, play uses the same maze/physics but scores go to admin ranking.
  final bool isAdminTest;

  factory FixedChallengeMode.veryEasy({
    String? sessionId,
    bool isAdminTest = false,
  }) =>
      FixedChallengeMode(
        difficulty: Difficulty.veryEasy,
        mazeId: 'VERY_EASY-001',
        boardKey: 'fixed_very_easy',
        sessionId: sessionId ?? _newSessionId(),
        isAdminTest: isAdminTest,
      );

  factory FixedChallengeMode.easy({
    String? sessionId,
    bool isAdminTest = false,
  }) =>
      FixedChallengeMode(
        difficulty: Difficulty.easy,
        mazeId: 'EASY-001',
        boardKey: 'fixed_easy',
        sessionId: sessionId ?? _newSessionId(),
        isAdminTest: isAdminTest,
      );

  factory FixedChallengeMode.normal({
    String? sessionId,
    bool isAdminTest = false,
  }) =>
      FixedChallengeMode(
        difficulty: Difficulty.normal,
        mazeId: 'NORMAL-001',
        boardKey: 'fixed_normal',
        sessionId: sessionId ?? _newSessionId(),
        isAdminTest: isAdminTest,
      );

  factory FixedChallengeMode.hard({
    String? sessionId,
    bool isAdminTest = false,
  }) =>
      FixedChallengeMode(
        difficulty: Difficulty.hard,
        mazeId: 'HARD-001',
        boardKey: 'fixed_hard',
        sessionId: sessionId ?? _newSessionId(),
        isAdminTest: isAdminTest,
      );

  factory FixedChallengeMode.veryHard({
    String? sessionId,
    bool isAdminTest = false,
  }) =>
      FixedChallengeMode(
        difficulty: Difficulty.veryHard,
        mazeId: 'VERY_HARD-001',
        boardKey: 'fixed_very_hard',
        sessionId: sessionId ?? _newSessionId(),
        isAdminTest: isAdminTest,
      );

  /// Same maze identity, new session (for retry remount).
  FixedChallengeMode withFreshSession() => FixedChallengeMode(
        difficulty: difficulty,
        mazeId: mazeId,
        boardKey: boardKey,
        rulesVersion: rulesVersion,
        sessionId: _newSessionId(),
        isAdminTest: isAdminTest,
      );

  static String _newSessionId() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  @override
  String get displayName => isAdminTest
      ? '관리자 테스트 · ${difficulty.label}'
      : '랭킹 · ${difficulty.label}';

  @override
  int get mazeSize => difficulty.size;

  /// Stable board key for rankings; no session suffix.
  @override
  String get seedKey => boardKey;

  @override
  String get routeInstanceKey =>
      isAdminTest ? '$boardKey#admin#$sessionId' : '$boardKey#$sessionId';
}
