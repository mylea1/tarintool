import 'models.dart';
import 'exercise_growth.dart';

DateTime trendDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Latest actual measurement per day, retaining its ID, time and note.
List<WeightEntry> dailyWeightRecords(
  List<WeightEntry> entries,
  DateTime start,
  DateTime end,
) {
  final byDay = <DateTime, WeightEntry>{};
  for (final entry in entries) {
    final day = trendDay(entry.recordedAt);
    if (day.isBefore(trendDay(start)) ||
        day.isAfter(trendDay(end)) ||
        !entry.weightKg.isFinite ||
        entry.weightKg <= 0) {
      continue;
    }
    final previous = byDay[day];
    if (previous == null || entry.recordedAt.isAfter(previous.recordedAt)) {
      byDay[day] = entry;
    }
  }
  return byDay.values.toList()
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
}

class WeeklyTrainingVolume {
  const WeeklyTrainingVolume({
    required this.weekStart,
    required this.start,
    required this.end,
    required this.records,
    required this.now,
  });
  final DateTime weekStart, start, end, now;
  final List<WorkoutRecord> records;
  int get missingDetails => records.where((r) => r.exercises.isEmpty).length;
  double get volume => records
      .expand((r) => r.exercises)
      .expand((e) => e.sets)
      .where((s) => isComparableGrowthSet(s) && s.weight > 0)
      .fold(0.0, (sum, s) => sum + s.weight * s.reps);
  bool get partial =>
      start.isAfter(weekStart) ||
      end.isBefore(
        DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
      );
  bool get current =>
      !trendDay(now).isBefore(weekStart) &&
      trendDay(
        now,
      ).isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day + 7));
}

/// Includes empty weeks. Legacy aggregate-only records are explicitly flagged
/// instead of silently combining incompatible volume definitions.
List<WeeklyTrainingVolume> weeklyTrainingVolumes(
  List<WorkoutRecord> records,
  DateTime start,
  DateTime end, {
  required DateTime now,
}) {
  final from = trendDay(start);
  final to = trendDay(end).isAfter(trendDay(now))
      ? trendDay(now)
      : trendDay(end);
  if (to.isBefore(from)) return [];
  final result = <WeeklyTrainingVolume>[];
  var week = DateTime(from.year, from.month, from.day - from.weekday + 1);
  while (!week.isAfter(to)) {
    final last = DateTime(week.year, week.month, week.day + 6);
    final periodStart = week.isBefore(from) ? from : week;
    final periodEnd = last.isAfter(to) ? to : last;
    final matches =
        records.where((r) {
            final day = trendDay(r.date);
            return !day.isBefore(periodStart) && !day.isAfter(periodEnd);
          }).toList()
          ..sort((a, b) => growthRecordDate(a).compareTo(growthRecordDate(b)));
    result.add(
      WeeklyTrainingVolume(
        weekStart: week,
        start: periodStart,
        end: periodEnd,
        records: matches,
        now: now,
      ),
    );
    week = DateTime(week.year, week.month, week.day + 7);
  }
  return result;
}
