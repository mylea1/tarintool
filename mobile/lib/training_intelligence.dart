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
    List<Routine> officialRoutines = const [],
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
        officialRoutines: officialRoutines,
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
    List<Routine> officialRoutines = const [],
    required List<MuscleRecovery> recovery,
    required List<MuscleVolume> volume,
    required TrainingProfile profile,
    String? preferredRoutineName,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final hasData =
        TrainingKnowledgeRules.hasCompletedSet(history) ||
        profile.hasRecommendationBaseline;
    final exerciseMap = {for (final e in exercises) e.id: e};
    final recoveryMap = {for (final r in recovery) r.muscle: r.percent};
    final recent = _recentMuscles(history, exerciseMap, now: clock);
    Set<String> expand(List<String> values) => values
        .expand(
          (v) => switch (v) {
            '腿' || '腿部' => ['股四头', '腘绳肌', '臀', '小腿'],
            '手臂' => ['二头', '三头'],
            _ => [v.replaceAll('部', '')],
          },
        )
        .toSet();
    final excluded = expand(profile.excludedMuscles);
    final focus = expand(profile.focusMuscles).difference(excluded);
    final reduced = expand(profile.reducedMuscles);
    final requiredCoverage = <String>{
      '胸',
      '背',
      '肩',
      '股四头',
      ...focus,
    }.difference(excluded);
    final blockedExercises = {
      ...profile.dislikedExerciseIds,
      ...profile.unavailableExerciseIds,
    };
    bool allowed(Routine r) {
      if (r.exercises.isEmpty ||
          r.exercises.any(
            (e) =>
                !exerciseMap.containsKey(e.exerciseId) ||
                blockedExercises.contains(e.exerciseId),
          )) {
        return false;
      }
      final groups = _routineMuscles(r, exerciseMap);
      return groups.isNotEmpty && groups.intersection(excluded).isEmpty;
    }

    final personal = routines
        .where((r) => r.folder != '官方计划' && allowed(r))
        .toList();
    final official = <String, Routine>{
      for (final r in officialRoutines.where(allowed)) r.id: r,
      for (final r in routines.where((r) => r.folder == '官方计划' && allowed(r)))
        r.id: r,
    }.values.toList();
    final coverage = personal
        .expand((r) => _routineMuscles(r, exerciseMap))
        .toSet();
    String coverageGroup(String muscle) =>
        {'股四头', '腘绳肌', '臀', '小腿'}.contains(muscle) ? '腿' : muscle;
    final personalReady =
        requiredCoverage.isNotEmpty &&
        coverage
            .map(coverageGroup)
            .toSet()
            .containsAll(requiredCoverage.map(coverageGroup));
    bool ready(Routine r) => _routineMuscles(r, exerciseMap).every(
      (m) =>
          (recoveryMap[m] ?? 100) >=
          TrainingKnowledgeRules.minimumRecoveryForPrimary,
    );
    List<Routine> ranked(List<Routine> source) {
      var pool = source.where(ready).toList();
      final fresh = pool
          .where(
            (r) => !_routineMuscles(
              r,
              exerciseMap,
            ).any((m) => _isRecent(recent[m], clock)),
          )
          .toList();
      if (fresh.isNotEmpty) pool = fresh;
      double score(Routine r) {
        final groups = _routineMuscles(r, exerciseMap);
        final average =
            groups.fold<double>(0, (n, m) => n + (recoveryMap[m] ?? 100)) /
            groups.length;
        final weekly = groups.fold<double>(
          0,
          (n, m) =>
              n +
              (volume.where((v) => v.muscle == m).firstOrNull?.effectiveSets ??
                  0),
        );
        final minutes =
            r.exercises.fold<int>(0, (n, e) => n + e.sets.length) * 3 +
            r.exercises.length * 2;
        return average +
            groups.intersection(focus).length * 12 -
            groups.intersection(reduced).length * 25 -
            weekly / groups.length -
            (minutes - profile.sessionMinutes).abs() * .3;
      }

      pool.sort((a, b) {
        final result = score(b).compareTo(score(a));
        return result != 0 ? result : a.id.compareTo(b.id);
      });
      return pool;
    }

    final primary = ranked(personalReady ? personal : official);
    final fallback = ranked(personalReady ? official : personal);
    // Incomplete personal libraries are never used as an automatic fallback.
    final candidates = primary.isNotEmpty
        ? primary
        : personalReady
        ? fallback
        : <Routine>[];
    final freshAvailable = [...personal, ...official]
        .where(ready)
        .any(
          (r) => !_routineMuscles(
            r,
            exerciseMap,
          ).any((m) => _isRecent(recent[m], clock)),
        );
    final manual = [...personal, ...official]
        .where(
          (r) =>
              r.name == preferredRoutineName &&
              ready(r) &&
              (!freshAvailable ||
                  !_routineMuscles(
                    r,
                    exerciseMap,
                  ).any((m) => _isRecent(recent[m], clock))),
        )
        .firstOrNull;
    final restDay =
        profile.preferredWeekdays.isNotEmpty &&
        !profile.preferredWeekdays.contains(clock.weekday);
    final best = manual ?? (restDay ? null : candidates.firstOrNull);
    if (best == null) {
      return DailyTrainingRecommendation(
        title: restDay
            ? '今天是休息日'
            : !hasData && official.isEmpty
            ? '暂无训练数据'
            : '暂无合适的训练计划',
        muscles: const [],
        reason: restDay
            ? '按你的训练日期偏好安排休息；也可以手动选择训练。'
            : !personalReady && official.isEmpty
            ? '个人计划尚未覆盖训练偏好，等待可用的官方计划；你仍可手动选择计划。'
            : '当前计划未满足部位偏好或恢复条件，可先恢复或手动选择训练。',
        estimatedMinutes: 0,
        exerciseCount: 0,
        hasTrainingData: hasData,
      );
    }
    final groups = _routineMuscles(best, exerciseMap).toList();
    return DailyTrainingRecommendation(
      title: best.name,
      muscles: groups,
      reason:
          '${history.isEmpty ? '依据训练偏好提供首份建议；' : ''}${best.folder == '官方计划' ? '从官方计划中选择' : '从个人计划中选择'}，按实际动作匹配部位，已排除不想训练的部位；'
          '${groups.map((m) => '$m恢复估算 ${recoveryMap[m] ?? 100}%').join('，')}。',
      estimatedMinutes:
          (best.exercises.fold<int>(0, (n, e) => n + e.sets.length) * 3 +
                  best.exercises.length * 2)
              .clamp(10, 180),
      exerciseCount: best.exercises.length,
      routineId: best.id,
      hasTrainingData: hasData,
    );
  }

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
          if (!_primaryMuscles(definition).contains(muscle)) continue;
          final previous = result[muscle];
          if (previous == null || record.date.isAfter(previous)) {
            result[muscle] = record.date;
          }
        }
      }
    }
    return result;
  }

  Set<String> _primaryMuscles(Exercise exercise) {
    // Use catalog anatomy fields, never the routine/exercise marketing title.
    final tags = '${exercise.muscle}|${exercise.family}'.toLowerCase();
    final result = <String>{};
    const aliases = <String, List<String>>{
      '胸': ['胸', 'chest', 'pectoral'],
      '背': ['背', 'back', 'latissimus'],
      '肩': ['肩', '三角', 'shoulder', 'deltoid'],
      '二头': ['二头', 'biceps'],
      '三头': ['三头', 'triceps'],
      '股四头': ['股四头', 'quadriceps'],
      '腘绳肌': ['腘绳', 'hamstring'],
      '臀': ['臀', 'glute'],
      '小腿': ['小腿', 'calf', 'calves'],
      '核心': ['核心', '腹', 'core', 'abdominal'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any(tags.contains)) result.add(entry.key);
    }
    if (result.intersection({'股四头', '腘绳肌', '臀', '小腿'}).isEmpty &&
        (tags.contains('腿') || tags.contains('leg'))) {
      result.add('股四头');
    }
    return result;
  }

  Set<String> _routineMuscles(
    Routine routine,
    Map<String, Exercise> exerciseMap,
  ) => routine.exercises
      .map((item) => exerciseMap[item.exerciseId])
      .whereType<Exercise>()
      .expand(_primaryMuscles)
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
