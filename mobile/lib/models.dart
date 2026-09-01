import 'package:flutter/foundation.dart';

import 'exercise_dataset.generated.dart';
import 'exercise_retirement_candidates.generated.dart';
import 'exercise_retirement_overrides.dart';
import 'exercise_name_zh.dart';
import 'exercise_media.dart';

enum PageId { today, train, records, exercises, recognition, ai, profile }

enum TrainView { workout, plans, history }

enum AiView { chat, recognition }

/// User-selectable light palettes. `warm` remains the compatibility default
/// for existing installs; new surfaces read semantic Material color tokens so
/// switching to glacier, forest or titanium updates them consistently.
enum KiloThemeChoice { warm, glacier, forest, titanium }

@immutable
class AiSkill {
  const AiSkill({
    required this.id,
    required this.name,
    required this.instructions,
    this.enabled = false,
  });

  final String id;
  final String name;
  final String instructions;
  final bool enabled;

  AiSkill copyWith({String? name, String? instructions, bool? enabled}) =>
      AiSkill(
        id: id,
        name: name ?? this.name,
        instructions: instructions ?? this.instructions,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'instructions': instructions,
    'enabled': enabled,
  };

  factory AiSkill.fromJson(Map<String, dynamic> json) => AiSkill(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    instructions: json['instructions']?.toString() ?? '',
    enabled: json['enabled'] == true,
  );
}

enum RecognitionStatus {
  idle,
  ready,
  processing,
  complete,
  lowConfidence,
  offline,
  error,
}

enum RecognitionStage { idle, preparing, uploading, queued, analyzing }

@immutable
class RecognitionProgressUpdate {
  const RecognitionProgressUpdate({
    required this.stage,
    this.fraction,
    this.sentBytes,
    this.totalBytes,
  });

  final RecognitionStage stage;
  final double? fraction;
  final int? sentBytes;
  final int? totalBytes;
}

@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.englishName,
    required this.family,
    required this.muscle,
    required this.secondary,
    required this.equipment,
    required this.camera,
    required this.cue,
    this.loadMode = 'total',
  });
  final String id;
  final String name;
  final String englishName;
  final String family;
  final String muscle;
  final String secondary;
  final String equipment;
  final String camera;
  final String cue;
  final String loadMode;
}

@immutable
class RecognitionCameraOption {
  const RecognitionCameraOption({
    required this.id,
    required this.label,
    required this.hint,
  });

  final String id;
  final String label;
  final String hint;
}

@immutable
class RecognitionCapability {
  const RecognitionCapability({
    required this.exerciseId,
    required this.cameras,
    this.group = '其他',
  });

  final String exerciseId;
  final List<RecognitionCameraOption> cameras;
  final String group;
}

const _baseFallbackRecognitionCapabilities = <RecognitionCapability>[
  RecognitionCapability(
    exerciseId: 'barbell_squat',
    group: '腿部',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '镜头与髋部同高，完整拍到头、髋、膝和脚。',
      ),
      RecognitionCameraOption(
        id: 'side_rear',
        label: '侧后方',
        hint: '从侧后方完整拍到双脚与杠铃，便于观察膝髋轨迹。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'hip_thrust',
    group: '臀腿',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '镜头与髋部同高，完整拍到肩、髋和膝，避免器械遮挡。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'romanian_deadlift',
    group: '臀腿',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '完整拍到头、肩、髋、膝和脚，镜头保持水平。',
      ),
      RecognitionCameraOption(
        id: 'side_rear',
        label: '侧后方',
        hint: '侧后方约 30° 拍摄，确保杠铃与下肢轨迹无遮挡。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'lat_pulldown',
    group: '背部',
    cameras: [
      RecognitionCameraOption(
        id: 'rear',
        label: '正后方',
        hint: '镜头正对座椅后方，完整拍到双臂、肩胛和躯干。',
      ),
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '镜头与肩部同高，完整拍到手、肩、髋与下拉轨迹。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'goblet_squat',
    group: '腿部',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '拍全头、髋、膝与双脚，镜头保持水平。',
      ),
      RecognitionCameraOption(
        id: 'side_rear',
        label: '侧后方',
        hint: '从侧后方约 30° 拍摄，保留双脚与膝髋轨迹。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'deadlift',
    group: '臀腿',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '完整拍到杠铃、肩、髋、膝和脚。',
      ),
      RecognitionCameraOption(
        id: 'side_rear',
        label: '侧后方',
        hint: '侧后方约 30° 拍摄，确保杠铃无遮挡。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'bench_press',
    group: '胸部',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '完整拍到杠铃、肩肘、躯干和双脚。',
      ),
      RecognitionCameraOption(
        id: 'side_front',
        label: '侧前方',
        hint: '从侧前方约 30° 拍摄，避免器械遮住手肘。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'dumbbell_press',
    group: '胸部',
    cameras: [
      RecognitionCameraOption(id: 'side', label: '正侧面', hint: '拍全哑铃、肩肘、躯干和双脚。'),
      RecognitionCameraOption(
        id: 'side_front',
        label: '侧前方',
        hint: '侧前方拍摄，确保两侧哑铃都可见。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'shoulder_press',
    group: '肩部',
    cameras: [
      RecognitionCameraOption(id: 'front', label: '正前方', hint: '拍全双手、肩、肘和躯干。'),
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '侧面拍摄，观察躯干与手臂轨迹。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'push_up',
    group: '胸部',
    cameras: [
      RecognitionCameraOption(id: 'side', label: '正侧面', hint: '完整拍到头、肩、髋、膝和脚。'),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'dip',
    group: '胸部',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '拍全头、肩肘、髋与双脚，避免器械遮挡。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'row',
    group: '背部',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '拍到手、肩、髋和器械完整运动轨迹。',
      ),
      RecognitionCameraOption(
        id: 'rear',
        label: '正后方',
        hint: '后方拍摄，观察肩胛与双臂对称性。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'pull_up',
    group: '背部',
    cameras: [
      RecognitionCameraOption(
        id: 'front',
        label: '正前方',
        hint: '从正前方拍全单杠、双手和身体。',
      ),
      RecognitionCameraOption(id: 'side', label: '正侧面', hint: '侧面拍全身体，避免脚部出画。'),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'face_pull',
    group: '肩背',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '侧面拍到绳索、手肘、肩和躯干。',
      ),
      RecognitionCameraOption(
        id: 'front',
        label: '正前方',
        hint: '正面观察双臂轨迹与肩胛对称性。',
      ),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'lateral_raise',
    group: '肩部',
    cameras: [
      RecognitionCameraOption(id: 'front', label: '正前方', hint: '拍全双手、肩、髋和双脚。'),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'biceps_curl',
    group: '手臂',
    cameras: [
      RecognitionCameraOption(id: 'side', label: '正侧面', hint: '拍全肩、肘、手和躯干。'),
      RecognitionCameraOption(id: 'front', label: '正前方', hint: '正面观察两侧手臂是否对称。'),
    ],
  ),
  RecognitionCapability(
    exerciseId: 'triceps_extension',
    group: '手臂',
    cameras: [
      RecognitionCameraOption(
        id: 'side',
        label: '正侧面',
        hint: '侧面拍到肩、肘、手与器械轨迹。',
      ),
    ],
  ),
];

const recognitionExerciseNames = <String, String>{
  'leg_press': '45°腿举',
  'leg_extension': '坐姿腿屈伸',
  'leg_curl': '腿弯举',
  'bulgarian_split_squat': '保加利亚分腿蹲',
  'barbell_row': '杠铃俯身划船',
  'yates_row': '耶茨划船',
  't_bar_row': 'T杠划船',
  'chest_supported_row': '胸支撑划船',
  'landmine_one_arm_row': '单臂地雷划船',
  'half_kneeling_one_arm_row': '半跪单臂划船',
  'standing_one_arm_cable_row': '站姿单臂绳索划船',
  'upright_row': '直立划船',
  'one_arm_dumbbell_row': '单臂哑铃划船',
  'inverted_row': '澳式划船',
  'single_arm_pulldown': '单臂高位下拉',
  'straight_arm_pulldown': '直臂下压',
  'underhand_pulldown': '反手高位下拉',
  'chest_supported_pulldown': '胸支撑下拉',
  'incline_bench_press': '上斜杠铃卧推',
  'decline_bench_press': '下斜杠铃卧推',
  'close_grip_bench_press': '窄握卧推',
  'wide_grip_bench_press': '宽握卧推',
  'barbell_floor_press': '杠铃地板卧推',
  'machine_shoulder_press': '器械肩推',
  'machine_chest_press': '器械推胸',
  'single_arm_overhead_press': '单臂肩上推举',
  'push_press': '借力推举',
  'alternate_dumbbell_press': '交替哑铃卧推',
  'diamond_push_up': '钻石俯卧撑',
  'dumbbell_fly': '哑铃飞鸟',
  'cable_fly': '绳索夹胸',
  'low_to_high_cable_fly': '低位绳索夹胸',
  'standing_one_arm_cable_fly': '站姿单臂绳索夹胸',
  'pec_deck_fly': '蝴蝶机夹胸',
  'reverse_fly': '俯卧反向飞鸟',
  'side_lying_lateral_raise': '侧卧侧平举',
  'dumbbell_front_raise': '哑铃前平举',
  'lean_away_lateral_raise': '倾身绳索侧平举',
  'bent_over_reverse_fly': '俯身哑铃反向飞鸟',
  'cable_reverse_fly': '绳索反向飞鸟',
  'machine_reverse_fly': '器械反向飞鸟',
  'rear_delt_row': '宽肘后束划船',
  'prone_y_raise': '俯卧Y字上举',
  'dumbbell_pullover': '哑铃仰卧上拉',
  'pike_push_up': '派克俯卧撑',
  'back_extension': '山羊挺身',
  'landmine_press': '半跪地雷推举',
  'incline_dumbbell_press': '上斜哑铃卧推',
  'decline_dumbbell_press': '下斜哑铃卧推',
};

const _sideOnlyRecognitionExercises = <String>{
  'leg_press',
  'leg_extension',
  'leg_curl',
  'incline_bench_press',
  'decline_bench_press',
  'barbell_floor_press',
  'alternate_dumbbell_press',
  'side_lying_lateral_raise',
  'dumbbell_front_raise',
  'prone_y_raise',
  'dumbbell_pullover',
  'pike_push_up',
  'back_extension',
  'landmine_press',
  'incline_dumbbell_press',
  'decline_dumbbell_press',
};

const _genericSideRecognitionCameras = <RecognitionCameraOption>[
  RecognitionCameraOption(
    id: 'side',
    label: '正侧面',
    hint: '镜头保持水平，完整拍到动作使用的肩、肘、腕、髋、膝和脚踝。',
  ),
  RecognitionCameraOption(
    id: 'side_front',
    label: '侧前方',
    hint: '从侧前方约 30° 拍摄，尽量避免器械遮挡四肢。',
  ),
  RecognitionCameraOption(
    id: 'side_rear',
    label: '侧后方',
    hint: '从侧后方约 30° 拍摄，完整保留身体和器械轨迹。',
  ),
];

const _genericAllRecognitionCameras = <RecognitionCameraOption>[
  ..._genericSideRecognitionCameras,
  RecognitionCameraOption(
    id: 'front',
    label: '正前方',
    hint: '镜头正对身体，完整拍到左右两侧关节。',
  ),
  RecognitionCameraOption(
    id: 'rear',
    label: '正后方',
    hint: '镜头正对身体后方，完整拍到双肩、双臂和下肢。',
  ),
];

final List<RecognitionCapability> fallbackRecognitionCapabilities =
    List<RecognitionCapability>.unmodifiable([
      ..._baseFallbackRecognitionCapabilities,
      for (final entry in recognitionExerciseNames.entries)
        RecognitionCapability(
          exerciseId: entry.key,
          group: _recognitionGroupForId(entry.key),
          cameras: _sideOnlyRecognitionExercises.contains(entry.key)
              ? _genericSideRecognitionCameras
              : _genericAllRecognitionCameras,
        ),
    ]);

String _recognitionGroupForId(String id) {
  if (id.contains('leg') || id.contains('squat') || id == 'back_extension') {
    return '腿部';
  }
  if (id.contains('press') || id.contains('push_up') || id.contains('fly')) {
    return id.contains('shoulder') || id == 'push_press' ? '肩部' : '胸部';
  }
  if (id.contains('raise') || id == 'upright_row') return '肩部';
  return '背部';
}

Exercise recognitionExerciseDefinition(String id, String group) => Exercise(
  id: id,
  name: recognitionExerciseNames[id] ?? id.replaceAll('_', ' '),
  englishName: id.replaceAll('_', ' '),
  family: group,
  muscle: group,
  secondary: '稳定肌群',
  equipment: '按动作要求',
  camera: '按识别页机位提示拍摄',
  cue: '保持主体完整入镜，并用可控节奏完成一次完整动作。',
);

class WorkoutSet {
  WorkoutSet({
    required this.id,
    this.type = 'work',
    this.weight = 80,
    this.plannedWeight,
    this.reps = 8,
    this.targetMin = 6,
    this.targetMax = 8,
    // A live/free-training set has no implicit rest. Prescribed plans and
    // restored legacy records can still pass an explicit positive value.
    this.restSeconds = 0,
    this.completed = false,
    this.failed = false,
    this.rpe,
    this.rir,
    this.note = '',
    this.durationSeconds,
  });
  final String id;
  String type;

  /// The weight prescribed by the plan, when the source plan recorded one.
  ///
  /// This stays nullable so legacy records can explicitly report that their
  /// planned weight was not stored. Callers that need a compatibility value
  /// can use [plannedWeightOrActual], while history/progress surfaces should
  /// inspect this field first and avoid inventing a planned value.
  double? plannedWeight;
  double weight;
  int reps;
  int targetMin;
  int targetMax;
  int restSeconds;
  bool completed;
  bool failed;

  /// User-reported effort. RPE is 1-10; RIR is 0-5. Both remain nullable so
  /// legacy records are never treated as if effort had been measured.
  double? rpe;
  double? rir;
  String note;
  int? durationSeconds;

  double get plannedWeightOrActual => plannedWeight ?? weight;

  WorkoutSet copy({bool normalizePlannedWeight = false}) => WorkoutSet(
    id: id,
    type: type,
    weight: weight,
    plannedWeight: normalizePlannedWeight
        ? plannedWeight ?? weight
        : plannedWeight,
    reps: reps,
    targetMin: targetMin,
    targetMax: targetMax,
    restSeconds: restSeconds,
    completed: completed,
    failed: failed,
    rpe: rpe,
    rir: rir,
    note: note,
    durationSeconds: durationSeconds,
  );

  /// Copies a set into a persisted plan. A plan created from a legacy live
  /// workout has no separate planned value, so its current weight becomes the
  /// initial prescribed value at this boundary.
  WorkoutSet copyForPlan() => copy(normalizePlannedWeight: true);

  /// Copies a plan set into a live workout. The user may then edit [weight]
  /// without changing [plannedWeight].
  WorkoutSet copyForWorkout() => WorkoutSet(
    id: id,
    type: type,
    weight: plannedWeight ?? weight,
    plannedWeight: plannedWeight,
    reps: reps,
    targetMin: targetMin,
    targetMax: targetMax,
    restSeconds: restSeconds,
    completed: completed,
    failed: failed,
    rpe: rpe,
    rir: rir,
    note: note,
    durationSeconds: durationSeconds,
  );
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    // Rest is deliberately unset until the athlete chooses it for a live
    // session. Plan snapshots may provide their own positive value.
    this.restSeconds = 0,
    this.note = '',
    this.collapsed = false,
    this.supersetId,
  });
  final String id;
  String exerciseId;
  final List<WorkoutSet> sets;
  int restSeconds;
  String note;
  bool collapsed;
  String? supersetId;

  WorkoutExercise copy({String? newId, bool normalizePlannedWeight = false}) =>
      WorkoutExercise(
        id: newId ?? id,
        exerciseId: exerciseId,
        sets: sets
            .map(
              (set) => set.copy(normalizePlannedWeight: normalizePlannedWeight),
            )
            .toList(),
        restSeconds: restSeconds,
        note: note,
        collapsed: collapsed,
        supersetId: supersetId,
      );

  WorkoutExercise copyForPlan({String? newId}) =>
      copy(newId: newId, normalizePlannedWeight: true);

  WorkoutExercise copyForWorkout({String? newId}) => WorkoutExercise(
    id: newId ?? id,
    exerciseId: exerciseId,
    sets: sets.map((set) => set.copyForWorkout()).toList(),
    restSeconds: restSeconds,
    note: note,
    collapsed: collapsed,
    supersetId: supersetId,
  );
}

class WorkoutRecord {
  WorkoutRecord({
    required this.id,
    required this.name,
    required this.date,
    required this.startTime,
    required this.durationSeconds,
    required this.volume,
    required this.effectiveSets,
    this.note = '',
    required this.exerciseIds,
    this.prs = const [],
    this.prDetails = const [],
    this.exercises = const [],
    this.gymId,
  });
  final String id;
  final String name;
  final DateTime date;
  final String startTime;
  final int durationSeconds;
  final double volume;
  final int effectiveSets;
  final String note;
  final List<String> exerciseIds;
  final List<String> prs;
  final List<WorkoutPrDetail> prDetails;

  /// A snapshot of the exercises and sets performed in this record.
  /// Older records may omit it and fall back to [exerciseIds].
  final List<WorkoutExercise> exercises;
  final String? gymId;
}

/// A personal record proven against this user's earlier records for the same
/// exercise. First-time exercise entries are deliberately not labelled PRs.
class WorkoutPrDetail {
  const WorkoutPrDetail({
    required this.exerciseId,
    required this.metric,
    required this.currentValue,
    required this.previousValue,
    required this.previousRecordId,
    required this.previousDate,
  });

  final String exerciseId;

  /// `estimated1rm`, `weight`, `reps` or `volume`.
  final String metric;
  final double currentValue;
  final double previousValue;
  final String previousRecordId;
  final DateTime previousDate;
}

/// A compact comparison between the finished session and its most relevant
/// previous baseline. Kept as a model so the summary UI and future exports
/// use the same comparison semantics.
class WorkoutComparison {
  const WorkoutComparison({
    required this.baseline,
    required this.volumeDelta,
    required this.effectiveSetsDelta,
    required this.durationDelta,
    required this.exerciseProgress,
  });

  final WorkoutRecord baseline;
  final double volumeDelta;
  final int effectiveSetsDelta;
  final int durationDelta;
  final List<WorkoutExerciseProgress> exerciseProgress;
}

class WorkoutExerciseProgress {
  const WorkoutExerciseProgress({
    required this.exerciseId,
    required this.weightDelta,
    required this.repsDelta,
    required this.currentWeight,
    required this.previousWeight,
    required this.currentReps,
    required this.previousReps,
  });

  final String exerciseId;
  final double weightDelta;
  final int repsDelta;
  final double currentWeight;
  final double previousWeight;
  final int currentReps;
  final int previousReps;
}

class Routine {
  Routine({
    required this.id,
    required this.name,
    required this.folder,
    required this.exercises,
    required this.updatedAt,
  });
  final String id;
  String name;
  String folder;
  List<WorkoutExercise> exercises;
  DateTime updatedAt;
}

enum AiContextType { activeWorkout, workoutRecord, routine, week, month }

class AiContextSelection {
  const AiContextSelection({
    required this.type,
    required this.id,
    required this.label,
  });

  final AiContextType type;
  final String id;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is AiContextSelection && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.days,
    required this.weeks,
    required this.level,
    required this.focus,
    required this.sessions,
  });
  final String id;
  final String title;
  final String subtitle;
  final int days;
  final int weeks;
  final String level;
  final String focus;
  final List<PlanSession> sessions;
}

class PlanSession {
  const PlanSession({
    required this.day,
    required this.name,
    required this.exercises,
    required this.duration,
    required this.exerciseIds,
  });
  final String day;
  final String name;
  final int exercises;
  final String duration;
  final List<String> exerciseIds;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.body,
    this.citations = const [],
    this.plan,
  });
  final String id;
  final String role;
  String body;
  List<String> citations;
  AiPlanDraft? plan;
}

class AiPlanDraft {
  const AiPlanDraft({
    required this.title,
    required this.weeks,
    required this.sessions,
  });

  final String title;
  final int weeks;
  final List<AiPlanSession> sessions;
}

class AiPlanSession {
  const AiPlanSession({
    required this.dayOffset,
    required this.name,
    required this.exerciseIds,
    this.exercises = const [],
  });

  final int dayOffset;
  final String name;
  final List<String> exerciseIds;
  final List<AiPlanExerciseDraft> exercises;

  List<String> get effectiveExerciseIds => exercises.isEmpty
      ? exerciseIds
      : exercises.map((exercise) => exercise.exerciseId).toList();

  int get totalSets =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);

  double get plannedVolume =>
      exercises.fold(0, (total, exercise) => total + exercise.plannedVolume);
}

class AiPlanExerciseDraft {
  const AiPlanExerciseDraft({
    required this.exerciseId,
    required this.sets,
    this.note = '',
  });

  final String exerciseId;
  final List<AiPlanSetDraft> sets;
  final String note;

  double get plannedVolume =>
      sets.fold(0, (total, set) => total + set.weight * set.reps);
}

class AiPlanSetDraft {
  const AiPlanSetDraft({
    required this.type,
    required this.weight,
    required this.reps,
    required this.restSeconds,
  });

  final String type;
  final double weight;
  final int reps;
  final int restSeconds;
}

class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.messages,
    this.serverConversationId,
  });
  final String id;
  String title;
  List<ChatMessage> messages;
  String? serverConversationId;
}

class TrainingProfile {
  const TrainingProfile({
    this.gender,
    this.age,
    this.trainingYears,
    this.goal,
    this.heightCm,
    this.weightKg,
    this.weeklyTrainingDays,
    this.preferredWeekdays = const [],
    this.activityLevel = 'moderate',
    this.sessionMinutes = 60,
    this.planStyle = 'fixed',
    this.preferredRepRange = '8-12',
    this.needsWarmupSets = true,
    this.focusMuscles = const [],
    this.reducedMuscles = const [],
    this.dislikedExerciseIds = const [],
    this.unavailableExerciseIds = const [],
  });

  final String? gender;
  final int? age;
  final double? trainingYears;
  final String? goal;
  final double? heightCm;
  final double? weightKg;
  final int? weeklyTrainingDays;

  /// ISO weekday numbers (1 = Monday … 7 = Sunday) selected by the user.
  /// Empty means that the user has not selected a preferred schedule yet.
  /// [weeklyTrainingDays] remains in the wire shape for older installs and
  /// is derived from this list whenever the profile is saved.
  final List<int> preferredWeekdays;

  /// Kept for backward compatibility with profiles saved before weekly
  /// training frequency replaced the vague daily-activity selector.
  final String activityLevel;
  final int sessionMinutes;
  final String planStyle;
  final String preferredRepRange;
  final bool needsWarmupSets;
  final List<String> focusMuscles;
  final List<String> reducedMuscles;
  final List<String> dislikedExerciseIds;
  final List<String> unavailableExerciseIds;

  Map<String, dynamic> toJson() => {
    if (gender != null) 'gender': gender,
    if (age != null) 'age': age,
    if (trainingYears != null) 'trainingYears': trainingYears,
    if (goal != null) 'goal': goal,
    if (heightCm != null) 'heightCm': heightCm,
    if (weightKg != null) 'weightKg': weightKg,
    if (weeklyTrainingDays != null) 'weeklyTrainingDays': weeklyTrainingDays,
    'preferredWeekdays': preferredWeekdays,
    'activityLevel': activityLevel,
    'sessionMinutes': sessionMinutes,
    'planStyle': planStyle,
    'preferredRepRange': preferredRepRange,
    'needsWarmupSets': needsWarmupSets,
    'focusMuscles': focusMuscles,
    'reducedMuscles': reducedMuscles,
    'dislikedExerciseIds': dislikedExerciseIds,
    'unavailableExerciseIds': unavailableExerciseIds,
  };

  factory TrainingProfile.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = json['preferredWeekdays'];
    final parsedWeekdays = rawWeekdays is List
        ? rawWeekdays
              .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
              .whereType<int>()
              .where(
                (item) => item >= DateTime.monday && item <= DateTime.sunday,
              )
              .toSet()
              .toList()
        : <int>[];
    final legacyFrequency = (json['weeklyTrainingDays'] as num?)?.toInt();
    final activityLevel = json['activityLevel']?.toString() ?? 'moderate';
    final fallbackCount =
        legacyFrequency ??
        switch (activityLevel) {
          'low' => 1,
          'high' => 5,
          _ => 3,
        };
    final preferredWeekdays = parsedWeekdays.isNotEmpty
        ? (parsedWeekdays..sort())
        : List<int>.generate(
            fallbackCount.clamp(0, 7).toInt(),
            (index) => DateTime.monday + index,
          );
    return TrainingProfile(
      gender: json['gender']?.toString(),
      age: (json['age'] as num?)?.toInt(),
      trainingYears: (json['trainingYears'] as num?)?.toDouble(),
      goal: json['goal']?.toString(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      // The selected weekdays are authoritative for new profiles. Keep the
      // legacy frequency only as the source for the fallback list above.
      weeklyTrainingDays: preferredWeekdays.length,
      preferredWeekdays: preferredWeekdays,
      activityLevel: activityLevel,
      sessionMinutes: (json['sessionMinutes'] as num?)?.toInt() ?? 60,
      planStyle: json['planStyle']?.toString() ?? 'fixed',
      preferredRepRange: json['preferredRepRange']?.toString() ?? '8-12',
      needsWarmupSets: json['needsWarmupSets'] != false,
      focusMuscles: _profileStringList(json['focusMuscles']),
      reducedMuscles: _profileStringList(json['reducedMuscles']),
      dislikedExerciseIds: _profileStringList(json['dislikedExerciseIds']),
      unavailableExerciseIds: _profileStringList(
        json['unavailableExerciseIds'],
      ),
    );
  }
}

List<String> _profileStringList(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

class NutritionEntry {
  const NutritionEntry({
    required this.id,
    required this.recordedAt,
    required this.mealType,
    required this.foodName,
    required this.calories,
    this.amount = '',
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.photoPaths = const [],
    this.recognitionWarnings = const [],
    this.recognitionReviewed = false,
  });

  final String id;
  final DateTime recordedAt;
  final String mealType;
  final String foodName;
  final String amount;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final List<String> photoPaths;
  final List<String> recognitionWarnings;
  final bool recognitionReviewed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'mealType': mealType,
    'foodName': foodName,
    'amount': amount,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    if (photoPaths.isNotEmpty) 'photoPaths': photoPaths,
    if (recognitionWarnings.isNotEmpty)
      'recognitionWarnings': recognitionWarnings,
    'recognitionReviewed': recognitionReviewed,
  };

  factory NutritionEntry.fromJson(Map<String, dynamic> json) => NutritionEntry(
    id: json['id']?.toString() ?? '',
    recordedAt:
        DateTime.tryParse(json['recordedAt']?.toString() ?? '') ??
        DateTime.now(),
    mealType: json['mealType']?.toString() ?? '其他',
    foodName: json['foodName']?.toString() ?? '',
    amount: json['amount']?.toString() ?? '',
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    proteinGrams: (json['proteinGrams'] as num?)?.toDouble() ?? 0,
    carbsGrams: (json['carbsGrams'] as num?)?.toDouble() ?? 0,
    fatGrams: (json['fatGrams'] as num?)?.toDouble() ?? 0,
    photoPaths:
        (json['photoPaths'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const [],
    recognitionWarnings:
        (json['recognitionWarnings'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false) ??
        const [],
    recognitionReviewed: json['recognitionReviewed'] == true,
  );
}

/// A compact, immutable snapshot shown in the friends feed after a user
/// explicitly publishes a completed workout. Private notes and body metrics
/// never belong to this model.
@immutable
class WorkoutActivityPost {
  const WorkoutActivityPost({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.workoutName,
    required this.completedAt,
    required this.durationSeconds,
    required this.volume,
    required this.effectiveSets,
    required this.completionPercent,
    this.exerciseSummary = const [],
    this.caption = '',
    this.createdAt,
    this.likeCount = 0,
    this.liked = false,
    this.emojiCounts = const {},
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String workoutName;
  final DateTime completedAt;
  final int durationSeconds;
  final double volume;
  final int effectiveSets;
  final int completionPercent;
  final List<WorkoutActivityExercise> exerciseSummary;
  final String caption;
  final DateTime? createdAt;
  final int likeCount;
  final bool liked;
  final Map<String, int> emojiCounts;

  factory WorkoutActivityPost.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exerciseSummary'] ?? json['exercises'];
    final exercises = rawExercises is List
        ? rawExercises
              .whereType<Map>()
              .map(
                (item) => WorkoutActivityExercise.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <WorkoutActivityExercise>[];
    final rawEmojiCounts = json['emojiCounts'] ?? json['commentCounts'];
    final emojiCounts = <String, int>{};
    if (rawEmojiCounts is Map) {
      rawEmojiCounts.forEach((key, value) {
        final count = value is num ? value.toInt() : int.tryParse('$value');
        if (count != null && count > 0) emojiCounts[key.toString()] = count;
      });
    }
    final completedAt =
        DateTime.tryParse(
          (json['completedAt'] ?? json['finishedAt'] ?? json['createdAt'] ?? '')
              .toString(),
        ) ??
        DateTime.now();
    final createdAt = DateTime.tryParse((json['createdAt'] ?? '').toString());
    final rawCompletion = json['completionPercent'] ?? json['completionRate'];
    final completion = rawCompletion is num
        ? (rawCompletion > 1 ? rawCompletion : rawCompletion * 100).round()
        : 100;
    return WorkoutActivityPost(
      id: (json['id'] ?? json['postId'] ?? '').toString(),
      ownerId: (json['ownerId'] ?? json['userId'] ?? '').toString(),
      ownerName: (json['ownerName'] ?? json['displayName'] ?? '好友').toString(),
      workoutName: (json['workoutName'] ?? json['name'] ?? '训练').toString(),
      completedAt: completedAt,
      durationSeconds:
          (json['durationSeconds'] ?? json['duration'] as num?)?.toInt() ?? 0,
      volume:
          (json['volume'] ?? json['trainingVolume'] as num?)?.toDouble() ?? 0,
      effectiveSets:
          (json['effectiveSets'] ?? json['completedSets'] as num?)?.toInt() ??
          0,
      completionPercent: completion.clamp(0, 100),
      exerciseSummary: exercises,
      caption: (json['caption'] ?? json['note'] ?? '').toString(),
      createdAt: createdAt,
      likeCount: (json['likeCount'] ?? json['likes'] as num?)?.toInt() ?? 0,
      liked: json['liked'] == true || json['myLike'] == true,
      emojiCounts: Map<String, int>.unmodifiable(emojiCounts),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'workoutName': workoutName,
    'completedAt': completedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'volume': volume,
    'effectiveSets': effectiveSets,
    'completionPercent': completionPercent,
    'exerciseSummary': exerciseSummary.map((item) => item.toJson()).toList(),
    if (caption.trim().isNotEmpty) 'caption': caption.trim(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    'likeCount': likeCount,
    'liked': liked,
    'emojiCounts': emojiCounts,
  };

  WorkoutActivityPost copyWith({
    int? likeCount,
    bool? liked,
    Map<String, int>? emojiCounts,
  }) => WorkoutActivityPost(
    id: id,
    ownerId: ownerId,
    ownerName: ownerName,
    workoutName: workoutName,
    completedAt: completedAt,
    durationSeconds: durationSeconds,
    volume: volume,
    effectiveSets: effectiveSets,
    completionPercent: completionPercent,
    exerciseSummary: exerciseSummary,
    caption: caption,
    createdAt: createdAt,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
    emojiCounts: emojiCounts ?? this.emojiCounts,
  );
}

@immutable
class WorkoutActivityExercise {
  const WorkoutActivityExercise({
    required this.exerciseId,
    required this.name,
    this.sets = 0,
    this.topWeight,
    this.topReps,
  });

  final String exerciseId;
  final String name;
  final int sets;
  final double? topWeight;
  final int? topReps;

  factory WorkoutActivityExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutActivityExercise(
        exerciseId: (json['exerciseId'] ?? json['id'] ?? '').toString(),
        name: (json['name'] ?? json['exerciseName'] ?? '').toString(),
        sets: (json['sets'] ?? json['setCount'] as num?)?.toInt() ?? 0,
        topWeight: (json['topWeight'] ?? json['weight'] as num?)?.toDouble(),
        topReps: (json['topReps'] ?? json['reps'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'sets': sets,
    if (topWeight != null) 'topWeight': topWeight,
    if (topReps != null) 'topReps': topReps,
  };
}

enum FoodRecognitionStatus { completed, insufficientImage, failed }

@immutable
class FoodNutritionCandidate {
  const FoodNutritionCandidate({
    required this.label,
    required this.confidence,
    this.estimatedGrams,
    this.calories,
    this.calorieRange,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.nutritionSource,
  });

  final String label;
  final double confidence;
  final double? estimatedGrams;
  final double? calories;
  final (double, double)? calorieRange;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  final String? nutritionSource;

  factory FoodNutritionCandidate.fromJson(Map<String, dynamic> json) {
    final rawRange = json['calorieRange'];
    (double, double)? range;
    if (rawRange is List && rawRange.length >= 2) {
      final low = (rawRange[0] as num?)?.toDouble();
      final high = (rawRange[1] as num?)?.toDouble();
      if (low != null && high != null) range = (low, high);
    }
    double? number(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value');
    return FoodNutritionCandidate(
      label: (json['label'] ?? json['name'] ?? '待确认食物').toString(),
      confidence: (number(json['confidence']) ?? 0).clamp(0, 1),
      estimatedGrams: number(json['estimatedGrams'] ?? json['grams']),
      calories: number(json['estimatedCalories'] ?? json['calories']),
      calorieRange: range,
      proteinGrams: number(json['proteinGrams'] ?? json['protein']),
      carbsGrams: number(
        json['carbsGrams'] ?? json['carbs'] ?? json['carbohydrates'],
      ),
      fatGrams: number(json['fatGrams'] ?? json['fat']),
      nutritionSource: json['nutritionSource']?.toString(),
    );
  }
}

@immutable
class FoodPhotoRecognitionResult {
  const FoodPhotoRecognitionResult({
    required this.status,
    required this.requiresReview,
    this.items = const [],
    this.warnings = const [],
    this.modelVersion,
    this.error,
  });

  final FoodRecognitionStatus status;
  final bool requiresReview;
  final List<FoodNutritionCandidate> items;
  final List<String> warnings;
  final String? modelVersion;
  final String? error;

  bool get hasNutrition =>
      items.any((item) => item.calories != null || item.proteinGrams != null);

  factory FoodPhotoRecognitionResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => FoodNutritionCandidate.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <FoodNutritionCandidate>[];
    final status = switch ((json['status'] ?? 'failed').toString()) {
      'completed' => FoodRecognitionStatus.completed,
      'insufficient_image' => FoodRecognitionStatus.insufficientImage,
      _ => FoodRecognitionStatus.failed,
    };
    return FoodPhotoRecognitionResult(
      status: status,
      requiresReview: json['requiresReview'] != false,
      items: items,
      warnings:
          (json['warnings'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false) ??
          const [],
      modelVersion: json['modelVersion']?.toString(),
      error: json['error']?.toString(),
    );
  }
}

@immutable
class ExerciseResource {
  const ExerciseResource({required this.note, required this.link});
  final String note;
  final String link;
}

const setTypeLabels = <String, String>{
  'warmup': '热身组',
  'work': '正式组',
  'backoff': '退阶组',
  'drop': '递减组',
  'failure': '力竭组',
  'technique': '技术练习',
};

const setTypeColors = <String, int>{
  'warmup': 0xFF708494,
  'work': 0xFF0B66D4,
  'backoff': 0xFFE47B32,
  'drop': 0xFFD26A2B,
  'failure': 0xFFB83A3A,
  'technique': 0xFF708494,
};

const setTypeIcons = <String, int>{
  'warmup': 0xe3a1,
  'work': 0xe57d,
  'backoff': 0xe8d4,
  'drop': 0xf04a,
  'failure': 0xe000,
  'technique': 0xe8b6,
};

const curatedCatalog = <Exercise>[
  Exercise(
    id: 'machine_chest_press',
    name: '器械推胸',
    englishName: 'Machine chest press',
    family: '推',
    muscle: '胸部',
    secondary: '肱三头肌',
    equipment: '固定器械',
    camera: '侧前方 30-45°',
    cue: '让手柄轨迹与前臂方向保持一致',
  ),
  Exercise(
    id: 'machine_crunch',
    name: '器械卷腹',
    englishName: 'Machine crunch',
    family: '核心',
    muscle: '腹部',
    secondary: '腹斜肌',
    equipment: '固定器械',
    camera: '正侧面',
    cue: '由胸廓向骨盆卷曲，不要只低头',
  ),
  Exercise(
    id: 'standing_hip_abduction',
    name: '站姿髋外展',
    englishName: 'Standing hip abduction',
    family: '髋部孤立',
    muscle: '臀中肌',
    secondary: '臀小肌',
    equipment: '绳索',
    camera: '正面',
    cue: '骨盆保持水平，腿向侧方展开',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'seated_hip_abduction',
    name: '坐姿髋外展',
    englishName: 'Seated hip abduction',
    family: '髋部孤立',
    muscle: '臀部',
    secondary: '臀中肌',
    equipment: '固定器械',
    camera: '正前方',
    cue: '保持躯干稳定，控制回程',
  ),
  Exercise(
    id: 'chest_supported_row',
    name: '胸托划船',
    englishName: 'Chest-supported row',
    family: '拉',
    muscle: '上背部',
    secondary: '肱二头肌',
    equipment: '固定器械',
    camera: '正侧方',
    cue: '胸口保持支撑，肘部向后拉',
  ),
  Exercise(
    id: 't_bar_row',
    name: 'T 杠划船',
    englishName: 'T-bar row',
    family: '拉',
    muscle: '背部',
    secondary: '后束',
    equipment: '杠铃',
    camera: '侧后方',
    cue: '保持躯干角度，不用髋部甩动',
  ),
  Exercise(
    id: 'plate_loaded_pulldown',
    name: '片装高位下拉',
    englishName: 'Plate-loaded pulldown',
    family: '拉',
    muscle: '背阔肌',
    secondary: '肱二头肌',
    equipment: '固定器械',
    camera: '正侧方',
    cue: '肘部向髋部方向下拉',
  ),
  Exercise(
    id: 'plate_loaded_romanian_deadlift',
    name: '片装罗马尼亚硬拉',
    englishName: 'Plate-loaded RDL',
    family: '髋铰链',
    muscle: '腘绳肌',
    secondary: '臀部',
    equipment: '固定器械',
    camera: '正侧面',
    cue: '髋部后移，负重路径贴近身体',
  ),
  Exercise(
    id: 'single_arm_pulldown',
    name: '单臂高位下拉',
    englishName: 'Single-arm pulldown',
    family: '拉',
    muscle: '背阔肌',
    secondary: '肱二头肌',
    equipment: '绳索',
    camera: '工作侧前方',
    cue: '先稳定肩胛，再让肘部向下',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'hack_squat',
    name: '哈克深蹲',
    englishName: 'Hack squat',
    family: '蹲',
    muscle: '股四头肌',
    secondary: '臀部',
    equipment: '固定器械',
    camera: '侧后方',
    cue: '膝盖跟随脚尖方向，控制下放',
  ),
  Exercise(
    id: 'hip_thrust',
    name: '杠铃臀推',
    englishName: 'Hip thrust',
    family: '髋铰链',
    muscle: '臀部',
    secondary: '腘绳肌',
    equipment: '杠铃',
    camera: '正侧面',
    cue: '顶端保持肋骨和骨盆稳定',
  ),
  Exercise(
    id: 'back_extension',
    name: '山羊挺身',
    englishName: 'Back extension',
    family: '髋铰链',
    muscle: '后侧链',
    secondary: '下背部',
    equipment: '自重',
    camera: '正侧面',
    cue: '从髋部折叠，不要过度伸展腰椎',
    loadMode: 'bodyweight',
  ),
  Exercise(
    id: 'preacher_curl',
    name: '牧师凳弯举',
    englishName: 'Preacher curl',
    family: '肘部孤立',
    muscle: '肱二头肌',
    secondary: '前臂',
    equipment: '哑铃',
    camera: '工作侧',
    cue: '上臂贴稳支撑面，完整控制下放',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'barbell_squat',
    name: '杠铃深蹲',
    englishName: 'Barbell squat',
    family: '蹲',
    muscle: '腿部',
    secondary: '臀部',
    equipment: '杠铃',
    camera: '侧后方 30-45°',
    cue: '中足稳定，髋膝同步下降',
  ),
  Exercise(
    id: 'goblet_squat',
    name: '高脚杯深蹲',
    englishName: 'Goblet squat',
    family: '蹲',
    muscle: '腿部',
    secondary: '核心',
    equipment: '哑铃',
    camera: '侧前方',
    cue: '负重贴近胸口，保持足底稳定',
  ),
  Exercise(
    id: 'deadlift',
    name: '传统硬拉',
    englishName: 'Deadlift',
    family: '髋铰链',
    muscle: '后侧链',
    secondary: '背部',
    equipment: '杠铃',
    camera: '正侧面',
    cue: '杠铃从中足上方垂直移动',
  ),
  Exercise(
    id: 'romanian_deadlift',
    name: '罗马尼亚硬拉',
    englishName: 'Romanian deadlift',
    family: '髋铰链',
    muscle: '腘绳肌',
    secondary: '臀部',
    equipment: '杠铃',
    camera: '正侧面',
    cue: '膝角稳定，髋部持续后移',
  ),
  Exercise(
    id: 'bench_press',
    name: '杠铃卧推',
    englishName: 'Bench press',
    family: '推',
    muscle: '胸部',
    secondary: '肱三头肌',
    equipment: '杠铃',
    camera: '侧前方 30-45°',
    cue: '前臂垂直，杠铃稳定触胸',
  ),
  Exercise(
    id: 'dumbbell_press',
    name: '上斜哑铃卧推',
    englishName: 'Dumbbell press',
    family: '推',
    muscle: '上胸',
    secondary: '肱三头肌',
    equipment: '哑铃',
    camera: '侧前方',
    cue: '两侧同步下降，避免肩部前移',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'shoulder_press',
    name: '哑铃推举',
    englishName: 'Shoulder press',
    family: '推',
    muscle: '肩部',
    secondary: '肱三头肌',
    equipment: '哑铃',
    camera: '正侧方',
    cue: '保持肋骨下沉，手腕叠在肘部上方',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'push_up',
    name: '俯卧撑',
    englishName: 'Push-up',
    family: '推',
    muscle: '胸部',
    secondary: '核心',
    equipment: '自重',
    camera: '正侧面',
    cue: '头肩髋保持一条直线',
    loadMode: 'bodyweight',
  ),
  Exercise(
    id: 'dip',
    name: '双杠臂屈伸',
    englishName: 'Dip',
    family: '推',
    muscle: '胸部',
    secondary: '肱三头肌',
    equipment: '自重',
    camera: '正侧面',
    cue: '肩胛稳定，下降深度由控制决定',
    loadMode: 'bodyweight',
  ),
  Exercise(
    id: 'row',
    name: '坐姿绳索划船',
    englishName: 'Seated row',
    family: '拉',
    muscle: '背部',
    secondary: '肱二头肌',
    equipment: '绳索',
    camera: '正侧方',
    cue: '躯干保持稳定，肘部贴近身体',
  ),
  Exercise(
    id: 'lat_pulldown',
    name: '高位下拉',
    englishName: 'Lat pulldown',
    family: '拉',
    muscle: '背阔肌',
    secondary: '肱二头肌',
    equipment: '绳索',
    camera: '正前方',
    cue: '下拉到上胸，避免明显后仰',
  ),
  Exercise(
    id: 'pull_up',
    name: '引体向上',
    englishName: 'Pull-up',
    family: '拉',
    muscle: '背部',
    secondary: '肱二头肌',
    equipment: '自重',
    camera: '正前方',
    cue: '从稳定悬垂开始，胸口向上',
    loadMode: 'bodyweight',
  ),
  Exercise(
    id: 'face_pull',
    name: '绳索面拉',
    englishName: 'Face pull',
    family: '拉',
    muscle: '肩后束',
    secondary: '上背部',
    equipment: '绳索',
    camera: '正前方',
    cue: '向面部拉开绳索，避免耸肩',
  ),
  Exercise(
    id: 'lateral_raise',
    name: '哑铃侧平举',
    englishName: 'Lateral raise',
    family: '肩部孤立',
    muscle: '肩中束',
    secondary: '斜方肌',
    equipment: '哑铃',
    camera: '正前方',
    cue: '以肘部带动手臂向侧上方',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'y_raise',
    name: '绳索 Y 举',
    englishName: 'Cable Y raise',
    family: '肩部孤立',
    muscle: '肩部',
    secondary: '下斜方肌',
    equipment: '绳索',
    camera: '正前方',
    cue: '手腕沿对角线上升到 Y 字顶端',
    loadMode: 'perSide',
  ),
  Exercise(
    id: 'biceps_curl',
    name: '杠铃弯举',
    englishName: 'Biceps curl',
    family: '肘部孤立',
    muscle: '肱二头肌',
    secondary: '前臂',
    equipment: '杠铃',
    camera: '正侧方',
    cue: '上臂稳定，避免躯干借力',
  ),
  Exercise(
    id: 'triceps_extension',
    name: '绳索臂屈伸',
    englishName: 'Triceps extension',
    family: '肘部孤立',
    muscle: '肱三头肌',
    secondary: '前臂',
    equipment: '绳索',
    camera: '正侧方',
    cue: '肘部位置稳定，完成伸展',
  ),
  Exercise(
    id: 'leg_extension',
    name: '腿屈伸',
    englishName: 'Leg extension',
    family: '膝部孤立',
    muscle: '股四头肌',
    secondary: '无',
    equipment: '固定器械',
    camera: '正侧面',
    cue: '控制膝关节伸展和下放',
  ),
  Exercise(
    id: 'leg_curl',
    name: '腿弯举',
    englishName: 'Leg curl',
    family: '膝部孤立',
    muscle: '腘绳肌',
    secondary: '小腿',
    equipment: '固定器械',
    camera: '正侧面',
    cue: '骨盆稳定，控制回程',
  ),
];

final List<Exercise> _rawCatalog = <Exercise>[
  ...curatedCatalog,
  for (final entry in datasetExerciseEntries.entries)
    Exercise(
      id: entry.key,
      name: chineseExerciseName(
        entry.value.name,
        equipment: entry.value.equipment,
        muscle: entry.value.muscle,
      ),
      englishName: entry.value.name,
      family: entry.value.family,
      muscle: entry.value.muscle,
      secondary: entry.value.secondary,
      equipment: entry.value.equipment,
      camera: '正侧面或侧前方 30-45°',
      cue: entry.value.steps.isEmpty
          ? entry.value.summary
          : entry.value.steps.first,
      loadMode: entry.value.loadMode,
    ),
];

/// Stable, user-facing names must be unique inside the library. The public
/// dataset contains variants whose translated names legitimately collide (and
/// even a few duplicate English names). Keep the concise translation for the
/// first item and add a compact Chinese variant number only to colliding
/// variants. Media remains keyed by the stable exercise ID.
final List<Exercise> catalog = _disambiguateExerciseNames(_rawCatalog);

/// The complete catalog remains available for history/import compatibility.
///
/// A small number of movements belong to legacy equipment categories that are
/// intentionally not offered by the current picker.  They must be filtered at
/// the selectable boundary only: old records still resolve through [catalog]
/// and can be rendered after an app upgrade.
bool _isUnsupportedSelectableExercise(Exercise exercise) {
  return retiredExerciseIds.contains(exercise.id) ||
      manuallyRetiredExerciseIds.contains(exercise.id);
}

/// Picker-visible exercises. The historical catalog above is deliberately not
/// mutated, so old saved plans and records remain readable.
final List<Exercise> selectableCatalog = List<Exercise>.unmodifiable(
  catalog.where((exercise) => !_isUnsupportedSelectableExercise(exercise)),
);

List<Exercise> _disambiguateExerciseNames(List<Exercise> source) {
  final counts = <String, int>{};
  for (final exercise in source) {
    counts[exercise.name] = (counts[exercise.name] ?? 0) + 1;
  }
  final seen = <String, int>{};
  return [
    for (final exercise in source)
      if ((counts[exercise.name] ?? 0) <= 1)
        exercise
      else
        Exercise(
          id: exercise.id,
          name: '${exercise.name}（${_exerciseVariantLabel(exercise, seen)}）',
          englishName: exercise.englishName,
          family: exercise.family,
          muscle: exercise.muscle,
          secondary: exercise.secondary,
          equipment: exercise.equipment,
          camera: exercise.camera,
          cue: exercise.cue,
          loadMode: exercise.loadMode,
        ),
  ];
}

String _exerciseVariantLabel(Exercise exercise, Map<String, int> seen) {
  final key = exercise.name;
  final occurrence = (seen[key] ?? 0) + 1;
  seen[key] = occurrence;
  return '变式 $occurrence';
}

/// English metadata for the public dataset is already canonical. Curated
/// Chinese-only metadata uses this compact lookup so filters and cards remain
/// understandable in the overseas build without changing stored contracts.
String localizeExerciseMetadata(String value, {required bool english}) {
  if (!english) return value;
  const labels = <String, String>{
    '胸部': 'Chest',
    '背部': 'Back',
    '肩部': 'Shoulders',
    '腿部': 'Legs',
    '手臂': 'Arms',
    '核心': 'Core',
    '前臂': 'Forearms',
    '小腿': 'Calves',
    '胸肌': 'Pectorals',
    '背阔肌': 'Lats',
    '上背部': 'Upper back',
    '三角肌': 'Deltoids',
    '肱二头肌': 'Biceps',
    '肱三头肌': 'Triceps',
    '股四头肌': 'Quadriceps',
    '腘绳肌': 'Hamstrings',
    '臀肌': 'Glutes',
    '腹肌': 'Abs',
    '腹斜肌': 'Obliques',
    '斜方肌': 'Traps',
    '杠铃': 'Barbell',
    '哑铃': 'Dumbbell',
    '绳索': 'Cable',
    '自重': 'Bodyweight',
    '固定器械': 'Machine',
    '弹力带': 'Band',
    '阻力带': 'Resistance band',
    '壶铃': 'Kettlebell',
    '史密斯机': 'Smith machine',
    '药球': 'Medicine ball',
    '健身球': 'Stability ball',
    '有氧': 'Cardio',
    '辅助器械': 'Assisted',
    '其他': 'Other',
    '无': 'None',
  };
  return labels[value] ?? value;
}

Exercise findExercise(String id) =>
    catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

String muscleGroupForLabel(String muscle) {
  if (muscle.contains('胸')) return '胸';
  if (muscle.contains('背') || muscle.contains('背阔') || muscle.contains('斜方')) {
    return '背';
  }
  if (muscle.contains('肩') || muscle.contains('三角') || muscle.contains('束')) {
    return '肩';
  }
  if (muscle.contains('腿') ||
      muscle.contains('股') ||
      muscle.contains('臀') ||
      muscle.contains('腘') ||
      muscle.contains('小腿')) {
    return '腿';
  }
  if (muscle.contains('肱') || muscle.contains('前臂') || muscle.contains('肘')) {
    return '手臂';
  }
  if (muscle.contains('腹') || muscle.contains('核心')) return '核心';
  return '其他';
}

/// Returns the equipment category used by filters.
///
/// Barbell variants and common cardio machines share a stable Chinese filter
/// group. Other equipment labels remain available so the full exercise library
/// is not hidden behind an opaque "other" bucket.
String equipmentGroupForLabel(String equipment) {
  final normalized = equipment.trim().toLowerCase();
  if (normalized.isEmpty) return '其他';
  if (normalized.contains('杠铃') ||
      normalized.contains('barbell') ||
      normalized.contains('olympic bar') ||
      normalized.contains('ez bar') ||
      normalized.contains('曲杆') ||
      normalized.contains('六角杠') ||
      normalized.contains('奥杆') ||
      normalized.contains('trap bar')) {
    return '杠铃';
  }
  if (normalized.contains('固定自行车') ||
      normalized.contains('椭圆机') ||
      normalized.contains('登阶机') ||
      normalized.contains('stationary bike') ||
      normalized.contains('exercise bike') ||
      normalized.contains('elliptical') ||
      normalized.contains('stepper') ||
      normalized.contains('stair climber')) {
    return '有氧';
  }
  return equipment.trim();
}

String exerciseAsset(String id) {
  final reference = mediaForExercise(id);
  if (reference != null) return reference.imagePath;
  const assets = <String, String>{
    'machine_chest_press': 'bench_press_0.png',
    'machine_crunch': 'crunch_0.png',
    'seated_hip_abduction': 'hip_bridge_0.png',
    'chest_supported_row': 'seated_row_0.png',
    't_bar_row': 'seated_row_1.png',
    'plate_loaded_pulldown': 'lat_pulldown_0.png',
    'plate_loaded_romanian_deadlift': 'romanian_deadlift_0.png',
    'single_arm_pulldown': 'lat_pulldown_1.png',
    'hack_squat': 'squat_1.png',
    'hip_thrust': 'hip_bridge_1.png',
    'back_extension': 'romanian_deadlift_1.png',
    'preacher_curl': 'biceps_curl_1.png',
    'barbell_squat': 'squat_0.png',
    'goblet_squat': 'squat_1.png',
    'deadlift': 'romanian_deadlift_1.png',
    'romanian_deadlift': 'romanian_deadlift_0.png',
    'bench_press': 'bench_press_0.png',
    'dumbbell_press': 'incline_dumbbell_press_0.png',
    'shoulder_press': 'shoulder_press_0.png',
    'push_up': 'bench_press_1.png',
    'row': 'seated_row_0.png',
    'lat_pulldown': 'lat_pulldown_0.png',
    'pull_up': 'lat_pulldown_1.png',
    'face_pull': 'seated_row_1.png',
    'lateral_raise': 'lateral_raise_0.png',
    'y_raise': 'lateral_raise_1.png',
    'biceps_curl': 'biceps_curl_0.png',
  };
  return 'assets/exercises/${assets[id] ?? 'bench_press_0.png'}';
}
