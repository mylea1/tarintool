import 'package:flutter/foundation.dart';

import 'exercise_dataset.generated.dart';
import 'exercise_name_zh.dart';
import 'exercise_media.dart';

enum PageId { today, train, records, exercises, recognition, ai, profile }

enum TrainView { workout, plans, history }

enum AiView { chat, recognition }

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

const fallbackRecognitionCapabilities = <RecognitionCapability>[
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

class WorkoutSet {
  WorkoutSet({
    required this.id,
    this.type = 'work',
    this.weight = 80,
    this.plannedWeight,
    this.reps = 8,
    this.targetMin = 6,
    this.targetMax = 8,
    this.restSeconds = 120,
    this.completed = false,
    this.failed = false,
    this.note = '',
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
  String note;

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
    note: note,
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
    note: note,
  );
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    required this.sets,
    this.restSeconds = 120,
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
    this.exercises = const [],
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

  /// A snapshot of the exercises and sets performed in this record.
  /// Older records may omit it and fall back to [exerciseIds].
  final List<WorkoutExercise> exercises;
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
  final String body;
  final List<String> citations;
  final AiPlanDraft? plan;
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
  const AiPlanExerciseDraft({required this.exerciseId, required this.sets});

  final String exerciseId;
  final List<AiPlanSetDraft> sets;

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
  });
  final String id;
  String title;
  List<ChatMessage> messages;
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

final List<Exercise> catalog = <Exercise>[
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

Exercise findExercise(String id) =>
    catalog.firstWhere((item) => item.id == id, orElse: () => catalog.first);

String muscleGroupForLabel(String muscle) {
  if (muscle.contains('胸')) return '胸';
  if (muscle.contains('背') || muscle.contains('背阔') || muscle.contains('斜方')) {
    return '背';
  }
  if (muscle.contains('肩') || muscle.contains('束')) return '肩';
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
