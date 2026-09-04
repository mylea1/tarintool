import 'dart:math' as math;

import 'models.dart';
import 'training_knowledge_rules.dart';

/// One location owns its machine history. Standard free weights are compared
/// globally by [TrainingIntelligenceEngine.strengthHistoryKey].
class GymLocationProfile {
  const GymLocationProfile({
    required this.id,
    required this.name,
    required this.equipment,
    this.exerciseIds = const [],
    this.isCurrent = false,
  });

  final String id;
  final String name;
  final List<String> equipment;
  final List<String> exerciseIds;
  final bool isCurrent;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'equipment': equipment,
    'exerciseIds': exerciseIds,
    'isCurrent': isCurrent,
  };

  factory GymLocationProfile.fromJson(Map<String, dynamic> json) =>
      GymLocationProfile(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '训练地点',
        equipment: _strings(json['equipment']),
        exerciseIds: _strings(json['exerciseIds']),
        isCurrent: json['isCurrent'] == true,
      );
}

class TechniqueAssessment {
  const TechniqueAssessment({
    required this.id,
    required this.exerciseId,
    required this.createdAt,
    required this.scoreable,
    required this.overall,
    required this.rom,
    required this.stability,
    required this.symmetry,
    required this.tempo,
    required this.trajectory,
    this.videoPath,
    this.qualityReason = '',
    this.strengths = const [],
    this.issues = const [],
    this.nextFocus = '',
  });

  final String id;
  final String exerciseId;
  final DateTime createdAt;
  final bool scoreable;
  final int overall;
  final int rom;
  final int stability;
  final int symmetry;
  final int tempo;
  final int trajectory;
  final String? videoPath;
  final String qualityReason;
  final List<String> strengths;
  final List<String> issues;
  final String nextFocus;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'createdAt': createdAt.toIso8601String(),
    'scoreable': scoreable,
    'overall': overall,
    'rom': rom,
    'stability': stability,
    'symmetry': symmetry,
    'tempo': tempo,
    'trajectory': trajectory,
    'videoPath': videoPath,
    'qualityReason': qualityReason,
    'strengths': strengths,
    'issues': issues,
    'nextFocus': nextFocus,
  };

  factory TechniqueAssessment.fromJson(Map<String, dynamic> json) =>
      TechniqueAssessment(
        id: json['id']?.toString() ?? '',
        exerciseId: json['exerciseId']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        scoreable: json['scoreable'] == true,
        overall: _integer(json['overall']),
        rom: _integer(json['rom']),
        stability: _integer(json['stability']),
        symmetry: _integer(json['symmetry']),
        tempo: _integer(json['tempo']),
        trajectory: _integer(json['trajectory']),
        videoPath: json['videoPath']?.toString(),
        qualityReason: json['qualityReason']?.toString() ?? '',
        strengths: _strings(json['strengths']),
        issues: _strings(json['issues']),
        nextFocus: json['nextFocus']?.toString() ?? '',
      );
}

class MuscleRecovery {
  const MuscleRecovery(this.muscle, this.percent, this.reason);
  final String muscle;
  final int percent;
  final String reason;

  String get status => percent >= 80
      ? '恢复良好'
      : percent >= 60
      ? '基本恢复'
      : percent >= 40
      ? '仍有疲劳'
      : '建议休息';
}

class MuscleVolume {
  const MuscleVolume(this.muscle, this.effectiveSets, this.status);
  final String muscle;
  final double effectiveSets;
  final String status;
}

class ProgressionRecommendation {
  const ProgressionRecommendation({
    required this.exerciseId,
    required this.weight,
    required this.sets,
    required this.targetMin,
    required this.targetMax,
    required this.decision,
    required this.reason,
  });
  final String exerciseId;
  final double weight;
  final int sets;
  final int targetMin;
  final int targetMax;
  final String decision;
  final String reason;
}

class DailyTrainingRecommendation {
  const DailyTrainingRecommendation({
    required this.title,
    required this.muscles,
    required this.reason,
    required this.estimatedMinutes,
    required this.exerciseCount,
    this.routineId,
    this.hasTrainingData = true,
  });
  final String title;
  final List<String> muscles;
  final String reason;
  final int estimatedMinutes;
  final int exerciseCount;
  final String? routineId;

  /// False means neither a completed onboarding baseline nor real completed
  /// training data is available, so the engine intentionally withheld a
  /// recommendation.
  final bool hasTrainingData;
}

class WeeklyTrainingReport {
  const WeeklyTrainingReport({
    required this.sessions,
    required this.durationMinutes,
    required this.volumeChangePercent,
    required this.strengthChangePercent,
    required this.techniqueChange,
    required this.bestMuscle,
    required this.undertrainedMuscle,
    required this.summary,
    required this.nextWeekAdvice,
    this.personalRecords = const [],
  });
  final int sessions;
  final int durationMinutes;
  final double volumeChangePercent;
  final double strengthChangePercent;
  final int techniqueChange;
  final String bestMuscle;
  final String undertrainedMuscle;
  final String summary;
  final String nextWeekAdvice;
  final List<String> personalRecords;
}

class TrainingIntelligenceSnapshot {
  const TrainingIntelligenceSnapshot({
    required this.recovery,
    required this.volume4Weeks,
    required this.today,
    required this.weeklyReport,
  });
  final List<MuscleRecovery> recovery;
  final List<MuscleVolume> volume4Weeks;
  final DailyTrainingRecommendation today;
  final WeeklyTrainingReport weeklyReport;
}

class TrainingIntelligenceEngine {
  const TrainingIntelligenceEngine();

  static const muscles = <String>[
    '胸',
    '背',
    '肩',
    '二头',
    '三头',
    '股四头',
    '腘绳肌',
    '臀',
    '小腿',
    '核心',
  ];
  static const volumeMuscles = <String>[
    ...muscles,
    '上胸',
    '中胸',
    '前三角',
    '中三角',
    '后三角',
    '三头长头',
  ];

  TrainingIntelligenceSnapshot calculate({
    required List<WorkoutRecord> history,
    required List<Exercise> exercises,
    required List<Routine> routines,
    required List<TechniqueAssessment> techniques,
    required TrainingProfile profile,
    String? scheduledRoutineName,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final recovery = calculateRecovery(history, exercises, now: clock);
    final volume = calculateVolume(
      history,
      exercises,
      start: clock.subtract(const Duration(days: 28)),
      end: clock,
      normalizationDays: 28,
    );
    return TrainingIntelligenceSnapshot(
      recovery: recovery,
      volume4Weeks: volume,
      today: recommendToday(
        history: history,
        exercises: exercises,
        routines: routines,
        recovery: recovery,
        volume: volume,
        profile: profile,
        preferredRoutineName: scheduledRoutineName,
        now: clock,
      ),
      weeklyReport: weeklyReport(
        history: history,
        exercises: exercises,
        techniques: techniques,
        now: clock,
      ),
    );
  }

  List<MuscleRecovery> calculateRecovery(
    List<WorkoutRecord> history,
    List<Exercise> exercises, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final exerciseMap = {for (final item in exercises) item.id: item};
    return [
      for (final muscle in muscles)
        () {
          var fatigue = 0.0;
          DateTime? latest;
          for (final record in history) {
            final ageHours = clock.difference(record.date).inMinutes / 60;
            if (ageHours < 0 || ageHours > 168) continue;
            for (final performed in record.exercises) {
              final definition = exerciseMap[performed.exerciseId];
              if (definition == null) continue;
              final factor = _muscleFactor(definition, muscle);
              if (factor <= 0) continue;
              for (final set in performed.sets.where(
                (item) => item.completed,
              )) {
                final effort = set.rir != null
                    ? (1.25 - set.rir! * .09).clamp(.72, 1.3)
                    : set.rpe != null
                    ? (.55 + set.rpe! * .075).clamp(.7, 1.3)
                    : 1.0;
                fatigue +=
                    factor * effort * math.exp(-ageHours / 38).clamp(0, 1);
                if (latest == null || record.date.isAfter(latest)) {
                  latest = record.date;
                }
              }
            }
          }
          final percent = (100 - fatigue * 9.2).round().clamp(0, 100);
          final reason = latest == null
              ? '暂无近期刺激，按充分恢复处理'
              : '距上次相关训练 ${clock.difference(latest).inHours.clamp(0, 999)} 小时，已计入训练组数与接近力竭程度';
          return MuscleRecovery(muscle, percent, reason);
        }(),
    ];
  }

  List<MuscleVolume> calculateVolume(
    List<WorkoutRecord> history,
    List<Exercise> exercises, {
    required DateTime start,
    required DateTime end,
    int normalizationDays = 7,
  }) {
    final exerciseMap = {for (final item in exercises) item.id: item};
    final weeks = math.max(1.0, normalizationDays / 7);
    return [
      for (final muscle in volumeMuscles)
        () {
          var sets = 0.0;
          for (final record in history) {
            if (record.date.isBefore(start) || record.date.isAfter(end)) {
              continue;
            }
            for (final performed in record.exercises) {
              final definition = exerciseMap[performed.exerciseId];
              if (definition == null) continue;
              sets +=
                  performed.sets.where((item) => item.completed).length *
                  _muscleFactor(definition, muscle);
            }
          }
          final weekly = sets / weeks;
          final status = weekly < 6
              ? '训练不足'
              : weekly <= 16
              ? '训练适中'
              : weekly <= 22
              ? '训练较高'
              : '可能过量';
          return MuscleVolume(muscle, sets, status);
        }(),
    ];
  }

  ProgressionRecommendation recommendProgression({
    required String exerciseId,
    required List<WorkoutRecord> history,
    required List<TechniqueAssessment> techniques,
    required int recoveryPercent,
    String? gymId,
    bool machineExercise = false,
  }) {
    final sessions = <List<WorkoutSet>>[];
    for (final record in history) {
      if (machineExercise && gymId != null && record.gymId != gymId) continue;
      final matching = record.exercises
          .where((item) => item.exerciseId == exerciseId)
          .expand((item) => item.sets)
          .where((set) => set.completed && set.weight > 0 && set.reps > 0)
          .toList();
      if (matching.isNotEmpty) sessions.add(matching);
      if (sessions.length == 3) break;
    }
    if (sessions.isEmpty) {
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        weight: 0,
        sets: 3,
        targetMin: 8,
        targetMax: 12,
        decision: '建立基线',
        reason: '还没有可比较的实际训练记录，请先用可稳定完成的重量建立基线。',
      );
    }
    final latest = sessions.first;
    final weight = latest.map((set) => set.weight).reduce(math.max);
    final targetMin = latest
        .map((set) => set.targetMin)
        .where((v) => v > 0)
        .fold(8, math.min);
    final targetMax = latest
        .map((set) => set.targetMax)
        .where((v) => v > 0)
        .fold(12, math.max);
    final latestTechnique = techniques
        .where((item) => item.exerciseId == exerciseId && item.scoreable)
        .firstOrNull;
    final qualityBlocksIncrease =
        latestTechnique != null &&
        (latestTechnique.overall < 80 || latestTechnique.stability < 78);
    final allMet = sessions
        .take(2)
        .every(
          (sets) => sets.every((set) => set.reps >= math.max(1, set.targetMax)),
        );
    final effortAllows = latest.every(
      (set) =>
          (set.rir == null || set.rir! >= 2) &&
          (set.rpe == null || set.rpe! <= 8),
    );
    if (recoveryPercent < 60) {
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        weight: weight,
        sets: math.max(2, latest.length - 1),
        targetMin: targetMin,
        targetMax: targetMax,
        decision: '减少训练量',
        reason: '相关肌群恢复仅 $recoveryPercent%，本次保留重量并减少一组；你仍可按实际状态调整。',
      );
    }
    if (qualityBlocksIncrease) {
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        weight: weight,
        sets: latest.length,
        targetMin: targetMin,
        targetMax: targetMax,
        decision: '保持重量',
        reason:
            '最近动作评分 ${latestTechnique.overall}，稳定性 ${latestTechnique.stability}；先保持重量并改善动作质量。',
      );
    }
    if (sessions.length >= 2 && allMet && effortAllows) {
      final increment = weight >= 60 ? 2.5 : 1.0;
      return ProgressionRecommendation(
        exerciseId: exerciseId,
        weight: weight + increment,
        sets: latest.length,
        targetMin: math.max(1, targetMin - 2),
        targetMax: math.max(2, targetMax - 2),
        decision: '增加重量',
        reason: '最近两次均完成目标上限，且 RIR/RPE 未显示接近力竭，恢复状态良好，建议小幅加重。',
      );
    }
    final missed = latest.any((set) => set.reps < math.max(1, set.targetMin));
    return ProgressionRecommendation(
      exerciseId: exerciseId,
      weight: weight,
      sets: latest.length,
      targetMin: targetMin,
      targetMax: targetMax,
      decision: missed ? '保持重量并补足次数' : '保持重量',
      reason: missed
          ? '上次仍有组数未达到目标下限，先用同一重量补齐目标，不机械加重。'
          : '当前证据不足以安全加重，继续完成目标次数并记录 RIR/RPE。',
    );
  }

  DailyTrainingRecommendation recommendToday({
    required List<WorkoutRecord> history,
    required List<Exercise> exercises,
    required List<Routine> routines,
    required List<MuscleRecovery> recovery,
    required List<MuscleVolume> volume,
    required TrainingProfile profile,
    String? preferredRoutineName,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final hasCompletedTraining = TrainingKnowledgeRules.hasCompletedSet(
      history,
    );
    if (!hasCompletedTraining && !profile.hasRecommendationBaseline) {
      return const DailyTrainingRecommendation(
        title: '暂无训练数据',
        muscles: [],
        reason: '完成基础训练档案后，系统会先按目标与偏好生成建议。',
        estimatedMinutes: 0,
        exerciseCount: 0,
        hasTrainingData: false,
      );
    }
    final recoveryMap = {
      for (final item in recovery) item.muscle: item.percent,
    };
    final volumeMap = {for (final item in volume) item.muscle: item};
    final exerciseMap = {for (final item in exercises) item.id: item};
    final recentMuscles = _recentMuscles(history, exerciseMap, now: clock);
    final recentRoutineIds = <String>{};
    for (final routine in routines) {
      if (_wasRoutineRecentlyPerformed(routine, history, now: clock)) {
        recentRoutineIds.add(routine.id);
      }
    }
    final ranked = [...muscles]
      ..sort((a, b) {
        final ar = recoveryMap[a] ?? 100;
        final br = recoveryMap[b] ?? 100;
        final av =
            (volumeMap[a]?.status == '训练不足' ? 15 : 0) +
            (profile.focusMuscles.contains(a) ? 12 : 0) -
            (profile.reducedMuscles.contains(a) ? 12 : 0) -
            (_isRecent(recentMuscles[a], clock) ? 100 : 0);
        final bv =
            (volumeMap[b]?.status == '训练不足' ? 15 : 0) +
            (profile.focusMuscles.contains(b) ? 12 : 0) -
            (profile.reducedMuscles.contains(b) ? 12 : 0) -
            (_isRecent(recentMuscles[b], clock) ? 100 : 0);
        return (br + bv).compareTo(ar + av);
      });
    final recovered = ranked
        .where((item) => (recoveryMap[item] ?? 100) >= 60)
        .toList();
    // A recently trained muscle is excluded whenever another recovered
    // candidate exists. Only if every recovered option is recent do we allow
    // continuity, and the reason below makes that trade-off explicit.
    final fresh = recovered
        .where((item) => !_isRecent(recentMuscles[item], clock))
        .toList();
    final selected = (fresh.isNotEmpty ? fresh : recovered)
        .take(TrainingKnowledgeRules.maxPrimaryMuscles)
        .toList();
    Routine? best;
    if (preferredRoutineName != null) {
      best = routines
          .where((item) => item.name == preferredRoutineName)
          .firstOrNull;
      if (best != null) {
        final plannedMuscles = _routineMuscles(best, exerciseMap);
        final recoveredPlan = plannedMuscles.every(
          (muscle) =>
              (recoveryMap[muscle] ?? 100) >=
              TrainingKnowledgeRules.minimumRecoveryForPrimary,
        );
        final recentPlan = plannedMuscles.any(
          (muscle) => _isRecent(recentMuscles[muscle], clock),
        );
        if (!recoveredPlan || (recentPlan && fresh.isNotEmpty)) best = null;
        if (best != null && recentRoutineIds.contains(best.id)) best = null;
      }
    }
    var bestHits = -1;
    for (final routine in best == null ? routines : const <Routine>[]) {
      if (recentRoutineIds.contains(routine.id)) continue;
      final plannedMuscles = _routineMuscles(routine, exerciseMap);
      final hasFatiguedPrimary = plannedMuscles.any(
        (muscle) =>
            (recoveryMap[muscle] ?? 100) <
            TrainingKnowledgeRules.minimumRecoveryForPrimary,
      );
      if (hasFatiguedPrimary) continue;
      final hasRecentPrimary = plannedMuscles.any(
        (muscle) => _isRecent(recentMuscles[muscle], clock),
      );
      if (hasRecentPrimary && fresh.isNotEmpty) continue;
      final hits = routine.exercises.where((performed) {
        final definition = exerciseMap[performed.exerciseId];
        return definition != null &&
            selected.any((m) => _muscleFactor(definition, m) >= 1);
      }).length;
      if (hits > bestHits) {
        best = routine;
        bestHits = hits;
      }
    }
    final recommendedMuscles = best == null
        ? selected
        : best.exercises
              .map((performed) => exerciseMap[performed.exerciseId])
              .whereType<Exercise>()
              .expand(
                (definition) => muscles.where(
                  (muscle) => _muscleFactor(definition, muscle) >= 1,
                ),
              )
              .toSet()
              .take(3)
              .toList();
    final title =
        best?.name ??
        (selected.isEmpty ? '今天先恢复' : '${selected.join(' + ')}训练');
    final count = best?.exercises.length ?? (selected.isEmpty ? 0 : 5);
    final recentFallback = fresh.isEmpty && recovered.isNotEmpty;
    return DailyTrainingRecommendation(
      title: title,
      muscles: recommendedMuscles,
      reason: !hasCompletedTraining
          ? '这是依据你的${_goalLabel(profile.goal)}目标、每周 ${profile.preferredWeekdays.length} 天、'
                '单次 ${profile.sessionMinutes} 分钟和重点肌群生成的首份建议；完成后会再按真实表现调整。'
          : '${recommendedMuscles.map((m) => '$m恢复 ${recoveryMap[m] ?? 100}%').join('，')}'
                '${recentFallback ? '；近期主要肌群均在冷却窗口内，已优先延续可恢复计划' : ''}'
                '；'
                '${preferredRoutineName == best?.name ? '已承接今天或最近漏掉的计划，' : ''}'
                '同时优先补足近4周训练量较低的肌群。',
      estimatedMinutes: best == null
          ? profile.sessionMinutes
          : (best.exercises.fold<int>(
                          0,
                          (sum, item) => sum + item.sets.length,
                        ) *
                        3 +
                    count * 2)
                .clamp(20, 100),
      exerciseCount: count,
      routineId: best?.id,
    );
  }

  String _goalLabel(String? goal) => switch (goal) {
    'muscle_gain' => '增肌',
    'fat_loss' => '减脂',
    'body_recomp' => '塑形',
    'strength' => '力量',
    _ => '当前',
  };

  Map<String, DateTime> _recentMuscles(
    List<WorkoutRecord> history,
    Map<String, Exercise> exerciseMap, {
    required DateTime now,
  }) {
    final result = <String, DateTime>{};
    for (final record in history) {
      final ageHours = now.difference(record.date).inMinutes / 60;
      if (ageHours < 0 ||
          ageHours > TrainingKnowledgeRules.recentStimulusCooldownHours) {
        continue;
      }
      for (final performed in record.exercises) {
        if (!performed.sets.any((set) => set.completed)) continue;
        final definition = exerciseMap[performed.exerciseId];
        if (definition == null) continue;
        for (final muscle in muscles) {
          if (_muscleFactor(definition, muscle) < 1) continue;
          final previous = result[muscle];
          if (previous == null || record.date.isAfter(previous)) {
            result[muscle] = record.date;
          }
        }
      }
    }
    return result;
  }

  bool _wasRoutineRecentlyPerformed(
    Routine routine,
    List<WorkoutRecord> history, {
    required DateTime now,
  }) {
    final routineExercises = routine.exercises
        .map((item) => item.exerciseId)
        .toSet();
    if (routineExercises.isEmpty) return false;
    for (final record in history) {
      final ageHours = now.difference(record.date).inMinutes / 60;
      if (ageHours < 0 ||
          ageHours > TrainingKnowledgeRules.recentStimulusCooldownHours ||
          !TrainingKnowledgeRules.hasCompletedSet([record])) {
        continue;
      }
      if (record.name.trim() == routine.name.trim()) return true;
      final performed = record.exercises
          .where((item) => item.sets.any((set) => set.completed))
          .map((item) => item.exerciseId)
          .toSet();
      if (performed.isEmpty) continue;
      final overlap = routineExercises.intersection(performed).length;
      final denominator = math.min(routineExercises.length, performed.length);
      if (denominator > 0 && overlap / denominator >= .75) return true;
    }
    return false;
  }

  Set<String> _routineMuscles(
    Routine routine,
    Map<String, Exercise> exerciseMap,
  ) => routine.exercises
      .map((item) => exerciseMap[item.exerciseId])
      .whereType<Exercise>()
      .expand(
        (definition) =>
            muscles.where((muscle) => _muscleFactor(definition, muscle) >= 1),
      )
      .toSet();

  bool _isRecent(DateTime? value, DateTime now) {
    if (value == null) return false;
    final ageHours = now.difference(value).inMinutes / 60;
    return ageHours >= 0 &&
        ageHours <= TrainingKnowledgeRules.recentStimulusCooldownHours;
  }

  WeeklyTrainingReport weeklyReport({
    required List<WorkoutRecord> history,
    required List<Exercise> exercises,
    required List<TechniqueAssessment> techniques,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final thisStart = DateTime(
      clock.year,
      clock.month,
      clock.day,
    ).subtract(Duration(days: clock.weekday - 1));
    final previousStart = thisStart.subtract(const Duration(days: 7));
    final current = history.where((r) => !r.date.isBefore(thisStart)).toList();
    final previous = history
        .where(
          (r) => !r.date.isBefore(previousStart) && r.date.isBefore(thisStart),
        )
        .toList();
    double sumVolume(List<WorkoutRecord> items) =>
        items.fold(0, (sum, r) => sum + r.volume);
    final currentVolume = sumVolume(current);
    final previousVolume = sumVolume(previous);
    final volumeChange = previousVolume <= 0
        ? 0.0
        : (currentVolume - previousVolume) / previousVolume * 100;
    final volumes = calculateVolume(
      current,
      exercises,
      start: thisStart,
      end: clock,
    );
    final ranked = [...volumes]
      ..sort((a, b) => b.effectiveSets.compareTo(a.effectiveSets));
    final currentTech = techniques
        .where((t) => t.scoreable && !t.createdAt.isBefore(thisStart))
        .toList();
    final previousTech = techniques
        .where(
          (t) =>
              t.scoreable &&
              !t.createdAt.isBefore(previousStart) &&
              t.createdAt.isBefore(thisStart),
        )
        .toList();
    int average(List<TechniqueAssessment> items) => items.isEmpty
        ? 0
        : (items.fold<int>(0, (s, t) => s + t.overall) / items.length).round();
    final techniqueChange = previousTech.isEmpty
        ? 0
        : average(currentTech) - average(previousTech);
    final best = ranked.firstOrNull?.muscle ?? '暂无';
    final under = ranked.lastOrNull?.muscle ?? '暂无';
    double bestE1rm(WorkoutRecord record, String exerciseId) => record.exercises
        .where((item) => item.exerciseId == exerciseId)
        .expand((item) => item.sets)
        .where((set) => set.completed && set.weight > 0 && set.reps > 0)
        .fold(
          0,
          (best, set) => math.max(best, set.weight * (1 + set.reps / 30)),
        );
    final strengthChanges = <double>[];
    for (final record in current) {
      for (final exerciseId in record.exerciseIds.toSet()) {
        final currentBest = bestE1rm(record, exerciseId);
        final previousBest = previous
            .map((item) => bestE1rm(item, exerciseId))
            .fold<double>(0, math.max);
        if (currentBest > 0 && previousBest > 0) {
          strengthChanges.add(
            (currentBest - previousBest) / previousBest * 100,
          );
        }
      }
    }
    final strengthChange = strengthChanges.isEmpty
        ? 0.0
        : strengthChanges.fold<double>(0, (sum, item) => sum + item) /
              strengthChanges.length;
    return WeeklyTrainingReport(
      sessions: current.length,
      durationMinutes: current.fold(
        0,
        (sum, r) => sum + r.durationSeconds ~/ 60,
      ),
      volumeChangePercent: volumeChange,
      strengthChangePercent: strengthChange,
      techniqueChange: techniqueChange,
      bestMuscle: best,
      undertrainedMuscle: under,
      summary: current.isEmpty
          ? '本周还没有完成训练。完成一次训练后，报告会使用真实组数、强度和技术结果更新。'
          : '本周完成 ${current.length} 次训练，训练最充分的是$best；$under相对不足。所有结论来自已保存训练。',
      nextWeekAdvice: under == '暂无'
          ? '继续记录实际重量、次数和 RIR/RPE。'
          : '下周优先为$under增加 4–6 个有效组，并根据恢复状态动态安排。',
      personalRecords: current.expand((record) => record.prs).toSet().toList(),
    );
  }

  String strengthHistoryKey(Exercise exercise, String? gymId) {
    final equipment = exercise.equipment.toLowerCase();
    final standard =
        equipment.contains('杠铃') ||
        equipment.contains('哑铃') ||
        equipment.contains('barbell') ||
        equipment.contains('dumbbell') ||
        equipment.contains('自重');
    return standard || gymId == null ? exercise.id : '${exercise.id}@$gymId';
  }

  double _muscleFactor(Exercise exercise, String muscle) {
    final primary =
        '${exercise.id}|${exercise.name}|${exercise.englishName}|${exercise.muscle}|${exercise.family}'
            .toLowerCase();
    final secondary = exercise.secondary.toLowerCase();
    if (muscle == '上胸') {
      return (primary.contains('上胸') || primary.contains('incline')) ? 1 : 0;
    }
    if (muscle == '中胸') {
      return (primary.contains('胸') ||
                  primary.contains('chest') ||
                  primary.contains('pectoral')) &&
              !primary.contains('上胸') &&
              !primary.contains('incline')
          ? 1
          : 0;
    }
    if (muscle == '前三角') {
      return (primary.contains('前束') ||
              primary.contains('front_raise') ||
              primary.contains('front raise'))
          ? 1
          : 0;
    }
    if (muscle == '中三角') {
      return (primary.contains('侧平举') ||
              primary.contains('lateral_raise') ||
              primary.contains('lateral raise'))
          ? 1
          : 0;
    }
    if (muscle == '后三角') {
      return (primary.contains('后束') ||
              primary.contains('rear_delt') ||
              primary.contains('reverse fly'))
          ? 1
          : 0;
    }
    if (muscle == '三头长头') {
      return (primary.contains('过顶') ||
                  primary.contains('overhead') ||
                  primary.contains('long head')) &&
              (primary.contains('三头') || primary.contains('triceps'))
          ? 1
          : 0;
    }
    final keys = switch (muscle) {
      '胸' => ['胸', 'chest', 'pectoral'],
      '背' => ['背', 'lat', 'back', 'row'],
      '肩' => ['肩', 'deltoid', 'shoulder'],
      '二头' => ['二头', 'biceps'],
      '三头' => ['三头', 'triceps'],
      '股四头' => ['股四', 'quadriceps', 'quads'],
      '腘绳肌' => ['腘绳', 'hamstring'],
      '臀' => ['臀', 'glute'],
      '小腿' => ['小腿', 'calf', 'calves'],
      _ => ['核心', '腹', 'core', 'abs'],
    };
    if (keys.any(primary.contains)) return 1;
    if (keys.any(secondary.contains)) return .45;
    return 0;
  }
}

List<String> _strings(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

int _integer(Object? value) =>
    value is num ? value.round() : int.tryParse('$value') ?? 0;
