import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum MuscleGroup { chest, back, legs, shoulders, arms, core, endurance }

extension MuscleGroupLabel on MuscleGroup {
  String get label => switch (this) {
    MuscleGroup.chest => '胸部',
    MuscleGroup.back => '背部',
    MuscleGroup.legs => '腿部',
    MuscleGroup.shoulders => '肩部',
    MuscleGroup.arms => '手臂',
    MuscleGroup.core => '核心',
    MuscleGroup.endurance => '耐力',
  };
}

class AvatarStyle {
  const AvatarStyle({
    this.base = 'athlete',
    this.skin = 0,
    this.hair = 0,
    this.top = 0,
    this.pants = 0,
    this.shoes = 0,
    this.accessory = 0,
  });

  final String base;
  final int skin;
  final int hair;
  final int top;
  final int pants;
  final int shoes;
  final int accessory;

  AvatarStyle copyWith({
    String? base,
    int? skin,
    int? hair,
    int? top,
    int? pants,
    int? shoes,
    int? accessory,
  }) => AvatarStyle(
    base: base ?? this.base,
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    top: top ?? this.top,
    pants: pants ?? this.pants,
    shoes: shoes ?? this.shoes,
    accessory: accessory ?? this.accessory,
  );

  Map<String, dynamic> toMap() => {
    'base': base,
    'skin': skin,
    'hair': hair,
    'top': top,
    'pants': pants,
    'shoes': shoes,
    'accessory': accessory,
  };

  factory AvatarStyle.fromMap(Map<String, dynamic> map) => AvatarStyle(
    base: (map['base'] ?? 'athlete').toString(),
    skin: (map['skin'] as num?)?.toInt() ?? 0,
    hair: (map['hair'] as num?)?.toInt() ?? 0,
    top: (map['top'] as num?)?.toInt() ?? 0,
    pants: (map['pants'] as num?)?.toInt() ?? 0,
    shoes: (map['shoes'] as num?)?.toInt() ?? 0,
    accessory: (map['accessory'] as num?)?.toInt() ?? 0,
  );
}

class DailyQuestState {
  const DailyQuestState({
    required this.dayKey,
    required this.kind,
    this.done = false,
  });
  final String dayKey;
  final String kind;
  final bool done;

  DailyQuestState copyWith({bool? done}) =>
      DailyQuestState(dayKey: dayKey, kind: kind, done: done ?? this.done);
  Map<String, dynamic> toMap() => {
    'dayKey': dayKey,
    'kind': kind,
    'done': done,
  };
  factory DailyQuestState.fromMap(Map<String, dynamic> map) => DailyQuestState(
    dayKey: (map['dayKey'] ?? '').toString(),
    kind: (map['kind'] ?? '❤️ 形状').toString(),
    done: map['done'] == true,
  );
}

class PlayerProgress {
  const PlayerProgress({
    this.trainingXp = 0,
    this.explorerXp = 0,
    this.socialXp = 0,
    this.sparkCoins = 0,
    this.muscleXp = const {},
    this.avatar = const AvatarStyle(),
    this.processedWorkoutIds = const {},
    this.unlockedCosmetics = const {'余烬训练上衣'},
    this.collections = const {},
    this.quest,
    this.showAtVenue = false,
    this.allowFistBump = true,
    this.allowCheer = true,
    this.venueCode = '',
  });

  final int trainingXp;
  final int explorerXp;
  final int socialXp;
  final int sparkCoins;
  final Map<MuscleGroup, int> muscleXp;
  final AvatarStyle avatar;
  final Set<String> processedWorkoutIds;
  final Set<String> unlockedCosmetics;
  final Set<String> collections;
  final DailyQuestState? quest;
  final bool showAtVenue;
  final bool allowFistBump;
  final bool allowCheer;
  final String venueCode;

  int get trainingLevel => levelForXp(trainingXp);
  int get explorerLevel => levelForXp(explorerXp, base: 70, step: 24);
  int get socialLevel => levelForXp(socialXp, base: 60, step: 20);
  int muscleLevel(MuscleGroup group) =>
      levelForXp(muscleXp[group] ?? 0, base: 45, step: 18);
  int get physiqueStage => (trainingLevel ~/ 8).clamp(0, 5);
  int get levelStartXp => cumulativeXpForLevel(trainingLevel);
  int get nextLevelXp => cumulativeXpForLevel(trainingLevel + 1);
  double get levelProgress =>
      ((trainingXp - levelStartXp) / math.max(1, nextLevelXp - levelStartXp))
          .clamp(0, 1);

  PlayerProgress copyWith({
    int? trainingXp,
    int? explorerXp,
    int? socialXp,
    int? sparkCoins,
    Map<MuscleGroup, int>? muscleXp,
    AvatarStyle? avatar,
    Set<String>? processedWorkoutIds,
    Set<String>? unlockedCosmetics,
    Set<String>? collections,
    DailyQuestState? quest,
    bool? showAtVenue,
    bool? allowFistBump,
    bool? allowCheer,
    String? venueCode,
  }) => PlayerProgress(
    trainingXp: trainingXp ?? this.trainingXp,
    explorerXp: explorerXp ?? this.explorerXp,
    socialXp: socialXp ?? this.socialXp,
    sparkCoins: sparkCoins ?? this.sparkCoins,
    muscleXp: muscleXp ?? this.muscleXp,
    avatar: avatar ?? this.avatar,
    processedWorkoutIds: processedWorkoutIds ?? this.processedWorkoutIds,
    unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
    collections: collections ?? this.collections,
    quest: quest ?? this.quest,
    showAtVenue: showAtVenue ?? this.showAtVenue,
    allowFistBump: allowFistBump ?? this.allowFistBump,
    allowCheer: allowCheer ?? this.allowCheer,
    venueCode: venueCode ?? this.venueCode,
  );

  Map<String, dynamic> toMap() => {
    'trainingXp': trainingXp,
    'explorerXp': explorerXp,
    'socialXp': socialXp,
    'sparkCoins': sparkCoins,
    'muscleXp': {
      for (final entry in muscleXp.entries) entry.key.name: entry.value,
    },
    'avatar': avatar.toMap(),
    'processedWorkoutIds': processedWorkoutIds.toList(),
    'unlockedCosmetics': unlockedCosmetics.toList(),
    'collections': collections.toList(),
    'quest': quest?.toMap(),
    'showAtVenue': showAtVenue,
    'allowFistBump': allowFistBump,
    'allowCheer': allowCheer,
    'venueCode': venueCode,
  };

  factory PlayerProgress.fromMap(Map<String, dynamic> map) {
    final rawMuscles = map['muscleXp'] is Map
        ? Map<String, dynamic>.from(map['muscleXp'] as Map)
        : <String, dynamic>{};
    return PlayerProgress(
      trainingXp: (map['trainingXp'] as num?)?.toInt() ?? 0,
      explorerXp: (map['explorerXp'] as num?)?.toInt() ?? 0,
      socialXp: (map['socialXp'] as num?)?.toInt() ?? 0,
      sparkCoins: (map['sparkCoins'] as num?)?.toInt() ?? 0,
      muscleXp: {
        for (final group in MuscleGroup.values)
          group: (rawMuscles[group.name] as num?)?.toInt() ?? 0,
      },
      avatar: map['avatar'] is Map
          ? AvatarStyle.fromMap(Map<String, dynamic>.from(map['avatar'] as Map))
          : const AvatarStyle(),
      processedWorkoutIds: Set<String>.from(
        map['processedWorkoutIds'] as List? ?? const [],
      ),
      unlockedCosmetics: Set<String>.from(
        map['unlockedCosmetics'] as List? ?? const ['余烬训练上衣'],
      ),
      collections: Set<String>.from(map['collections'] as List? ?? const []),
      quest: map['quest'] is Map
          ? DailyQuestState.fromMap(
              Map<String, dynamic>.from(map['quest'] as Map),
            )
          : null,
      showAtVenue: map['showAtVenue'] == true,
      allowFistBump: map['allowFistBump'] != false,
      allowCheer: map['allowCheer'] != false,
      venueCode: (map['venueCode'] ?? '').toString(),
    );
  }
}

class MuscleContribution {
  const MuscleContribution({
    required this.primary,
    this.secondary,
    this.allowsZeroWeight = false,
  });
  final MuscleGroup primary;
  final MuscleGroup? secondary;
  final bool allowsZeroWeight;
}

class WorkoutGameSettlement {
  const WorkoutGameSettlement({
    required this.workoutId,
    required this.xp,
    required this.performanceScore,
    required this.muscleXp,
    required this.previousLevel,
    required this.currentLevel,
    required this.prCount,
    required this.coins,
    this.reward,
    this.duplicate = false,
  });
  final String workoutId;
  final int xp;
  final int performanceScore;
  final Map<MuscleGroup, int> muscleXp;
  final int previousLevel;
  final int currentLevel;
  final int prCount;
  final int coins;
  final String? reward;
  final bool duplicate;
  bool get leveledUp => currentLevel > previousLevel;
}

class GamificationResult {
  const GamificationResult(this.progress, this.settlement);
  final PlayerProgress progress;
  final WorkoutGameSettlement settlement;
}

typedef MuscleResolver = MuscleContribution Function(String exerciseId);

class GamificationEngine {
  static GamificationResult settle({
    required PlayerProgress progress,
    required WorkoutRecord record,
    required List<WorkoutRecord> history,
    required MuscleResolver resolveMuscles,
  }) {
    if (progress.processedWorkoutIds.contains(record.id)) {
      return GamificationResult(
        progress,
        WorkoutGameSettlement(
          workoutId: record.id,
          xp: 0,
          performanceScore: 0,
          muscleXp: const {},
          previousLevel: progress.trainingLevel,
          currentLevel: progress.trainingLevel,
          prCount: 0,
          coins: 0,
          duplicate: true,
        ),
      );
    }

    bool validSet(WorkoutExercise exercise, WorkoutSet set) {
      final allowsZeroWeight = resolveMuscles(
        exercise.exerciseId,
      ).allowsZeroWeight;
      return set.completed &&
          !set.failed &&
          set.reps > 0 &&
          (set.weight > 0 || allowsZeroWeight);
    }

    final validSets = [
      for (final exercise in record.exercises)
        ...exercise.sets.where((set) => validSet(exercise, set)),
    ];
    if (validSets.isEmpty) {
      final next = progress.copyWith(
        processedWorkoutIds: {...progress.processedWorkoutIds, record.id},
      );
      return GamificationResult(
        next,
        WorkoutGameSettlement(
          workoutId: record.id,
          xp: 0,
          performanceScore: 0,
          muscleXp: const {},
          previousLevel: progress.trainingLevel,
          currentLevel: progress.trainingLevel,
          prCount: 0,
          coins: 0,
        ),
      );
    }
    final baseXp = math.min(36, validSets.length * 3);
    var improvementXp = 0;
    for (final exercise in record.exercises) {
      final current = _bestE1rm(exercise.sets);
      if (current <= 0) continue;
      final previous = history
          .expand((item) => item.exercises)
          .where((item) => item.exerciseId == exercise.exerciseId)
          .map((item) => _bestE1rm(item.sets))
          .fold<double>(0, math.max);
      if (previous <= 0) {
        improvementXp += 8;
      } else if (current > previous) {
        final ratio = ((current - previous) / previous).clamp(0, .15);
        improvementXp += 16 + (ratio * 220).round();
      }
    }
    final prXp = math.min(72, record.prs.length * 24);
    final planned = record.exercises
        .expand((item) => item.sets)
        .where((set) => set.plannedWeight != null)
        .length;
    final plannedDone = record.exercises
        .expand((item) => item.sets)
        .where(
          (set) =>
              set.plannedWeight != null &&
              set.completed &&
              !set.failed &&
              set.reps > 0,
        )
        .length;
    final planXp = planned == 0 ? 0 : (24 * plannedDone / planned).round();
    final recentWeeks = history
        .where((item) => record.date.difference(item.date).inDays.abs() <= 28)
        .map((item) => '${item.date.year}-${_weekOfYear(item.date)}')
        .toSet()
        .length;
    final consistencyXp = math.min(18, recentWeeks * 5);
    final total = math.max(
      0,
      baseXp + improvementXp + prXp + planXp + consistencyXp,
    );
    final performanceScore =
        (48 + improvementXp * .55 + prXp * .35 + planXp * .4).round().clamp(
          0,
          100,
        );

    final muscleAwards = <MuscleGroup, int>{};
    for (final exercise in record.exercises) {
      final contribution = resolveMuscles(exercise.exerciseId);
      final exerciseSets = exercise.sets
          .where((set) => validSet(exercise, set))
          .length;
      if (exerciseSets == 0) continue;
      final share = math.max(
        3,
        (total * exerciseSets / math.max(1, validSets.length)).round(),
      );
      muscleAwards.update(
        contribution.primary,
        (value) => value + (share * .7).round(),
        ifAbsent: () => (share * .7).round(),
      );
      final secondary = contribution.secondary;
      if (secondary != null) {
        muscleAwards.update(
          secondary,
          (value) => value + (share * .3).round(),
          ifAbsent: () => (share * .3).round(),
        );
      }
    }

    final oldLevel = progress.trainingLevel;
    final nextXp = progress.trainingXp + total;
    final newLevel = levelForXp(nextXp);
    final coins = math.max(4, total ~/ 6) + record.prs.length * 3;
    String? reward;
    final unlocked = {...progress.unlockedCosmetics};
    if (newLevel > oldLevel && newLevel % 5 == 0) {
      reward = '等级 $newLevel 训练配色';
      unlocked.add(reward);
    }
    final nextMuscles = {...progress.muscleXp};
    for (final award in muscleAwards.entries) {
      nextMuscles.update(
        award.key,
        (value) => value + award.value,
        ifAbsent: () => award.value,
      );
    }
    final next = progress.copyWith(
      trainingXp: nextXp,
      sparkCoins: progress.sparkCoins + coins,
      muscleXp: nextMuscles,
      processedWorkoutIds: {...progress.processedWorkoutIds, record.id},
      unlockedCosmetics: unlocked,
    );
    return GamificationResult(
      next,
      WorkoutGameSettlement(
        workoutId: record.id,
        xp: total,
        performanceScore: performanceScore,
        muscleXp: muscleAwards,
        previousLevel: oldLevel,
        currentLevel: newLevel,
        prCount: record.prs.length,
        coins: coins,
        reward: reward,
      ),
    );
  }

  static double _bestE1rm(Iterable<WorkoutSet> sets) => sets
      .where(
        (set) => set.completed && !set.failed && set.weight > 0 && set.reps > 0,
      )
      .map((set) => set.weight * (1 + set.reps / 30))
      .fold<double>(0, math.max);

  static int _weekOfYear(DateTime date) =>
      ((date.difference(DateTime(date.year, 1, 1)).inDays +
                  DateTime(date.year, 1, 1).weekday) /
              7)
          .ceil();
}

int cumulativeXpForLevel(int level, {int base = 100, int step = 35}) {
  if (level <= 1) return 0;
  final n = level - 1;
  return n * base + (n * (n - 1) ~/ 2) * step;
}

int levelForXp(int xp, {int base = 100, int step = 35}) {
  var level = 1;
  while (level < 100 &&
      xp >= cumulativeXpForLevel(level + 1, base: base, step: step)) {
    level++;
  }
  return level;
}

DailyQuestState questForDay(DateTime now) {
  final dayKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  const kinds = ['❤️ 形状', '圆形', '三角形', '对称图案', '橙色物体', '有力量感的线条'];
  final seed = now.year * 400 + now.month * 31 + now.day;
  return DailyQuestState(dayKey: dayKey, kind: kinds[seed % kinds.length]);
}

abstract class GamificationPersistence {
  Future<PlayerProgress> read(String userId);
  Future<void> write(String userId, PlayerProgress progress);
}

class SharedPreferencesGamificationPersistence
    implements GamificationPersistence {
  static String _key(String userId) => 'xingyu.gamification.v1.$userId';
  @override
  Future<PlayerProgress> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const PlayerProgress();
    try {
      return PlayerProgress.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PlayerProgress();
    }
  }

  @override
  Future<void> write(String userId, PlayerProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), jsonEncode(progress.toMap()));
  }
}
