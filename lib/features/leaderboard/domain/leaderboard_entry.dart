import 'package:equatable/equatable.dart';

/// Clear time (centiseconds) + hint count.
///
/// Official rank / personal-best order:
/// 1) hintCount ASC — no-hint runs always beat hinted runs
/// 2) elapsedCentiseconds ASC
/// 3) createdAt ASC when tied (preserve earlier registration)
final class LeaderboardEntry extends Equatable
    implements Comparable<LeaderboardEntry> {
  const LeaderboardEntry({
    required this.playerId,
    required this.nickname,
    required this.elapsedSeconds,
    required this.hintCount,
    required this.boardKey,
    this.createdAt,
    this.mazeId,
    this.rulesVersion,
    this.isAdminTest,
  });

  final String playerId;
  final String nickname;

  /// Precise to 0.01s (e.g. 12.45).
  final double elapsedSeconds;
  final int hintCount;

  /// `weekly_2026-W46`, `practice_hard_<seed>`, or `fixed_easy` etc.
  final String boardKey;
  final DateTime? createdAt;

  /// Frozen maze id for fixed boards (optional for legacy weekly/practice JSON).
  final String? mazeId;

  /// Movement/hint rules tag (optional for legacy entries).
  final String? rulesVersion;

  /// Admin playtest marker. Absent/`false` = public ranking; `true` = admin-only.
  final bool? isAdminTest;

  bool get isAdminTestRecord => isAdminTest == true;

  int get elapsedCentiseconds => (elapsedSeconds * 100).round();

  String get displayLine =>
      '$nickname | ${elapsedSeconds.toStringAsFixed(2)}초 (힌트 $hintCount회)';

  /// True when [candidate] should replace [existing] as personal best.
  /// Equal hint+time → false (keep existing).
  static bool isBetterRecord(
    LeaderboardEntry candidate,
    LeaderboardEntry existing,
  ) {
    final hintCmp = candidate.hintCount.compareTo(existing.hintCount);
    if (hintCmp != 0) return hintCmp < 0;
    return candidate.elapsedCentiseconds < existing.elapsedCentiseconds;
  }

  @override
  int compareTo(LeaderboardEntry other) {
    final hintCmp = hintCount.compareTo(other.hintCount);
    if (hintCmp != 0) return hintCmp;
    final timeCmp = elapsedCentiseconds.compareTo(other.elapsedCentiseconds);
    if (timeCmp != 0) return timeCmp;
    final a = createdAt;
    final b = other.createdAt;
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'nickname': nickname,
        'elapsedSeconds': elapsedSeconds,
        'hintCount': hintCount,
        'boardKey': boardKey,
        'createdAt': createdAt?.toIso8601String(),
        if (mazeId != null) 'mazeId': mazeId,
        if (rulesVersion != null) 'rulesVersion': rulesVersion,
        if (isAdminTest != null) 'isAdminTest': isAdminTest,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      nickname: json['nickname'] as String,
      elapsedSeconds: (json['elapsedSeconds'] as num).toDouble(),
      hintCount: json['hintCount'] as int,
      boardKey: json['boardKey'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      mazeId: json['mazeId'] as String?,
      rulesVersion: json['rulesVersion'] as String?,
      isAdminTest: json['isAdminTest'] as bool?,
    );
  }

  @override
  List<Object?> get props => [
        playerId,
        nickname,
        elapsedSeconds,
        hintCount,
        boardKey,
        mazeId,
        rulesVersion,
        isAdminTest,
      ];
}
