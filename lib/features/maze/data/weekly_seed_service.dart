import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants/game_constants.dart';

/// Builds a deterministic weekly seed key based on Monday 00:00 KST.
///
/// Example week id: `2026-W46`
final class WeeklySeedService {
  WeeklySeedService._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(GameConstants.kstTimezone));
    _initialized = true;
  }

  /// ISO-like week id for the calendar week containing [now] in KST.
  /// Week starts Monday 00:00 KST.
  static String weekIdFor([DateTime? now]) {
    ensureInitialized();
    final kst = tz.getLocation(GameConstants.kstTimezone);
    final instant = tz.TZDateTime.from(now ?? DateTime.now().toUtc(), kst);
    final monday = _mondayStartOfWeek(instant);
    final weekNumber = _isoWeekNumber(monday);
    return '${monday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Stable 32-bit seed derived from [weekId] via FNV-1a.
  static int seedFromWeekId(String weekId) => _fnv1a32(weekId);

  static int seedForCurrentWeek([DateTime? now]) =>
      seedFromWeekId(weekIdFor(now));

  /// Next Monday 00:00 KST after the week of [now].
  static DateTime nextResetAt([DateTime? now]) {
    ensureInitialized();
    final kst = tz.getLocation(GameConstants.kstTimezone);
    final instant = tz.TZDateTime.from(now ?? DateTime.now().toUtc(), kst);
    final monday = _mondayStartOfWeek(instant);
    return monday.add(const Duration(days: 7));
  }

  static tz.TZDateTime _mondayStartOfWeek(tz.TZDateTime instant) {
    // DateTime.weekday: Mon=1 … Sun=7
    final daysFromMonday = instant.weekday - DateTime.monday;
    final dayStart = tz.TZDateTime(
      instant.location,
      instant.year,
      instant.month,
      instant.day,
    );
    return dayStart.subtract(Duration(days: daysFromMonday));
  }

  /// ISO 8601 week number for the Monday of that week.
  static int _isoWeekNumber(tz.TZDateTime monday) {
    // Thursday of this week determines ISO year/week.
    final thursday = monday.add(const Duration(days: 3));
    final jan4 = tz.TZDateTime(thursday.location, thursday.year, 1, 4);
    final week1Monday = _mondayStartOfWeek(jan4);
    final diffDays = thursday.difference(week1Monday).inDays;
    return (diffDays ~/ 7) + 1;
  }

  static int _fnv1a32(String input) {
    const prime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash;
  }
}
