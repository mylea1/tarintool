import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'ai_api.dart';
import 'models.dart';
import 'recognition_api.dart';

class PlatformTimerBridge {
  static const _channel = MethodChannel('kilo.platform.timer');

  static void setRestSkippedHandler(VoidCallback? handler) {
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'restSkippedFromNotification') {
                handler();
              }
            },
    );
  }

  static Future<void> start({
    required String exercise,
    required int seconds,
  }) async {
    try {
      await _channel.invokeMethod<void>('startTimer', {
        'exercise': exercise,
        'seconds': seconds,
      });
    } on MissingPluginException {
      // The Android/iOS bridge is optional in widget tests and desktop previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when a system capability is unavailable.
    }
  }

  static Future<void> pause() async {
    try {
      await _channel.invokeMethod<void>('pauseTimer');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> update({
    required String exercise,
    required int seconds,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateTimer', {
        'exercise': exercise,
        'seconds': seconds,
      });
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> finish() async {
    try {
      await _channel.invokeMethod<void>('finishTimer');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }
}

class AppController extends ChangeNotifier {
  AppController() {
    _seed();
    PlatformTimerBridge.setRestSkippedHandler(skipRest);
  }

  PageId page = PageId.today;
  TrainView trainView = TrainView.workout;
  AiView aiView = AiView.chat;
  bool workoutStarted = false;
  bool workoutPaused = false;
  DateTime? workoutStartedAt;
  int workoutElapsedSeconds = 0;
  bool workoutDraft = false;
  bool workoutCompleted = false;
  bool liveWorkoutVisible = false;
  String workoutName = '上肢力量 A';
  String workoutNote = '';
  final List<WorkoutExercise> workout = [];
  final List<Routine> routines = [];
  final List<String> routineFolders = [];
  final List<WorkoutRecord> history = [];
  final List<Exercise> customExercises = [];
  final Map<String, Map<String, ExerciseResource>> exerciseResources = {};
  final RecognitionApi recognitionApi = MockRecognitionApi();
  final CoachApi mockCoachApi = MockCoachApi();
  String aiBaseUrl = '';
  String? selectedMediaPath;
  String? selectedMediaName;
  int? selectedMediaBytes;
  String? mediaError;
  bool mediaPicking = false;
  RecognitionResult? recognitionResult;
  final List<String> scheduled = [
    '2026-08-01',
    '2026-08-03',
    '2026-08-05',
    '2026-08-08',
  ];
  int defaultRestSeconds = 120;
  bool rpeTrackingEnabled = true;
  bool livePrEnabled = true;
  String selectedExerciseId = 'bench_press';
  String search = '';
  String muscleFilter = '全部';
  String equipmentFilter = '全部';
  RecognitionStatus recognitionStatus = RecognitionStatus.idle;
  double recognitionProgress = 0;
  String recognitionExerciseId = 'bench_press';
  String recognitionCamera = '侧前方 30-45°';
  bool savedCue = false;
  bool analysisAttached = false;
  bool aiUseTrainingData = false;
  bool aiConsentSeen = false;
  bool aiTyping = false;
  final List<ChatMessage> chat = [
    ChatMessage(
      id: 'welcome',
      role: 'assistant',
      body: '可以直接问训练技术、计划安排或恢复问题。我会优先使用知识库，并把依据放在回答下方。',
    ),
  ];
  final List<AiConversation> conversations = [];
  String activeConversationId = 'conversation-main';
  String scenario = 'normal';
  bool appleWatch = false;
  bool liveActivity = true;
  bool androidNotifications = false;
  bool batchMode = false;
  final Set<String> selectedSetIds = <String>{};
  String? selectedPlanFolder;
  final Map<String, String> scheduledLabels = {
    '2026-08-05': '上肢增肌',
    '2026-08-08': '下肢增肌',
  };
  int restRemainingSeconds = 0;
  bool restRunning = false;
  String? restExerciseName;
  Timer? _workoutTicker;
  Timer? _restTicker;
  Timer? _recognitionTicker;

  List<Exercise> get allExercises => [...catalog, ...customExercises];

  List<Exercise> get visibleExercises {
    final query = search.trim().toLowerCase();
    return allExercises.where((item) {
      final queryMatch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.englishName.toLowerCase().contains(query);
      final muscleMatch =
          muscleFilter == '全部' || muscleGroupFor(item.muscle) == muscleFilter;
      final equipmentMatch =
          equipmentFilter == '全部' || item.equipment == equipmentFilter;
      return queryMatch && muscleMatch && equipmentMatch;
    }).toList();
  }

  String muscleGroupFor(String muscle) => muscleGroupForLabel(muscle);

  Exercise get selectedExercise => findExercise(selectedExerciseId);
  int get completedSets =>
      workout.expand((item) => item.sets).where((set) => set.completed).length;
  int get totalSets => workout.expand((item) => item.sets).length;
  double get completion => totalSets == 0 ? 0 : completedSets / totalSets;
  double get workoutVolume => workout
      .expand((item) => item.sets)
      .where((set) => set.completed)
      .fold(0, (sum, set) => sum + set.weight * set.reps);
  int get currentElapsed {
    if (!workoutStarted || workoutStartedAt == null || workoutPaused) {
      return workoutElapsedSeconds;
    }
    return workoutElapsedSeconds +
        DateTime.now().difference(workoutStartedAt!).inSeconds;
  }

  void _seed() {
    workout.addAll([
      WorkoutExercise(
        id: 'we-bench',
        exerciseId: 'bench_press',
        restSeconds: 150,
        sets: [
          WorkoutSet(
            id: 'bench-warm-1',
            type: 'warmup',
            weight: 20,
            reps: 10,
            completed: true,
            restSeconds: 60,
          ),
          WorkoutSet(
            id: 'bench-warm-2',
            type: 'warmup',
            weight: 50,
            reps: 8,
            completed: true,
            restSeconds: 90,
          ),
          WorkoutSet(id: 'bench-work-1'),
          WorkoutSet(id: 'bench-work-2'),
          WorkoutSet(id: 'bench-work-3'),
        ],
      ),
      WorkoutExercise(
        id: 'we-row',
        exerciseId: 'chest_supported_row',
        restSeconds: 120,
        collapsed: true,
        sets: [
          WorkoutSet(
            id: 'row-warm-1',
            type: 'warmup',
            weight: 35,
            reps: 10,
            restSeconds: 60,
          ),
          WorkoutSet(id: 'row-work-1', weight: 62.5, reps: 10),
          WorkoutSet(id: 'row-work-2', weight: 62.5, reps: 10),
          WorkoutSet(id: 'row-back-1', type: 'backoff', weight: 55, reps: 12),
        ],
      ),
      WorkoutExercise(
        id: 'we-lateral',
        exerciseId: 'lateral_raise',
        restSeconds: 75,
        collapsed: true,
        sets: [
          WorkoutSet(id: 'lat-work-1', weight: 10, reps: 12, restSeconds: 75),
          WorkoutSet(id: 'lat-work-2', weight: 10, reps: 12, restSeconds: 75),
          WorkoutSet(
            id: 'lat-drop-1',
            type: 'drop',
            weight: 8,
            reps: 15,
            restSeconds: 60,
          ),
        ],
      ),
    ]);
    routines.addAll([
      Routine(
        id: 'routine-upper-a',
        name: '上肢力量 A',
        folder: '力量周期',
        exercises: workout
            .map((item) => item.copy(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime(2026, 8, 2),
      ),
      Routine(
        id: 'routine-lower-b',
        name: '下肢力量 B',
        folder: '力量周期',
        exercises: [
          _makeWorkout('barbell_squat', 'lower-squat'),
          _makeWorkout('romanian_deadlift', 'lower-rdl'),
          _makeWorkout('leg_curl', 'lower-curl'),
        ],
        updatedAt: DateTime(2026, 8, 1),
      ),
      Routine(
        id: 'routine-hypertrophy',
        name: '上肢增肌',
        folder: '增肌模板',
        exercises: [
          _makeWorkout('dumbbell_press', 'hyper-press'),
          _makeWorkout('lat_pulldown', 'hyper-pull'),
          _makeWorkout('lateral_raise', 'hyper-lat'),
        ],
        updatedAt: DateTime(2026, 7, 29),
      ),
    ]);
    routineFolders.addAll(['力量周期', '增肌模板', '自定义']);
    history.addAll([
      WorkoutRecord(
        id: 'history-0801',
        name: '上肢力量 A',
        date: DateTime(2026, 8, 1),
        startTime: '18:32',
        durationSeconds: 3258,
        volume: 6842.5,
        effectiveSets: 12,
        note: '卧推最后一组保持了目标次数。',
        exerciseIds: ['bench_press', 'chest_supported_row', 'lateral_raise'],
        prs: ['卧推重复次数 PR'],
        exercises: _historyDetails([
          'bench_press',
          'chest_supported_row',
          'lateral_raise',
        ]),
      ),
      WorkoutRecord(
        id: 'history-0730',
        name: '下肢力量 B',
        date: DateTime(2026, 7, 30),
        startTime: '19:10',
        durationSeconds: 4020,
        volume: 8260,
        effectiveSets: 15,
        note: '深蹲节奏稳定。',
        exerciseIds: ['barbell_squat', 'romanian_deadlift', 'leg_curl'],
        exercises: _historyDetails([
          'barbell_squat',
          'romanian_deadlift',
          'leg_curl',
        ]),
      ),
      WorkoutRecord(
        id: 'history-0727',
        name: '推拉混合',
        date: DateTime(2026, 7, 27),
        startTime: '17:45',
        durationSeconds: 3510,
        volume: 6410,
        effectiveSets: 13,
        note: '',
        exerciseIds: ['bench_press', 'row', 'shoulder_press'],
        prs: ['坐姿划船重量 PR'],
        exercises: _historyDetails(['bench_press', 'row', 'shoulder_press']),
      ),
      WorkoutRecord(
        id: 'history-0724',
        name: '上肢容量',
        date: DateTime(2026, 7, 24),
        startTime: '18:05',
        durationSeconds: 3360,
        volume: 5985,
        effectiveSets: 14,
        note: '',
        exerciseIds: ['dumbbell_press', 'lat_pulldown', 'lateral_raise'],
        exercises: _historyDetails([
          'dumbbell_press',
          'lat_pulldown',
          'lateral_raise',
        ]),
      ),
    ]);
    conversations.add(
      AiConversation(
        id: activeConversationId,
        title: '训练建议',
        messages: List<ChatMessage>.from(chat),
      ),
    );
  }

  WorkoutExercise _makeWorkout(String exerciseId, String id) => WorkoutExercise(
    id: id,
    exerciseId: exerciseId,
    sets: List.generate(
      3,
      (index) => WorkoutSet(id: '$id-set-$index', weight: index == 0 ? 20 : 30),
    ),
  );

  WorkoutExercise createWorkoutExercise(String exerciseId, String id) =>
      _makeWorkout(exerciseId, id);

  List<WorkoutExercise> _historyDetails(List<String> exerciseIds) {
    return [
      for (
        var exerciseIndex = 0;
        exerciseIndex < exerciseIds.length;
        exerciseIndex++
      )
        (() {
          final exercise = _makeWorkout(
            exerciseIds[exerciseIndex],
            'history-detail-$exerciseIndex-${exerciseIds[exerciseIndex]}',
          );
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++) {
            final set = exercise.sets[setIndex];
            set.completed = true;
            set.type = setIndex == 0 ? 'warmup' : 'work';
            set.weight = 40 + exerciseIndex * 12.5 + setIndex * 2.5;
            set.reps = 8 + (setIndex % 3);
            set.restSeconds = exercise.restSeconds;
          }
          return exercise;
        })(),
    ];
  }

  void selectPage(PageId next) {
    switch (next) {
      case PageId.records:
        page = PageId.train;
        trainView = TrainView.history;
      case PageId.recognition:
        page = PageId.ai;
        aiView = AiView.recognition;
      case PageId.today:
      case PageId.train:
      case PageId.exercises:
      case PageId.ai:
      case PageId.profile:
        page = next;
    }
    notifyListeners();
  }

  /// Notifies Flutter after a field is edited by a form or a platform control.
  void refresh() => notifyListeners();

  void selectTrainView(TrainView next) {
    trainView = next;
    if (next != TrainView.workout) {
      page = PageId.train;
      liveWorkoutVisible = false;
    }
    notifyListeners();
  }

  void selectAiView(AiView next) {
    aiView = next;
    page = PageId.ai;
    notifyListeners();
  }

  void startWorkout({List<WorkoutExercise>? source, String? name}) {
    if (source != null) {
      workout
        ..clear()
        ..addAll(source.map((item) => item.copy(newId: 'session-${item.id}')));
      for (final exercise in workout) {
        for (final set in exercise.sets) {
          set.completed = false;
        }
      }
    }
    workoutName = name ?? workoutName;
    if (workout.isEmpty) {
      workoutDraft = true;
      workoutStarted = false;
      notifyListeners();
      return;
    }
    workoutDraft = false;
    workoutCompleted = false;
    workoutStarted = true;
    workoutPaused = false;
    workoutStartedAt = DateTime.now();
    _workoutTicker?.cancel();
    _workoutTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    notifyListeners();
  }

  void openLiveWorkout() {
    liveWorkoutVisible = true;
    page = PageId.train;
    notifyListeners();
  }

  void closeLiveWorkout() {
    liveWorkoutVisible = false;
    notifyListeners();
  }

  void pauseWorkout() {
    if (!workoutStarted) return;
    workoutElapsedSeconds = currentElapsed;
    workoutPaused = !workoutPaused;
    workoutStartedAt = workoutPaused ? null : DateTime.now();
    if (restRunning) {
      if (workoutPaused) {
        PlatformTimerBridge.pause();
      } else {
        PlatformTimerBridge.update(
          exercise: restExerciseName ?? '休息计时',
          seconds: restRemainingSeconds,
        );
      }
    }
    notifyListeners();
  }

  void completeSet(WorkoutSet set, WorkoutExercise parent) {
    set.completed = !set.completed;
    if (set.completed) {
      restRemainingSeconds = set.restSeconds > 0
          ? set.restSeconds
          : parent.restSeconds;
      startRest(
        exercise: findExercise(parent.exerciseId).name,
        seconds: restRemainingSeconds,
      );
    } else {
      restRunning = false;
      restExerciseName = null;
      _restTicker?.cancel();
      PlatformTimerBridge.finish();
    }
    notifyListeners();
  }

  void addRestSeconds([int seconds = 15]) {
    if (!restRunning) return;
    restRemainingSeconds += seconds;
    PlatformTimerBridge.update(
      exercise: restExerciseName ?? '休息计时',
      seconds: restRemainingSeconds,
    );
    notifyListeners();
  }

  void startRest({required String exercise, required int seconds}) {
    restRemainingSeconds = seconds;
    restRunning = true;
    restExerciseName = exercise;
    PlatformTimerBridge.start(exercise: exercise, seconds: seconds);
    _restTicker?.cancel();
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (workoutPaused) {
        notifyListeners();
        return;
      }
      if (restRemainingSeconds > 0) {
        restRemainingSeconds -= 1;
      } else {
        restRunning = false;
        restExerciseName = null;
        _restTicker?.cancel();
        PlatformTimerBridge.finish();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void skipRest() {
    restRemainingSeconds = 0;
    restRunning = false;
    restExerciseName = null;
    _restTicker?.cancel();
    PlatformTimerBridge.finish();
    notifyListeners();
  }

  void finishWorkout({String note = ''}) {
    if (!workoutStarted && !workoutDraft) return;
    final now = DateTime.now();
    history.insert(
      0,
      WorkoutRecord(
        id: 'history-${now.microsecondsSinceEpoch}',
        name: workoutName,
        date: now,
        startTime:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        durationSeconds: currentElapsed,
        volume: workoutVolume,
        effectiveSets: workout
            .expand((item) => item.sets)
            .where((set) => set.completed && set.type != 'technique')
            .length,
        note: note,
        exerciseIds: workout.map((item) => item.exerciseId).toList(),
        prs: livePrEnabled ? const ['本次训练实时 PR'] : const [],
        exercises: workout.map((item) => item.copy()).toList(),
      ),
    );
    workoutStarted = false;
    workoutPaused = false;
    workoutDraft = false;
    workoutCompleted = true;
    liveWorkoutVisible = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    restRunning = false;
    restRemainingSeconds = 0;
    restExerciseName = null;
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    PlatformTimerBridge.finish();
    notifyListeners();
  }

  void addSet(WorkoutExercise exercise) {
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    exercise.sets.add(
      WorkoutSet(
        id: 'set-${DateTime.now().microsecondsSinceEpoch}',
        type: last?.type ?? 'work',
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 8,
        restSeconds: exercise.restSeconds,
      ),
    );
    notifyListeners();
  }

  void toggleBatchMode() {
    batchMode = !batchMode;
    if (!batchMode) selectedSetIds.clear();
    notifyListeners();
  }

  void toggleSetSelection(WorkoutSet set) {
    if (set.completed) return;
    if (!selectedSetIds.add(set.id)) selectedSetIds.remove(set.id);
    notifyListeners();
  }

  void batchUpdate({String? type, double? weight, int? reps}) {
    for (final item in workout.expand((item) => item.sets)) {
      if (!selectedSetIds.contains(item.id) || item.completed) continue;
      if (type != null) item.type = type;
      if (weight != null) item.weight = weight;
      if (reps != null) item.reps = reps;
    }
    selectedSetIds.clear();
    batchMode = false;
    notifyListeners();
  }

  void toggleSuperset(WorkoutExercise exercise) {
    final current = exercise.supersetId;
    exercise.supersetId = current == null
        ? 'superset-${DateTime.now().microsecondsSinceEpoch}'
        : null;
    notifyListeners();
  }

  void moveExercise(WorkoutExercise exercise, int direction) {
    final index = workout.indexOf(exercise);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= workout.length) return;
    final item = workout.removeAt(index);
    workout.insert(target, item);
    notifyListeners();
  }

  void addExercise(String id) {
    if (workout.any((item) => item.exerciseId == id)) return;
    workout.add(
      _makeWorkout(id, 'we-${DateTime.now().microsecondsSinceEpoch}'),
    );
    workoutDraft = true;
    notifyListeners();
  }

  void addCustomExercise({
    required String name,
    required String englishName,
    required String equipment,
    required String muscle,
    required String cue,
  }) {
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    customExercises.add(
      Exercise(
        id: id,
        name: name,
        englishName: englishName.isEmpty ? name : englishName,
        family: '自定义',
        muscle: muscle.isEmpty ? '未分类' : muscle,
        secondary: '无',
        equipment: equipment.isEmpty ? '自定义器械' : equipment,
        camera: '待设置',
        cue: cue.isEmpty ? '根据你的动作目标设置提示' : cue,
      ),
    );
    notifyListeners();
  }

  void saveResource({
    required String exerciseId,
    required String scope,
    required String note,
    required String link,
  }) {
    exerciseResources.putIfAbsent(exerciseId, () => {});
    exerciseResources[exerciseId]![scope] = ExerciseResource(
      note: note,
      link: link,
    );
    notifyListeners();
  }

  ExerciseResource resourceFor(String exerciseId, String scope) =>
      exerciseResources[exerciseId]?[scope] ??
      const ExerciseResource(note: '', link: '');

  void deleteRecord(WorkoutRecord record) {
    history.remove(record);
    notifyListeners();
  }

  void updateRecordNote(WorkoutRecord record, String note) {
    final index = history.indexOf(record);
    if (index < 0) return;
    history[index] = WorkoutRecord(
      id: record.id,
      name: record.name,
      date: record.date,
      startTime: record.startTime,
      durationSeconds: record.durationSeconds,
      volume: record.volume,
      effectiveSets: record.effectiveSets,
      note: note,
      exerciseIds: record.exerciseIds,
      prs: record.prs,
      exercises: record.exercises.map((item) => item.copy()).toList(),
    );
    notifyListeners();
  }

  void replaceExercise(String oldId, String nextId) {
    final target = workout.firstWhere((item) => item.id == oldId);
    target.exerciseId = nextId;
    notifyListeners();
  }

  void removeExercise(WorkoutExercise exercise) {
    workout.remove(exercise);
    notifyListeners();
  }

  void saveRoutine(String name, String folder) {
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        folder: folder,
        exercises: workout
            .map((item) => item.copy(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void saveRoutineFromExerciseIds(String name, List<String> exerciseIds) {
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        folder: '官方计划',
        exercises: [
          for (var index = 0; index < exerciseIds.length; index++)
            _makeWorkout(
              exerciseIds[index],
              'official-$index-${exerciseIds[index]}',
            ),
        ],
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void renameRoutine(Routine routine, String name) {
    routine.name = name.trim().isEmpty ? routine.name : name.trim();
    routine.updatedAt = DateTime.now();
    notifyListeners();
  }

  void deleteRoutine(Routine routine) {
    routines.remove(routine);
    notifyListeners();
  }

  void startRoutine(Routine routine) {
    startWorkout(source: routine.exercises, name: routine.name);
    openLiveWorkout();
  }

  void moveRoutine(Routine routine, String folder) {
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routine.folder = folder;
    routine.updatedAt = DateTime.now();
    notifyListeners();
  }

  void addRoutineFolder(String folder) {
    final value = folder.trim();
    if (value.isEmpty || routineFolders.contains(value)) return;
    routineFolders.add(value);
    notifyListeners();
  }

  void schedule(DateTime date, String label) {
    final value =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (!scheduled.contains(value)) scheduled.add(value);
    scheduledLabels[value] = label;
    notifyListeners();
  }

  void reschedule(String date, String label) {
    scheduled.add(date);
    scheduledLabels[date] = label;
    notifyListeners();
  }

  void unschedule(String date) {
    scheduled.remove(date);
    scheduledLabels.remove(date);
    notifyListeners();
  }

  void newConversation() {
    _saveActiveConversation();
    final id = 'conversation-${DateTime.now().microsecondsSinceEpoch}';
    activeConversationId = id;
    chat
      ..clear()
      ..add(
        ChatMessage(
          id: 'welcome-$id',
          role: 'assistant',
          body: '新的对话已开始。你想了解哪个训练问题？',
        ),
      );
    conversations.add(
      AiConversation(
        id: id,
        title: '新对话',
        messages: List<ChatMessage>.from(chat),
      ),
    );
    notifyListeners();
  }

  void selectConversation(String id) {
    if (id == activeConversationId) return;
    _saveActiveConversation();
    final selected = conversations.firstWhere((item) => item.id == id);
    activeConversationId = id;
    chat
      ..clear()
      ..addAll(selected.messages);
    notifyListeners();
  }

  void deleteConversation(String id) {
    if (conversations.length <= 1) {
      newConversation();
      return;
    }
    conversations.removeWhere((item) => item.id == id);
    if (id == activeConversationId) {
      final selected = conversations.first;
      activeConversationId = selected.id;
      chat
        ..clear()
        ..addAll(selected.messages);
    }
    notifyListeners();
  }

  void _saveActiveConversation() {
    AiConversation? current;
    for (final item in conversations) {
      if (item.id == activeConversationId) {
        current = item;
        break;
      }
    }
    if (current == null) return;
    current.messages = List<ChatMessage>.from(chat);
    final latestUser = chat.lastWhere(
      (item) => item.role == 'user',
      orElse: () => chat.first,
    );
    if (latestUser.role == 'user') {
      current.title = latestUser.body.length > 16
          ? '${latestUser.body.substring(0, 16)}…'
          : latestUser.body;
    }
  }

  Future<void> pickVideo() async {
    mediaPicking = true;
    mediaError = null;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        mediaError = '已取消选择视频。';
        recognitionStatus = RecognitionStatus.idle;
      } else {
        final file = result.files.single;
        final extension = (file.extension ?? '').toLowerCase();
        if (!['mp4', 'mov', 'm4v', 'webm'].contains(extension)) {
          mediaError = '仅支持 MP4、MOV、M4V 或 WebM 视频。';
          recognitionStatus = RecognitionStatus.idle;
        } else {
          selectedMediaPath = file.path;
          selectedMediaName = file.name;
          selectedMediaBytes = file.size;
          recognitionStatus = RecognitionStatus.ready;
        }
      }
    } catch (_) {
      mediaError = '文件选择失败，请重试或载入演示视频。';
      recognitionStatus = RecognitionStatus.idle;
    } finally {
      mediaPicking = false;
      notifyListeners();
    }
  }

  void chooseDemoVideo() {
    selectedMediaPath = 'mock://kilo/demo-squat.mp4';
    selectedMediaName = 'KILO 演示深蹲.mp4';
    selectedMediaBytes = 8 * 1024 * 1024;
    mediaError = null;
    recognitionStatus = RecognitionStatus.ready;
    recognitionProgress = 0;
    notifyListeners();
  }

  void startRecognition() {
    if (recognitionStatus != RecognitionStatus.ready) return;
    recognitionStatus = RecognitionStatus.processing;
    recognitionProgress = 0.08;
    _recognitionTicker?.cancel();
    _recognitionTicker = Timer.periodic(const Duration(milliseconds: 180), (_) {
      recognitionProgress = (recognitionProgress + .1).clamp(0, 1);
      if (recognitionProgress >= 1) {
        recognitionProgress = 1;
        recognitionStatus = RecognitionStatus.processing;
        recognitionApi
            .analyze(
              exerciseId: recognitionExerciseId,
              camera: recognitionCamera,
              scenario: scenario,
            )
            .then((result) {
              recognitionResult = result;
              recognitionStatus = result.status;
              notifyListeners();
            });
        _recognitionTicker?.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void resetRecognition() {
    recognitionStatus = RecognitionStatus.idle;
    recognitionProgress = 0;
    analysisAttached = false;
    recognitionResult = null;
    selectedMediaPath = null;
    selectedMediaName = null;
    selectedMediaBytes = null;
    mediaError = null;
    notifyListeners();
  }

  void saveRecognitionCue() {
    savedCue = true;
    notifyListeners();
  }

  void approveAiData(bool value) {
    aiUseTrainingData = value;
    aiConsentSeen = true;
    notifyListeners();
  }

  Future<void> sendChat(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || aiTyping) return;
    chat.add(
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        body: trimmed,
      ),
    );
    aiTyping = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    aiTyping = false;
    final offline = scenario == 'offline';
    final noEvidence = scenario == 'empty';
    CoachAnswer? remoteAnswer;
    if (!offline && !noEvidence && aiBaseUrl.trim().isNotEmpty) {
      try {
        remoteAnswer = await HttpCoachApi(
          baseUrl: aiBaseUrl.trim(),
        ).answer(prompt: trimmed, includeTrainingSummary: aiUseTrainingData);
      } catch (_) {
        remoteAnswer = null;
      }
    }
    final answerBody = remoteAnswer?.body;
    chat.add(
      ChatMessage(
        id: 'answer-${DateTime.now().microsecondsSinceEpoch}',
        role: 'assistant',
        body: answerBody?.isNotEmpty == true
            ? answerBody!
            : offline
            ? '当前处于离线状态。你仍可查看已缓存的训练摘要，联网后再获取新的知识库引用。'
            : noEvidence
            ? '我没有找到足够的证据支持确定建议。可以补充动作、目标或最近训练数据后再问一次。'
            : aiUseTrainingData
            ? '根据你最近的训练记录，下一次卧推可以先尝试 82.5 kg × 8。若第一组 RPE 超过 9，保留当前重量并减少一组。'
            : '下一次卧推建议先保持当前重量，记录 RPE 后再决定是否加重。若你希望我引用个人记录，请先开启训练摘要授权。',
        citations:
            remoteAnswer?.citations ??
            (offline || noEvidence
                ? const []
                : const [
                    'NSCA · Resistance Training Guidelines',
                    'KILO 训练记录摘要',
                  ]),
      ),
    );
    _saveActiveConversation();
    notifyListeners();
  }

  void resetDemo() {
    workoutStarted = false;
    workoutPaused = false;
    workoutCompleted = false;
    liveWorkoutVisible = false;
    workoutDraft = false;
    workoutElapsedSeconds = 0;
    workout
      ..clear()
      ..addAll([
        WorkoutExercise(
          id: 'we-bench',
          exerciseId: 'bench_press',
          restSeconds: 150,
          sets: [
            WorkoutSet(
              id: 'bench-warm-1',
              type: 'warmup',
              weight: 20,
              reps: 10,
              completed: true,
            ),
            WorkoutSet(
              id: 'bench-warm-2',
              type: 'warmup',
              weight: 50,
              reps: 8,
              completed: true,
            ),
            WorkoutSet(id: 'bench-work-1'),
            WorkoutSet(id: 'bench-work-2'),
            WorkoutSet(id: 'bench-work-3'),
          ],
        ),
        WorkoutExercise(
          id: 'we-row',
          exerciseId: 'chest_supported_row',
          restSeconds: 120,
          collapsed: true,
          sets: [
            WorkoutSet(id: 'row-1', type: 'warmup', weight: 35, reps: 10),
            WorkoutSet(id: 'row-2', weight: 62.5, reps: 10),
            WorkoutSet(id: 'row-3', weight: 62.5, reps: 10),
          ],
        ),
        WorkoutExercise(
          id: 'we-lateral',
          exerciseId: 'lateral_raise',
          restSeconds: 75,
          collapsed: true,
          sets: [
            WorkoutSet(id: 'lat-1', weight: 10, reps: 12),
            WorkoutSet(id: 'lat-2', weight: 10, reps: 12),
            WorkoutSet(id: 'lat-3', type: 'drop', weight: 8, reps: 15),
          ],
        ),
      ]);
    conversations
      ..clear()
      ..add(
        AiConversation(
          id: activeConversationId,
          title: '训练建议',
          messages: List<ChatMessage>.from(chat),
        ),
      );
    notifyListeners();
  }

  @override
  void dispose() {
    PlatformTimerBridge.setRestSkippedHandler(null);
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    _recognitionTicker?.cancel();
    super.dispose();
  }
}
