import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'account_membership.dart';
import 'ai_api.dart';
import 'models.dart';
import 'recognition_api.dart';

const String defaultCoachApiBaseUrl = String.fromEnvironment(
  'KILO_API_BASE_URL',
  defaultValue: 'https://magnitude-detail-pipe-cake.trycloudflare.com',
);

enum ExerciseNameLanguage { chinese, english }

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

  static Future<void> startWorkout({
    required int elapsedSeconds,
    required String workoutName,
  }) async {
    try {
      await _channel.invokeMethod<void>('startWorkout', {
        'elapsedSeconds': elapsedSeconds,
        'workoutName': workoutName,
      });
    } on MissingPluginException {
      // The native foreground service is optional in widget tests and previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when the system capability is unavailable.
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

  static Future<void> clearRest() async {
    try {
      await _channel.invokeMethod<void>('clearRest');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }
}

class AppController extends ChangeNotifier {
  AppController({
    AccountService? accountService,
    RecognitionApi? recognitionApi,
    this.coachApi,
  }) : accountService = accountService ?? AccountService(),
       recognitionApi = recognitionApi ?? UnconfiguredRecognitionApi() {
    _seed();
    PlatformTimerBridge.setRestSkippedHandler(skipRest);
    this.accountService.addListener(_handleAccountChanged);
  }

  final AccountService accountService;
  final RecognitionApi recognitionApi;
  final CoachApi? coachApi;
  HttpCoachApi? _defaultCoachApi;
  String? _defaultCoachApiBaseUrl;

  AccountUser? get currentUser => accountService.currentUser;
  bool get isAuthenticated => accountService.isAuthenticated;
  bool get isAdmin => accountService.isAdmin;
  EntitlementSnapshot? get entitlements => accountService.entitlements;
  int get aiRemaining => accountService.aiRemaining;
  int get recognitionRemaining => accountService.recognitionRemaining;

  void _handleAccountChanged() => notifyListeners();

  AuthResult loginWithPhone(String identifier, {String? password}) {
    _defaultCoachApi?.clearSession();
    return accountService.loginWithPhone(identifier, password: password);
  }

  AuthResult loginWithApple() => accountService.loginWithApple();

  AuthResult loginWithGoogle() => accountService.loginWithGoogle();

  void logout() {
    _defaultCoachApi?.clearSession();
    accountService.logout();
  }

  AccountResult<EntitlementSnapshot> grantMembership({
    required String identifier,
    required MembershipPlan plan,
  }) => accountService.grantMembership(identifier: identifier, plan: plan);

  RedemptionCode generateRedemptionCode({required MembershipPlan plan}) =>
      accountService.generateRedemptionCode(plan: plan);

  AccountResult<EntitlementSnapshot> redeemCode(String code) =>
      accountService.redeemCode(code);

  PageId page = PageId.today;
  TrainView trainView = TrainView.workout;
  AiView aiView = AiView.chat;
  bool workoutStarted = false;
  bool workoutTimerStarted = false;
  bool workoutPaused = false;
  DateTime? workoutStartedAt;
  int workoutElapsedSeconds = 0;
  bool workoutDraft = false;
  bool workoutCompleted = false;
  bool liveWorkoutVisible = false;
  bool completionBurstActive = false;
  int completionBurstId = 0;
  String? completionBurstSetId;

  /// Whether the current session was started without a prescribed plan.
  /// Free-training sets intentionally keep [WorkoutSet.plannedWeight] null.
  bool freeWorkout = false;
  String workoutName = '自由训练';
  String workoutNote = '';
  final List<WorkoutExercise> workout = [];
  final List<Routine> routines = [];
  final List<String> routineFolders = [];
  final List<WorkoutRecord> history = [];
  final List<Exercise> customExercises = [];
  final Map<String, Map<String, ExerciseResource>> exerciseResources = {};
  String aiBaseUrl = defaultCoachApiBaseUrl;
  String? selectedMediaPath;
  String? selectedMediaName;
  int? selectedMediaBytes;
  String? mediaError;
  bool mediaPicking = false;
  RecognitionResult? recognitionResult;
  final List<String> scheduled = [];
  int defaultRestSeconds = 120;
  bool rpeTrackingEnabled = true;
  bool livePrEnabled = true;
  String selectedExerciseId = 'bench_press';
  ExerciseNameLanguage exerciseNameLanguage = ExerciseNameLanguage.chinese;
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
  final List<ChatMessage> chat = [];
  final List<AiConversation> conversations = [];
  String activeConversationId = 'conversation-main';
  String scenario = 'normal';
  bool appleWatch = false;
  bool liveActivity = true;
  bool androidNotifications = false;
  bool batchMode = false;
  final Set<String> selectedSetIds = <String>{};
  String? selectedPlanFolder;
  final Map<String, String> scheduledLabels = {};
  double aiScrollOffset = 0;
  int restRemainingSeconds = 0;
  bool restRunning = false;
  String? restExerciseName;
  Timer? _workoutTicker;
  Timer? _restTicker;
  Timer? _recognitionTicker;
  Timer? _completionBurstTimer;
  QuotaReservation? _recognitionReservation;

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

  String displayExerciseName(Exercise exercise) =>
      exerciseNameLanguage == ExerciseNameLanguage.english
      ? exercise.englishName
      : exercise.name;

  void setExerciseNameLanguage(ExerciseNameLanguage value) {
    if (exerciseNameLanguage == value) return;
    exerciseNameLanguage = value;
    notifyListeners();
  }

  int get completedSets =>
      workout.expand((item) => item.sets).where((set) => set.completed).length;
  int get totalSets => workout.expand((item) => item.sets).length;
  double get completion => totalSets == 0 ? 0 : completedSets / totalSets;

  /// Returns the latest real history set for an exercise and index.
  ///
  /// Records are newest first. An exact completed index wins; if a recent
  /// record has no matching index, the most recent completed set for the same
  /// exercise is used as a conservative fallback. Planned values are never
  /// consulted here.
  WorkoutSet? previousSetFor(String exerciseId, int setIndex) {
    WorkoutSet? fallback;
    for (final record in history) {
      for (final exercise in record.exercises) {
        if (exercise.exerciseId != exerciseId) continue;
        if (setIndex < exercise.sets.length) {
          final exact = exercise.sets[setIndex];
          if (exact.completed) return exact;
        }
        for (final set in exercise.sets) {
          if (set.completed) return fallback ?? set;
        }
      }
    }
    return fallback;
  }

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

  /// The product starts with a clean local workspace. Catalog exercises and
  /// official static plans remain available, while user workouts, routines,
  /// history, schedules and conversations are created only through actions.
  void _seed() {}

  WorkoutExercise _makeWorkout(String exerciseId, String id) => WorkoutExercise(
    id: id,
    exerciseId: exerciseId,
    sets: List.generate(3, (index) {
      final weight = index == 0 ? 20.0 : 30.0;
      return WorkoutSet(
        id: '$id-set-$index',
        weight: weight,
        plannedWeight: weight,
      );
    }),
  );

  WorkoutExercise createWorkoutExercise(String exerciseId, String id) =>
      _makeWorkout(exerciseId, id);

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

  void startWorkout({
    List<WorkoutExercise>? source,
    String? name,
    bool autoStartTimer = true,
  }) {
    freeWorkout = source == null;
    if (source == null && workoutCompleted) {
      workout.clear();
    }
    if (source != null) {
      workout
        ..clear()
        ..addAll(
          source.map(
            (item) => item.copyForWorkout(newId: 'session-${item.id}'),
          ),
        );
      for (final exercise in workout) {
        for (final set in exercise.sets) {
          set.completed = false;
        }
      }
    }
    workoutName = name ?? (freeWorkout ? '自由训练' : workoutName);
    workoutDraft = workout.isEmpty;
    workoutCompleted = false;
    workoutStarted = true;
    workoutTimerStarted = false;
    workoutPaused = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    _workoutTicker?.cancel();
    _workoutTicker = null;
    if (autoStartTimer) {
      beginWorkoutTimer();
    } else {
      notifyListeners();
    }
  }

  void beginWorkoutTimer() {
    if (!workoutStarted || workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutPaused = false;
    workoutStartedAt = DateTime.now();
    _workoutTicker?.cancel();
    _workoutTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    PlatformTimerBridge.startWorkout(
      elapsedSeconds: 0,
      workoutName: workoutName,
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
    if (!workoutStarted || !workoutTimerStarted) return;
    workoutElapsedSeconds = currentElapsed;
    workoutPaused = !workoutPaused;
    workoutStartedAt = workoutPaused ? null : DateTime.now();
    if (workoutPaused) {
      PlatformTimerBridge.pause();
    } else {
      PlatformTimerBridge.startWorkout(
        elapsedSeconds: workoutElapsedSeconds,
        workoutName: workoutName,
      );
    }
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
    if (!workoutTimerStarted) return;
    set.completed = !set.completed;
    if (set.completed) {
      triggerCompletionBurst(set.id);
      restRemainingSeconds = set.restSeconds > 0
          ? set.restSeconds
          : parent.restSeconds;
      if (restRemainingSeconds > 0) {
        startRest(
          exercise: displayExerciseName(findExercise(parent.exerciseId)),
          seconds: restRemainingSeconds,
        );
      } else {
        restRemainingSeconds = 0;
        restRunning = false;
        restExerciseName = null;
        _restTicker?.cancel();
        PlatformTimerBridge.clearRest();
      }
    } else {
      restRemainingSeconds = 0;
      restRunning = false;
      restExerciseName = null;
      _restTicker?.cancel();
      PlatformTimerBridge.clearRest();
    }
    notifyListeners();
  }

  void triggerCompletionBurst([String? setId]) {
    completionBurstId++;
    completionBurstActive = true;
    completionBurstSetId = setId;
    _completionBurstTimer?.cancel();
    _completionBurstTimer = Timer(const Duration(milliseconds: 800), () {
      completionBurstActive = false;
      completionBurstSetId = null;
      notifyListeners();
    });
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
    if (seconds <= 0) {
      restRemainingSeconds = 0;
      restRunning = false;
      restExerciseName = null;
      _restTicker?.cancel();
      PlatformTimerBridge.clearRest();
      notifyListeners();
      return;
    }
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
        PlatformTimerBridge.clearRest();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void updateExerciseRest(WorkoutExercise exercise, int seconds) {
    final value = seconds.clamp(0, 600).toInt();
    exercise.restSeconds = value;
    if (freeWorkout) {
      for (final set in exercise.sets) {
        if (!set.completed) set.restSeconds = value;
      }
    }
    notifyListeners();
  }

  void skipRest() {
    restRemainingSeconds = 0;
    restRunning = false;
    restExerciseName = null;
    _restTicker?.cancel();
    PlatformTimerBridge.clearRest();
    notifyListeners();
  }

  WorkoutRecord? finishWorkout({
    String note = '',
    bool saveAsRoutine = false,
    String? routineName,
  }) {
    if (!workoutStarted && !workoutDraft) return null;
    final now = DateTime.now();
    final wasFreeWorkout = freeWorkout;
    final historySnapshot = workout.map((item) => item.copy()).toList();
    final record = WorkoutRecord(
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
      prs: const [],
      exercises: historySnapshot,
    );
    history.insert(0, record);
    // A valid completed session grants one recognition credit. The service
    // tracks record IDs, so opening/saving the same summary cannot reward it
    // twice. Empty sessions do not count as valid training.
    if (record.effectiveSets > 0) {
      accountService.rewardWorkoutCompleted(record.id, valid: true);
    }
    if (wasFreeWorkout && saveAsRoutine && workout.isNotEmpty) {
      final baseName = routineName?.trim().isNotEmpty == true
          ? routineName!.trim()
          : _defaultFreeRoutineName(now);
      var finalName = baseName;
      var suffix = 2;
      while (routines.any((routine) => routine.name == finalName)) {
        finalName = '$baseName ($suffix)';
        suffix++;
      }
      final exercises = historySnapshot.map((item) {
        final planExercise = item.copyForPlan(
          newId: 'routine-${DateTime.now().microsecondsSinceEpoch}-${item.id}',
        );
        for (final set in planExercise.sets) {
          set.plannedWeight = set.weight;
          set.completed = false;
          set.failed = false;
        }
        return planExercise;
      }).toList();
      if (!routineFolders.contains('自定义')) routineFolders.add('自定义');
      routines.insert(
        0,
        Routine(
          id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
          name: finalName,
          folder: '自定义',
          exercises: exercises,
          updatedAt: now,
        ),
      );
    }
    workoutStarted = false;
    workoutTimerStarted = false;
    workoutPaused = false;
    workoutDraft = false;
    workoutCompleted = true;
    liveWorkoutVisible = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    freeWorkout = false;
    restRunning = false;
    restRemainingSeconds = 0;
    restExerciseName = null;
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    PlatformTimerBridge.finish();
    notifyListeners();
    return record;
  }

  String _defaultFreeRoutineName(DateTime date) =>
      '自由训练 ${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void addSet(WorkoutExercise exercise) {
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    final firstFreeSet = freeWorkout && last == null;
    exercise.sets.add(
      WorkoutSet(
        id: 'set-${DateTime.now().microsecondsSinceEpoch}',
        type: last?.type ?? 'work',
        weight: firstFreeSet ? 0 : last?.weight ?? 0,
        plannedWeight: freeWorkout ? null : last?.plannedWeight ?? last?.weight,
        reps: firstFreeSet ? 0 : last?.reps ?? 8,
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
    final item = freeWorkout
        ? WorkoutExercise(
            id: 'we-${DateTime.now().microsecondsSinceEpoch}',
            exerciseId: id,
            sets: <WorkoutSet>[],
            restSeconds: 0,
          )
        : _makeWorkout(id, 'we-${DateTime.now().microsecondsSinceEpoch}');
    workout.add(item);
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
            .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Persists a draft composer in one transaction. The draft itself remains
  /// outside [routines] until this method is called, so cancelling a composer
  /// cannot leave an empty routine behind.
  void saveRoutineFromDraft(
    String name,
    List<WorkoutExercise> exercises, {
    String folder = '自定义',
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || exercises.isEmpty) return;
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: trimmedName,
        folder: folder,
        exercises: exercises
            .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Commits a full-page editor draft only after the user taps save. The
  /// original routine is never mutated while the draft route is open.
  void updateRoutineFromDraft(Routine original, Routine draft) {
    final index = routines.indexOf(original);
    if (index < 0) return;
    final target = routines[index];
    target.name = draft.name.trim().isEmpty ? target.name : draft.name.trim();
    target.folder = draft.folder;
    target.exercises = draft.exercises
        .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
        .toList();
    target.updatedAt = DateTime.now();
    notifyListeners();
  }

  /// Updates the prescribed weight in a plan and keeps its initial live
  /// workout value in sync. Live workout edits only touch [WorkoutSet.weight].
  void updatePlannedWeight(WorkoutSet set, double value) {
    set.plannedWeight = value;
    set.weight = value;
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
    if (chat.isEmpty) {
      current.title = '新对话';
      return;
    }
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
      mediaError = '文件选择失败，请重试。';
      recognitionStatus = RecognitionStatus.idle;
    } finally {
      mediaPicking = false;
      notifyListeners();
    }
  }

  void startRecognition() {
    if (recognitionStatus != RecognitionStatus.ready) return;
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    recognitionStatus = RecognitionStatus.processing;
    recognitionProgress = 0.08;
    _recognitionTicker?.cancel();
    _recognitionTicker = Timer.periodic(const Duration(milliseconds: 180), (_) {
      recognitionProgress = (recognitionProgress + .1).clamp(0, 1);
      if (recognitionProgress >= 1) {
        recognitionProgress = 1;
        recognitionStatus = RecognitionStatus.processing;
        _submitRecognition();
        _recognitionTicker?.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _submitRecognition() {
    // The local unconfigured adapter must never consume a credit. A real
    // adapter reserves immediately before its network submission and returns
    // the credit when the request fails.
    if (recognitionApi is! UnconfiguredRecognitionApi && isAuthenticated) {
      _recognitionReservation = accountService.reserveRecognition();
      if (_recognitionReservation == null) {
        recognitionStatus = RecognitionStatus.error;
        recognitionResult = const RecognitionResult(
          status: RecognitionStatus.error,
          confidence: 0,
          repetitions: 0,
          summary: '识别额度已用完，请等待每周补充或完成一次有效训练。',
          error: 'quota_exhausted',
        );
        notifyListeners();
        return;
      }
    }
    recognitionApi
        .analyze(
          exerciseId: recognitionExerciseId,
          camera: recognitionCamera,
          scenario: scenario,
        )
        .then((result) {
          final succeeded =
              result.error == null &&
              result.status != RecognitionStatus.error &&
              result.status != RecognitionStatus.offline;
          if (succeeded) {
            _recognitionReservation?.commit();
          } else {
            _recognitionReservation?.rollback();
          }
          _recognitionReservation = null;
          recognitionResult = result;
          recognitionStatus = result.status;
          notifyListeners();
        })
        .catchError((Object _) {
          _recognitionReservation?.rollback();
          _recognitionReservation = null;
          recognitionStatus = RecognitionStatus.error;
          recognitionResult = const RecognitionResult(
            status: RecognitionStatus.error,
            confidence: 0,
            repetitions: 0,
            summary: '识别服务暂时不可用，请稍后重试。',
            error: 'service_error',
          );
          notifyListeners();
        });
  }

  void resetRecognition() {
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
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

  Future<CoachApi> _activeCoachApi() async {
    final injected = coachApi;
    if (injected != null) return injected;

    final baseUrl = aiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const CoachApiException('coach_base_url_missing');
    }
    if (_defaultCoachApi == null || _defaultCoachApiBaseUrl != baseUrl) {
      _defaultCoachApi = HttpCoachApi(baseUrl: baseUrl);
      _defaultCoachApiBaseUrl = baseUrl;
    }
    final api = _defaultCoachApi!;
    if (!api.hasSession) {
      final identifier = currentUser?.identifier;
      if (identifier != '123' && identifier != '1234') {
        throw const CoachApiException('coach_account_not_synced');
      }
      await api.signIn(identifier: identifier!, password: identifier);
    }
    return api;
  }

  String _buildAiTrainingSummary() {
    if (history.isEmpty) return '用户尚无已完成训练记录。';
    final lines = <String>[];
    for (final record in history.take(5)) {
      lines.add(
        '${record.date.toIso8601String().split('T').first} ${record.name}：'
        '${record.durationSeconds ~/ 60} 分钟，训练量 ${record.volume.toStringAsFixed(1)} kg，'
        '有效组 ${record.effectiveSets}。',
      );
      for (final exercise in record.exercises.take(8)) {
        final completed = exercise.sets.where((set) => set.completed).take(8);
        if (completed.isEmpty) continue;
        final sets = completed
            .map(
              (set) =>
                  '${set.weight.toStringAsFixed(1)} kg × ${set.reps}'
                  '${set.rpe == null ? '' : '，RPE ${set.rpe!.toStringAsFixed(1)}'}',
            )
            .join('；');
        lines.add('${findExercise(exercise.exerciseId).name}：$sets');
      }
    }
    return lines.join('\n');
  }

  Future<CoachAnswer> _requestCoachAnswer(String prompt) async {
    final requestsPlan = _isAiPlanRequest(prompt);
    Future<CoachAnswer> request() async {
      final api = await _activeCoachApi();
      return api.answer(
        prompt: prompt,
        includeTrainingSummary: aiUseTrainingData,
        trainingSummary: aiUseTrainingData ? _buildAiTrainingSummary() : null,
        exerciseCatalog: requestsPlan ? _aiExerciseCatalog() : const [],
      );
    }

    try {
      return await request();
    } on CoachApiException catch (error) {
      // HttpCoachApi clears an expired session on 401. Re-authenticate once so
      // a long-lived app session does not force the user to resend the prompt.
      if (coachApi == null && error.code == 'coach_http_401') {
        return request();
      }
      rethrow;
    }
  }

  bool _isAiPlanRequest(String prompt) {
    final normalized = prompt.toLowerCase();
    final asksToCreate = RegExp(
      r'(生成|制定|安排|创建|做一份|设计|帮我做|帮我排|generate|create|build|make)',
    ).hasMatch(normalized);
    final mentionsPlan = RegExp(
      r'(训练计划|训练方案|健身计划|健身方案|月计划|周计划|workout plan|training plan)',
    ).hasMatch(normalized);
    return asksToCreate && mentionsPlan;
  }

  List<Map<String, String>> _aiExerciseCatalog() {
    final selected = <Exercise>[];
    final seenGroups = <String>{};
    for (final exercise in allExercises) {
      final key = '${exercise.equipment}|${exercise.muscle}';
      if (selected.length < 80 &&
          (curatedCatalog.contains(exercise) || seenGroups.add(key))) {
        selected.add(exercise);
      }
      if (selected.length >= 80) break;
    }
    return [
      for (final exercise in selected)
        {
          'id': exercise.id,
          'name': exercise.name,
          'equipment': exercise.equipment,
          'muscle': exercise.muscle,
        },
    ];
  }

  void saveAiPlan(AiPlanDraft plan, {required bool scheduleCalendar}) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (var sessionIndex = 0;
        sessionIndex < plan.sessions.length;
        sessionIndex++) {
      final session = plan.sessions[sessionIndex];
      final validIds = session.exerciseIds
          .where((id) => allExercises.any((exercise) => exercise.id == id))
          .toList();
      if (validIds.isEmpty) continue;
      final routineName = '${plan.title} · ${session.name}';
      if (!routineFolders.contains('AI 生成')) routineFolders.add('AI 生成');
      routines.add(
        Routine(
          id: 'ai-routine-$stamp-$sessionIndex',
          name: routineName,
          folder: 'AI 生成',
          exercises: [
            for (var exerciseIndex = 0;
                exerciseIndex < validIds.length;
                exerciseIndex++)
              _makeWorkout(
                validIds[exerciseIndex],
                'ai-$stamp-$sessionIndex-$exerciseIndex',
              ),
          ],
          updatedAt: DateTime.now(),
        ),
      );
      if (!scheduleCalendar) continue;
      for (var week = 0; week < plan.weeks; week++) {
        final dayOffset = session.dayOffset.clamp(0, 6).toInt();
        schedule(
          DateTime.now().add(
            Duration(days: dayOffset + week * 7),
          ),
          routineName,
        );
      }
    }
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
    CoachAnswer? remoteAnswer;
    String? serviceError;
    QuotaReservation? aiReservation;
    if (scenario == 'offline') {
      serviceError = '当前处于离线状态，AI 服务暂不可用。';
    } else if (scenario == 'empty') {
      serviceError = '暂未找到可用训练证据，请先完成训练或补充数据。';
    } else if (coachApi == null && aiBaseUrl.trim().isEmpty) {
      serviceError = 'AI 服务未配置，请在设置中配置 Coach 服务后重试。';
    } else {
      if (isAuthenticated) {
        aiReservation = accountService.reserveAi();
        if (aiReservation == null) {
          serviceError =
              '\u4eca\u65e5 AI \u989d\u5ea6\u5df2\u7528\u5b8c\uff0c\u660e\u5929\u6216\u5f00\u901a\u4f1a\u5458\u540e\u6062\u590d\u3002';
        }
      }
      if (serviceError == null) {
        try {
          remoteAnswer = await _requestCoachAnswer(trimmed);
          if (remoteAnswer.body.trim().isNotEmpty) {
            aiReservation?.commit();
          } else {
            aiReservation?.rollback();
            serviceError =
                '\u0041\u0049 \u670d\u52a1\u672a\u8fd4\u56de\u53ef\u7528\u56de\u7b54\u3002';
          }
        } on CoachApiException catch (error) {
          aiReservation?.rollback();
          serviceError = error.code == 'coach_account_not_synced'
              ? '当前账号尚未同步到云端，请先使用测试账号 123 或 1234。'
              : 'AI 服务暂时不可用，请稍后重试。';
        } catch (_) {
          aiReservation?.rollback();
          serviceError = 'AI 服务暂时不可用，请稍后重试。';
        }
      }
    }
    aiTyping = false;
    chat.add(
      ChatMessage(
        id: 'answer-${DateTime.now().microsecondsSinceEpoch}',
        role: 'assistant',
        body: remoteAnswer?.body.isNotEmpty == true
            ? remoteAnswer!.body
            : serviceError ?? 'AI 服务未返回可用回答。',
        citations: remoteAnswer?.citations ?? const [],
        plan: remoteAnswer?.plan,
      ),
    );
    _saveActiveConversation();
    notifyListeners();
  }

  @override
  void dispose() {
    accountService.removeListener(_handleAccountChanged);
    PlatformTimerBridge.setRestSkippedHandler(null);
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    _recognitionTicker?.cancel();
    _completionBurstTimer?.cancel();
    super.dispose();
  }
}
