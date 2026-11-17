import '../../maze/domain/fixed_maze_definition.dart';

/// Stable ranked-board keys for frozen mazes (SharedPreferences: `lb_{key}`).
abstract final class FixedBoardKeys {
  static const veryEasy = 'fixed_very_easy';
  static const easy = 'fixed_easy';
  static const normal = 'fixed_normal';
  static const hard = 'fixed_hard';
  static const veryHard = 'fixed_very_hard';

  static const all = <String>[
    veryEasy,
    easy,
    normal,
    hard,
    veryHard,
  ];

  static const mazeIdByBoard = <String, String>{
    veryEasy: 'VERY_EASY-001',
    easy: 'EASY-001',
    normal: 'NORMAL-001',
    hard: 'HARD-001',
    veryHard: 'VERY_HARD-001',
  };

  static const labelByBoard = <String, String>{
    veryEasy: '매우 쉬움',
    easy: '쉬움',
    normal: '중간',
    hard: '어려움',
    veryHard: '매우 어려움',
  };

  /// Current competitive rules tag written on every new fixed submit.
  static const String currentRulesVersion = FixedMazeDefinition.rulesVersionV1;

  static bool isFixed(String boardKey) => mazeIdByBoard.containsKey(boardKey);

  static String? mazeIdFor(String boardKey) => mazeIdByBoard[boardKey];

  static String prefsKey(String boardKey) => 'lb_$boardKey';
}
