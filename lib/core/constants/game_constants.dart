/// Global gameplay / economy constants.
abstract final class GameConstants {
  static const int defaultHintCount = 3;
  static const int maxAdHintPerRound = 2;
  static const int maxTotalHintsPerRound =
      defaultHintCount + maxAdHintPerRound; // 5

  static const Duration hintRevealDuration = Duration(seconds: 3);

  /// Timer display precision: 0.01s
  static const int timerCentisecondDigits = 2;

  static const String kstTimezone = 'Asia/Seoul';
}
