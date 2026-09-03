import 'dart:math' as math;

import 'models.dart';
import 'training_intelligence.dart';

/// One real weight/reps pair selected from one completed training session.
///
/// A point intentionally keeps the source set id and record id so a chart
/// detail can always explain where its values came from. [weight] and [reps]
/// are never calculated from different sets.
class ExerciseGrowthPoint {
  const ExerciseGrowthPoint({
    required this.exerciseId,
    required this.recordId,
    required this.setId,
    required this.date,
    required this.weight,
    required this.reps,
    required this.historyKey,
    this.gymId,
  });

  final String exerciseId;
  final String recordId;
  final String setId;
  final DateTime date;
  final double weight;
  final int reps;
  final String historyKey;
  final String? gymId;

  bool get isBodyweight => weight <= 0;

  /// A capped Epley estimate used only to select a representative loaded set.
  /// High-repetition sets do not get an unbounded estimated-strength boost.
  double get estimated1rm => estimatedOneRepMax(weight, reps);

  String get pairLabel => '${formatGrowthNumber(weight)} kg × $reps 次';
}

/// A conservative one-rep estimate for selecting a representative set.
///
/// This is not shown as a personal record. Repetitions above 12 are capped so
/// a very high-repetition set cannot outweigh a meaningfully heavier set just
/// because of an exaggerated formula estimate. Bodyweight sets are ranked by
/// repetitions and still retain their real 0 kg value for display.
double estimatedOneRepMax(double weight, int reps) {
  if (!weight.isFinite || weight <= 0 || reps <= 0) return 0;
  return weight * (1 + math.min(reps, 12) / 30);
}

String formatGrowthNumber(num value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// Uses the saved session clock when available. Some older records store the
/// calendar date at midnight, so sorting on [WorkoutRecord.date] alone can
/// mistake the order of two sessions on the same day.
DateTime growthRecordDate(WorkoutRecord record) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch(record.startTime.trim());
  if (match == null) return record.date;
  final hour = int.tryParse(match.group(1)!) ?? -1;
  final minute = int.tryParse(match.group(2)!) ?? -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return record.date;
  return DateTime(
    record.date.year,
    record.date.month,
    record.date.day,
    hour,
    minute,
  );
}

bool isComparableGrowthSet(WorkoutSet set) {
  if (!set.completed || set.reps <= 0 || set.weight < 0) return false;
  final type = set.type.trim().toLowerCase();
  // Technique work is not an effective loaded set, just like warm-up work.
  if (type == 'warmup' || type == 'technique' || type == '热身' || type == '技术') {
    return false;
  }
  // weight == 0 is valid for a bodyweight set when it has positive reps.
  return set.weight.isFinite;
}

WorkoutSet? representativeGrowthSet(WorkoutRecord record, String exerciseId) {
  final sets = record.exercises
      .where((item) => item.exerciseId == exerciseId)
      .expand((item) => item.sets)
      .where(isComparableGrowthSet)
      .toList(growable: false);
  if (sets.isEmpty) return null;

  // Loaded and bodyweight sets use different signals. Never let a high
  // bodyweight-repetition count compete directly with a kilogram-based 1RM.
  final candidates = sets
      .where((set) => set.weight > 0)
      .toList(growable: false);
  final comparable = candidates.isEmpty ? sets : candidates;
  WorkoutSet best = comparable.first;
  double score(WorkoutSet set) {
    final estimate = estimatedOneRepMax(set.weight, set.reps);
    // Bodyweight has no comparable kg estimate, so preserve the strongest
    // observable signal: repetitions in the actual set.
    return candidates.isEmpty ? set.reps.toDouble() : estimate;
  }

  for (final set in comparable.skip(1)) {
    if (score(set) > score(best)) best = set;
  }
  return best;
}

String exerciseGrowthHistoryKey({
  required String exerciseId,
  required String? gymId,
  Exercise? definition,
  TrainingIntelligenceEngine engine = const TrainingIntelligenceEngine(),
}) {
  if (definition == null) return exerciseId;
  return engine.strengthHistoryKey(definition, gymId);
}

/// Builds one point per training record, sorted by actual date.
///
/// When [definition] is supplied, machine history follows the existing
/// strength-history venue semantics: standard free weights compare globally,
/// while machine records are keyed by gym. Pass [historyKey] to show only one
/// comparable venue series.
List<ExerciseGrowthPoint> buildExerciseGrowthSeries(
  List<WorkoutRecord> records,
  String exerciseId, {
  Exercise? definition,
  TrainingIntelligenceEngine engine = const TrainingIntelligenceEngine(),
  String? historyKey,
}) {
  final ordered = records.toList()
    ..sort((a, b) {
      final date = growthRecordDate(a).compareTo(growthRecordDate(b));
      return date != 0 ? date : a.id.compareTo(b.id);
    });
  final points = <ExerciseGrowthPoint>[];
  for (final record in ordered) {
    final set = representativeGrowthSet(record, exerciseId);
    if (set == null) continue;
    final key = exerciseGrowthHistoryKey(
      exerciseId: exerciseId,
      gymId: record.gymId,
      definition: definition,
      engine: engine,
    );
    if (historyKey != null && key != historyKey) continue;
    points.add(
      ExerciseGrowthPoint(
        exerciseId: exerciseId,
        recordId: record.id,
        setId: set.id,
        date: growthRecordDate(record),
        weight: set.weight,
        reps: set.reps,
        historyKey: key,
        gymId: record.gymId,
      ),
    );
  }
  return points;
}

/// Returns the latest venue/key when a machine action has mixed locations.
/// Standard free-weight actions normally have one global key.
List<ExerciseGrowthPoint> comparableExerciseGrowthSeries(
  List<ExerciseGrowthPoint> points,
) {
  if (points.isEmpty) return const [];
  final keys = points.map((point) => point.historyKey).toSet();
  if (keys.length <= 1) return points;
  final latestKey = points.last.historyKey;
  return points.where((point) => point.historyKey == latestKey).toList();
}

bool hasMixedExerciseGrowthHistory(List<ExerciseGrowthPoint> points) =>
    points.map((point) => point.historyKey).toSet().length > 1;
