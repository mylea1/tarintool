import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_membership.dart';
import 'app_localizations.dart';
import 'ai_api.dart';
import 'natural_workout_parser.dart';
import 'models.dart';
import 'recognition_api.dart';
import 'workout_history_persistence.dart';

const String defaultCoachApiBaseUrl = String.fromEnvironment(
  'KILO_API_BASE_URL',
  defaultValue: 'https://api.kilostrength.cn',
);

class PlatformTimerBridge {
  static const _channel = MethodChannel('kilo.platform.timer');

  static void setSystemActionHandlers({
    VoidCallback? onRestSkipped,
    VoidCallback? onOpenWorkout,
    ValueChanged<int>? onCompletedSetsChanged,
    ValueChanged<bool>? onPauseChanged,
  }) {
    _channel.setMethodCallHandler(
      onRestSkipped == null &&
              onOpenWorkout == null &&
              onCompletedSetsChanged == null &&
              onPauseChanged == null
          ? null
          : (call) async {
              if (call.method == 'restSkippedFromNotification') {
                onRestSkipped?.call();
              } else if (call.method == 'openWorkoutFromSystem') {
                onOpenWorkout?.call();
              } else if (call.method == 'completeSetFromNotification') {
                final value = call.arguments;
                final target = value is Map
                    ? value['completedSets'] as int?
                    : null;
                if (target != null) onCompletedSetsChanged?.call(target);
              } else if (call.method == 'pauseChangedFromNotification') {
                onPauseChanged?.call(call.arguments == true);
              }
            },
    );
    if (onOpenWorkout != null) {
      unawaited(
        _consumePendingWorkoutOpen().then((pending) {
          if (pending) onOpenWorkout();
        }),
      );
    }
    if (onCompletedSetsChanged != null || onPauseChanged != null) {
      unawaited(
        _consumePendingTimerActions().then((pending) {
          final completed = pending['completedSets'];
          if (completed is int) onCompletedSetsChanged?.call(completed);
          final paused = pending['paused'];
          if (paused is bool) onPauseChanged?.call(paused);
        }),
      );
    }
  }

  static Future<Map<dynamic, dynamic>> _consumePendingTimerActions() async {
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'consumePendingTimerActions',
      );
      return result is Map ? result : const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException catch (_) {
      return const {};
    }
  }

  static Future<bool> _consumePendingWorkoutOpen() async {
    try {
      return await _channel.invokeMethod<bool>('consumePendingWorkoutOpen') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (_) {
      return false;
    }
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
    required String exercise,
    required int completedSets,
    required int totalSets,
  }) async {
    try {
      await _channel.invokeMethod<void>('startWorkout', {
        'elapsedSeconds': elapsedSeconds,
        'workoutName': workoutName,
        'exercise': exercise,
        'completedSets': completedSets,
        'totalSets': totalSets,
      });
    } on MissingPluginException {
      // The native foreground service is optional in widget tests and previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when the system capability is unavailable.
    }
  }

  static Future<void> updateWorkoutState({
    required String exercise,
    required int completedSets,
    required int totalSets,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateWorkoutState', {
        'exercise': exercise,
        'completedSets': completedSets,
        'totalSets': totalSets,
      });
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
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

  static Future<void> completeRest() async {
    try {
      await _channel.invokeMethod<void>('completeRest');
    } on MissingPluginException {
      // The native completion notification is optional in tests and previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when the system capability is unavailable.
    }
  }
}

class AppController extends ChangeNotifier {
  AppController({
    AccountService? accountService,
    this.recognitionApi,
    this.coachApi,
    WorkoutHistoryPersistence? workoutHistoryPersistence,
    ActiveWorkoutPersistence? activeWorkoutPersistence,
    TrainingLibraryPersistence? trainingLibraryPersistence,
  }) : accountService = accountService ?? AccountService(),
       workoutHistoryPersistence =
           workoutHistoryPersistence ??
           SharedPreferencesWorkoutHistoryPersistence(),
       activeWorkoutPersistence =
           activeWorkoutPersistence ??
           SharedPreferencesActiveWorkoutPersistence(),
       trainingLibraryPersistence =
           trainingLibraryPersistence ??
           SharedPreferencesTrainingLibraryPersistence() {
    _seed();
    PlatformTimerBridge.setSystemActionHandlers(
      onRestSkipped: skipRest,
      onOpenWorkout: _openWorkoutFromSystem,
      onCompletedSetsChanged: syncCompletedSetsFromSystem,
      onPauseChanged: setWorkoutPausedFromSystem,
    );
    this.accountService.addListener(_handleAccountChanged);
    unawaited(loadRecognitionCapabilities());
  }

  final AccountService accountService;
  final RecognitionApi? recognitionApi;
  final CoachApi? coachApi;
  final WorkoutHistoryPersistence workoutHistoryPersistence;
  final ActiveWorkoutPersistence activeWorkoutPersistence;
  final TrainingLibraryPersistence trainingLibraryPersistence;
  Future<void> _historyWriteChain = Future<void>.value();
  Future<void> _activeWorkoutWriteChain = Future<void>.value();
  Future<void> _trainingLibraryWriteChain = Future<void>.value();
  String? _loadedHistoryUserId;
  String? _loadedTrainingLibraryUserId;
  bool _pendingSystemWorkoutOpen = false;
  HttpCoachApi? _defaultCoachApi;
  String? _defaultCoachApiBaseUrl;
  HttpRecognitionApi? _defaultRecognitionApi;
  String? _defaultRecognitionApiBaseUrl;
  bool _disposed = false;

  AccountUser? get currentUser => accountService.currentUser;
  bool get isAuthenticated => accountService.isAuthenticated;
  bool get isAdmin => accountService.isAdmin;
  EntitlementSnapshot? get entitlements => accountService.entitlements;
  int get aiRemaining => accountService.aiRemaining;
  int get recognitionRemaining => accountService.recognitionRemaining;

  void _handleAccountChanged() => notifyListeners();

  AuthResult loginWithPhone(String identifier, {String? password}) {
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    final result = accountService.loginWithPhone(
      identifier,
      password: password,
    );
    if (result.isSuccess) {
      aiSkills.clear();
      unawaited(hydrateWorkoutHistory(force: true));
      unawaited(hydrateActiveWorkout());
      unawaited(hydrateTrainingLibrary(force: true));
      unawaited(hydrateAiSkills());
    }
    return result;
  }

  AuthResult loginWithApple() => accountService.loginWithApple();

  AuthResult loginWithGoogle() => accountService.loginWithGoogle();

  void logout() {
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    accountService.logout();
    _loadedHistoryUserId = null;
    _loadedTrainingLibraryUserId = null;
    history.clear();
    routines.clear();
    routineFolders.clear();
    scheduled.clear();
    scheduledLabels.clear();
    aiSkills.clear();
    notifyListeners();
  }

  Future<void> hydrateWorkoutHistory({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) {
      history.clear();
      _loadedHistoryUserId = null;
      notifyListeners();
      return;
    }
    if (!force && _loadedHistoryUserId == userId) return;
    await _historyWriteChain;
    final records = await workoutHistoryPersistence.read(userId);
    if (currentUser?.id != userId) return;
    history
      ..clear()
      ..addAll(records);
    _loadedHistoryUserId = userId;
    notifyListeners();
  }

  Future<void> flushWorkoutHistoryPersistence() => _historyWriteChain;

  Future<void> flushActiveWorkoutPersistence() => _activeWorkoutWriteChain;

  Future<void> flushTrainingLibraryPersistence() => _trainingLibraryWriteChain;

  Future<void> hydrateTrainingLibrary({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (!force && _loadedTrainingLibraryUserId == userId) return;
    await _trainingLibraryWriteChain;
    final snapshot = await trainingLibraryPersistence.read(userId);
    if (currentUser?.id != userId) return;
    routines
      ..clear()
      ..addAll(snapshot.routines);
    routineFolders
      ..clear()
      ..addAll(snapshot.routineFolders);
    scheduledLabels
      ..clear()
      ..addAll(snapshot.scheduledLabels);
    scheduled
      ..clear()
      ..addAll(snapshot.scheduledLabels.keys);
    _loadedTrainingLibraryUserId = userId;
    notifyListeners();
  }

  void _persistTrainingLibrary() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _loadedTrainingLibraryUserId = userId;
    final snapshot = TrainingLibrarySnapshot(
      routines: routines
          .map(
            (routine) => Routine(
              id: routine.id,
              name: routine.name,
              folder: routine.folder,
              exercises: routine.exercises
                  .map((exercise) => exercise.copyForPlan())
                  .toList(),
              updatedAt: routine.updatedAt,
            ),
          )
          .toList(growable: false),
      routineFolders: List<String>.from(routineFolders),
      scheduledLabels: Map<String, String>.from(scheduledLabels),
    );
    _trainingLibraryWriteChain = _trainingLibraryWriteChain
        .then((_) => trainingLibraryPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // Training remains available even if platform storage is absent.
        });
  }

  Future<void> hydrateActiveWorkout() async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty || workoutStarted) return;
    final snapshot = await activeWorkoutPersistence.read(userId);
    if (snapshot == null || _disposed) return;
    workout
      ..clear()
      ..addAll(snapshot.exercises.map((item) => item.copy()));
    workoutName = snapshot.name;
    workoutNote = snapshot.note;
    freeWorkout = snapshot.freeWorkout;
    workoutDraft = snapshot.draft;
    workoutStarted = true;
    workoutCompleted = false;
    workoutTimerStarted = snapshot.timerStarted;
    workoutPaused = snapshot.paused;
    workoutElapsedSeconds = snapshot.elapsedSeconds;
    workoutStartedAt = snapshot.timerStarted && !snapshot.paused
        ? snapshot.startedAt ?? DateTime.now()
        : null;
    if (workoutTimerStarted && !workoutPaused) {
      _workoutTicker?.cancel();
      _workoutTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
    if (_pendingSystemWorkoutOpen) {
      _pendingSystemWorkoutOpen = false;
      trainView = TrainView.workout;
      liveWorkoutVisible = true;
      page = PageId.train;
    }
    notifyListeners();
  }

  void persistActiveWorkout() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final snapshot = workoutStarted
        ? ActiveWorkoutSnapshot(
            name: workoutName,
            note: workoutNote,
            freeWorkout: freeWorkout,
            draft: workoutDraft,
            timerStarted: workoutTimerStarted,
            paused: workoutPaused,
            elapsedSeconds: currentElapsed,
            startedAt: workoutStartedAt,
            exercises: workout.map((item) => item.copy()).toList(),
          )
        : null;
    _activeWorkoutWriteChain = _activeWorkoutWriteChain
        .then((_) => activeWorkoutPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // A storage failure must never interrupt a live workout.
        });
  }

  void _persistWorkoutHistory() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _loadedHistoryUserId = userId;
    final snapshot = history.map((record) => record).toList(growable: false);
    _historyWriteChain = _historyWriteChain
        .then((_) => workoutHistoryPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // Training stays usable when platform storage is temporarily absent.
        });
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
  bool livePrEnabled = true;
  String selectedExerciseId = 'bench_press';
  AppLanguage appLanguage = AppLanguage.simplifiedChinese;
  String search = '';
  String muscleFilter = '全部';
  String equipmentFilter = '全部';
  RecognitionStatus recognitionStatus = RecognitionStatus.idle;
  RecognitionStage recognitionStage = RecognitionStage.idle;
  double recognitionProgress = 0;
  int recognitionElapsedSeconds = 0;
  bool recognitionIncludeOverlay = true;
  List<RecognitionCapability> recognitionCapabilities =
      fallbackRecognitionCapabilities;
  bool recognitionCapabilitiesLoading = false;
  String recognitionExerciseId =
      fallbackRecognitionCapabilities.first.exerciseId;
  String recognitionCamera =
      fallbackRecognitionCapabilities.first.cameras.first.id;
  bool savedCue = false;
  bool analysisAttached = false;
  bool aiUseTrainingData = false;
  bool aiConsentSeen = false;
  bool aiTyping = false;
  int aiWaitingSeconds = 0;
  final List<ChatMessage> chat = [];
  final List<AiSkill> aiSkills = [];
  final List<AiConversation> conversations = [];
  String activeConversationId = 'conversation-main';
  String scenario = 'normal';
  bool appleWatch = false;
  bool liveActivity = true;
  bool androidNotifications = true;
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
  Timer? _aiWaitingTimer;
  StreamSubscription<CoachStreamEvent>? _aiStreamSubscription;
  Completer<CoachAnswer>? _activeAiCompleter;
  bool _aiCancelled = false;
  DateTime? _activeSetStartedAt;
  int _activeSetElapsedSeconds = 0;
  QuotaReservation? _recognitionReservation;

  List<Exercise> get allExercises => [...catalog, ...customExercises];

  List<AiSkill> get enabledAiSkills =>
      aiSkills.where((skill) => skill.enabled).toList(growable: false);

  Future<void> hydrateAiSkills() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_aiSkillsStorageKey);
      aiSkills.clear();
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final values = jsonDecode(raw) as List<dynamic>;
      aiSkills
        ..clear()
        ..addAll(
          values
              .whereType<Map<String, dynamic>>()
              .map(AiSkill.fromJson)
              .where(
                (skill) => skill.id.isNotEmpty && skill.name.trim().isNotEmpty,
              )
              .take(3),
        );
      notifyListeners();
    } catch (_) {
      // Invalid local data must not block AI chat startup.
    }
  }

  Future<void> _persistAiSkills() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _aiSkillsStorageKey,
        jsonEncode(aiSkills.map((skill) => skill.toJson()).toList()),
      );
    } catch (_) {
      // In-memory skill editing remains available in previews.
    }
  }

  bool saveAiSkill({String? id, required String name, required String instructions}) {
    final cleanName = name.trim();
    final cleanInstructions = instructions.trim();
    if (cleanName.isEmpty || cleanInstructions.isEmpty) return false;
    final index = id == null ? -1 : aiSkills.indexWhere((item) => item.id == id);
    if (index >= 0) {
      aiSkills[index] = aiSkills[index].copyWith(
        name: cleanName,
        instructions: cleanInstructions,
      );
    } else {
      if (aiSkills.length >= 3) return false;
      aiSkills.add(
        AiSkill(
          id: 'skill-${DateTime.now().microsecondsSinceEpoch}',
          name: cleanName,
          instructions: cleanInstructions,
        ),
      );
    }
    unawaited(_persistAiSkills());
    notifyListeners();
    return true;
  }

  String get _aiSkillsStorageKey =>
      'xingyu.ai-skills.v1.${currentUser?.id ?? 'local'}';

  bool setAiSkillEnabled(String id, bool enabled) {
    final index = aiSkills.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    if (enabled && enabledAiSkills.length >= 3 && !aiSkills[index].enabled) {
      return false;
    }
    aiSkills[index] = aiSkills[index].copyWith(enabled: enabled);
    unawaited(_persistAiSkills());
    notifyListeners();
    return true;
  }

  void deleteAiSkill(String id) {
    aiSkills.removeWhere((item) => item.id == id);
    unawaited(_persistAiSkills());
    notifyListeners();
  }

  List<Exercise> get recognitionExercises => recognitionCapabilities
      .map((item) => allExercises.where((e) => e.id == item.exerciseId))
      .where((matches) => matches.isNotEmpty)
      .map((matches) => matches.first)
      .toList(growable: false);

  RecognitionCapability get selectedRecognitionCapability =>
      recognitionCapabilities.firstWhere(
        (item) => item.exerciseId == recognitionExerciseId,
        orElse: () => recognitionCapabilities.first,
      );

  RecognitionCameraOption get selectedRecognitionCamera =>
      selectedRecognitionCapability.cameras.firstWhere(
        (item) => item.id == recognitionCamera,
        orElse: () => selectedRecognitionCapability.cameras.first,
      );

  void selectRecognitionExercise(String exerciseId) {
    final capability = recognitionCapabilities.firstWhere(
      (item) => item.exerciseId == exerciseId,
      orElse: () => recognitionCapabilities.first,
    );
    recognitionExerciseId = capability.exerciseId;
    recognitionCamera = capability.cameras.first.id;
    notifyListeners();
  }

  void selectRecognitionCamera(String cameraId) {
    if (!selectedRecognitionCapability.cameras.any(
      (item) => item.id == cameraId,
    )) {
      return;
    }
    recognitionCamera = cameraId;
    notifyListeners();
  }

  Future<void> loadRecognitionCapabilities() async {
    if (recognitionCapabilitiesLoading) return;
    recognitionCapabilitiesLoading = true;
    notifyListeners();
    try {
      final api =
          _defaultRecognitionApi ??
          HttpRecognitionApi(
            baseUrl: aiBaseUrl.trim().isEmpty
                ? defaultCoachApiBaseUrl
                : aiBaseUrl.trim(),
          );
      final loaded = await api.capabilities();
      if (_disposed) return;
      if (loaded.isNotEmpty) recognitionCapabilities = loaded;
      if (!recognitionCapabilities.any(
        (item) => item.exerciseId == recognitionExerciseId,
      )) {
        recognitionExerciseId = recognitionCapabilities.first.exerciseId;
      }
      final capability = selectedRecognitionCapability;
      if (!capability.cameras.any((item) => item.id == recognitionCamera)) {
        recognitionCamera = capability.cameras.first.id;
      }
    } catch (_) {
      // The bundled capability list is intentionally kept usable when the
      // remote configuration endpoint is temporarily unreachable. Uploading a
      // local video and starting an analysis must not look disabled merely
      // because this optional refresh failed.
    } finally {
      if (!_disposed) {
        recognitionCapabilitiesLoading = false;
        notifyListeners();
      }
    }
  }

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
      appLanguage == AppLanguage.english ? exercise.englishName : exercise.name;

  WorkoutRecord? workoutRecordForAiContext(AiContextSelection context) {
    if (context.type != AiContextType.workoutRecord) return null;
    for (final record in history) {
      if (record.id == context.id) return record;
    }
    return null;
  }

  Routine? routineForAiContext(AiContextSelection context) {
    if (context.type != AiContextType.routine) return null;
    for (final routine in routines) {
      if (routine.id == context.id) return routine;
    }
    return null;
  }

  Future<void> hydrateAppLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = AppLanguageValue.fromStorage(
        preferences.getString('app_language'),
      );
      if (_disposed) return;
      appLanguage = stored;
      notifyListeners();
    } catch (_) {
      // Localization remains usable with the default language in previews.
    }
  }

  Future<void> setAppLanguage(AppLanguage value) async {
    if (appLanguage == value) return;
    appLanguage = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('app_language', value.storageValue);
    } catch (_) {
      // The in-memory language still changes if platform storage is absent.
    }
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

  WorkoutExercise createBlankWorkoutExercise(String exerciseId, String id) =>
      WorkoutExercise(
        id: id,
        exerciseId: exerciseId,
        restSeconds: 0,
        sets: [
          WorkoutSet(
            id: '$id-set-0',
            weight: 0,
            plannedWeight: null,
            reps: 0,
            targetMin: 0,
            targetMax: 0,
            restSeconds: 0,
          ),
        ],
      );

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
  void refresh({bool persistWorkout = false}) {
    if (persistWorkout) persistActiveWorkout();
    notifyListeners();
  }

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
      persistActiveWorkout();
      notifyListeners();
    }
  }

  void beginWorkoutTimer() {
    if (!workoutStarted || workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutPaused = false;
    workoutStartedAt = DateTime.now();
    _activeSetStartedAt ??= DateTime.now();
    _workoutTicker?.cancel();
    _workoutTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    PlatformTimerBridge.startWorkout(
      elapsedSeconds: 0,
      workoutName: workoutName,
      exercise: _platformExerciseName(),
      completedSets: completedSets,
      totalSets: totalSets,
    );
    persistActiveWorkout();
    notifyListeners();
  }

  void openLiveWorkout() {
    liveWorkoutVisible = true;
    page = PageId.train;
    notifyListeners();
  }

  void _openWorkoutFromSystem() {
    if (!workoutStarted) {
      _pendingSystemWorkoutOpen = true;
      unawaited(hydrateActiveWorkout());
      return;
    }
    trainView = TrainView.workout;
    openLiveWorkout();
  }

  void closeLiveWorkout() {
    liveWorkoutVisible = false;
    notifyListeners();
  }

  void pauseWorkout() {
    if (!workoutStarted || !workoutTimerStarted) return;
    workoutElapsedSeconds = currentElapsed;
    if (!workoutPaused && _activeSetStartedAt != null) {
      _activeSetElapsedSeconds += DateTime.now()
          .difference(_activeSetStartedAt!)
          .inSeconds;
      _activeSetStartedAt = null;
    }
    workoutPaused = !workoutPaused;
    workoutStartedAt = workoutPaused ? null : DateTime.now();
    if (workoutPaused) {
      PlatformTimerBridge.pause();
    } else {
      _activeSetStartedAt ??= DateTime.now();
      PlatformTimerBridge.startWorkout(
        elapsedSeconds: workoutElapsedSeconds,
        workoutName: workoutName,
        exercise: _platformExerciseName(),
        completedSets: completedSets,
        totalSets: totalSets,
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
    persistActiveWorkout();
    notifyListeners();
  }

  void setWorkoutPausedFromSystem(bool paused) {
    if (!workoutStarted || workoutPaused == paused) return;
    workoutElapsedSeconds = currentElapsed;
    if (paused && _activeSetStartedAt != null) {
      _activeSetElapsedSeconds += DateTime.now()
          .difference(_activeSetStartedAt!)
          .inSeconds;
      _activeSetStartedAt = null;
    } else if (!paused) {
      _activeSetStartedAt ??= DateTime.now();
    }
    workoutPaused = paused;
    workoutStartedAt = paused ? null : DateTime.now();
    persistActiveWorkout();
    notifyListeners();
  }

  void completeNextSetFromSystem() {
    for (final exercise in workout) {
      for (final set in exercise.sets) {
        if (!set.completed) {
          completeSet(set, exercise);
          return;
        }
      }
    }
  }

  void syncCompletedSetsFromSystem(int target) {
    final safeTarget = target.clamp(0, totalSets);
    while (completedSets < safeTarget) {
      final before = completedSets;
      completeNextSetFromSystem();
      if (completedSets == before) break;
    }
  }

  void completeSet(WorkoutSet set, WorkoutExercise parent) {
    if (!workoutStarted) return;
    if (!workoutTimerStarted) beginWorkoutTimer();
    set.completed = !set.completed;
    if (set.completed) {
      final started = _activeSetStartedAt;
      final currentSegment = started == null
          ? 0
          : DateTime.now().difference(started).inSeconds;
      final duration = _activeSetElapsedSeconds + currentSegment;
      if (duration > 0) {
        set.durationSeconds = duration.clamp(1, 3600);
      }
      _activeSetStartedAt = null;
      _activeSetElapsedSeconds = 0;
      triggerCompletionBurst(set.id);
      restRemainingSeconds = effectiveRestSeconds(set, parent);
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
      set.durationSeconds = null;
      _activeSetElapsedSeconds = 0;
      _activeSetStartedAt = workoutPaused ? null : DateTime.now();
      restRemainingSeconds = 0;
      restRunning = false;
      restExerciseName = null;
      _restTicker?.cancel();
      PlatformTimerBridge.clearRest();
    }
    persistActiveWorkout();
    _syncPlatformWorkoutState(parent);
    notifyListeners();
  }

  void startCurrentSetTimer() {
    if (!workoutStarted) return;
    if (!workoutTimerStarted) beginWorkoutTimer();
    _activeSetStartedAt = DateTime.now();
    _activeSetElapsedSeconds = 0;
    notifyListeners();
  }

  int get currentSetElapsedSeconds => _activeSetStartedAt == null
      ? 0
      : DateTime.now().difference(_activeSetStartedAt!).inSeconds;

  ParsedWorkoutNote parseNaturalWorkout(String text) =>
      NaturalWorkoutParser.parse(text, allExercises);

  void applyNaturalWorkout(ParsedWorkoutNote parsed) {
    if (parsed.exercises.isEmpty) return;
    if (!workoutStarted) startWorkout(name: '自由训练', autoStartTimer: false);
    workout.addAll(parsed.exercises.map((item) => item.copyForWorkout()));
    if (parsed.note.isNotEmpty) workoutNote = parsed.note;
    persistActiveWorkout();
    notifyListeners();
  }

  int effectiveRestSeconds(WorkoutSet set, WorkoutExercise parent) {
    if (set.restSeconds > 0) return set.restSeconds;
    if (parent.restSeconds > 0) return parent.restSeconds;
    if (set.type == 'warmup') return 60;
    return defaultRestSeconds;
  }

  String _platformExerciseName([WorkoutExercise? preferred]) {
    final exercise = preferred ?? (workout.isEmpty ? null : workout.first);
    if (exercise == null) return '准备训练';
    return displayExerciseName(findExercise(exercise.exerciseId));
  }

  void _syncPlatformWorkoutState([WorkoutExercise? preferred]) {
    if (!workoutStarted || !workoutTimerStarted) return;
    PlatformTimerBridge.updateWorkoutState(
      exercise: _platformExerciseName(preferred),
      completedSets: completedSets,
      totalSets: totalSets,
    );
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
      }
      if (restRemainingSeconds <= 0) {
        restRemainingSeconds = 0;
        restRunning = false;
        restExerciseName = null;
        _restTicker?.cancel();
        PlatformTimerBridge.completeRest();
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
        _activeSetStartedAt = DateTime.now();
        _activeSetElapsedSeconds = 0;
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
    persistActiveWorkout();
    notifyListeners();
  }

  void updateSetNote(WorkoutSet set, String note) {
    set.note = note.trim();
    persistActiveWorkout();
    notifyListeners();
  }

  void updateExerciseNote(WorkoutExercise exercise, String note) {
    exercise.note = note.trim();
    persistActiveWorkout();
    notifyListeners();
  }

  void skipRest() {
    restRemainingSeconds = 0;
    restRunning = false;
    restExerciseName = null;
    _restTicker?.cancel();
    PlatformTimerBridge.clearRest();
    _activeSetStartedAt = workoutPaused ? null : DateTime.now();
    _activeSetElapsedSeconds = 0;
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
    final prs = <String>[];
    for (final exercise in historySnapshot) {
      final currentBest = exercise.sets
          .where((set) => set.completed && set.weight > 0)
          .fold<double>(
            0,
            (best, set) => set.weight > best ? set.weight : best,
          );
      if (currentBest <= 0) continue;
      var previousBest = 0.0;
      for (final previousRecord in history) {
        for (final previousExercise in previousRecord.exercises.where(
          (item) => item.exerciseId == exercise.exerciseId,
        )) {
          for (final set in previousExercise.sets.where(
            (set) => set.completed,
          )) {
            if (set.weight > previousBest) previousBest = set.weight;
          }
        }
      }
      if (currentBest > previousBest) {
        prs.add(displayExerciseName(findExercise(exercise.exerciseId)));
      }
    }
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
      prs: prs,
      exercises: historySnapshot,
    );
    history.insert(0, record);
    _persistWorkoutHistory();
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
      _persistTrainingLibrary();
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
    persistActiveWorkout();
    notifyListeners();
    return record;
  }

  String _defaultFreeRoutineName(DateTime date) =>
      '自由训练 ${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void addSet(WorkoutExercise exercise) {
    final nextIndex = exercise.sets.length;
    exercise.sets.add(
      WorkoutSet(
        id: 'set-${exercise.id}-$nextIndex-${DateTime.now().microsecondsSinceEpoch}',
        type: 'work',
        weight: 0,
        plannedWeight: null,
        reps: 0,
        targetMin: 0,
        targetMax: 0,
        restSeconds: exercise.restSeconds,
      ),
    );
    _syncPlatformWorkoutState(exercise);
    persistActiveWorkout();
    notifyListeners();
  }

  bool removeSet(WorkoutExercise exercise, WorkoutSet set) {
    final removed = exercise.sets.remove(set);
    if (!removed) return false;
    selectedSetIds.remove(set.id);
    if (completionBurstSetId == set.id) {
      completionBurstActive = false;
      completionBurstSetId = null;
      _completionBurstTimer?.cancel();
    }
    _syncPlatformWorkoutState(exercise);
    persistActiveWorkout();
    notifyListeners();
    return true;
  }

  bool reusePreviousValues(WorkoutExercise exercise) {
    var reused = false;
    for (var index = 0; index < exercise.sets.length; index++) {
      final previous = previousSetFor(exercise.exerciseId, index);
      if (previous == null) continue;
      exercise.sets[index].weight = previous.weight;
      exercise.sets[index].reps = previous.reps;
      reused = true;
    }
    if (reused) notifyListeners();
    return reused;
  }

  bool hasPreviousValues(WorkoutExercise exercise) {
    for (var index = 0; index < exercise.sets.length; index++) {
      if (previousSetFor(exercise.exerciseId, index) != null) return true;
    }
    return false;
  }

  /// Changes the active rest countdown and uses the same value as the default
  /// for every upcoming exercise and unfinished set in this workout.
  void updateActiveAndUpcomingRest(int seconds) {
    final value = seconds.clamp(0, 600).toInt();
    defaultRestSeconds = value;
    for (final exercise in workout) {
      exercise.restSeconds = value;
      for (final set in exercise.sets) {
        if (!set.completed) set.restSeconds = value;
      }
    }
    if (restRunning) {
      final activeName = restExerciseName ?? '休息计时';
      startRest(exercise: activeName, seconds: value);
    }
    persistActiveWorkout();
    notifyListeners();
  }

  void clearExerciseValues(WorkoutExercise exercise) {
    for (final set in exercise.sets) {
      set.weight = 0;
      set.reps = 0;
      if (freeWorkout) set.plannedWeight = null;
    }
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
            restSeconds: defaultRestSeconds,
          )
        : createBlankWorkoutExercise(
            id,
            'we-${DateTime.now().microsecondsSinceEpoch}',
          );
    workout.add(item);
    workoutDraft = true;
    _syncPlatformWorkoutState(item);
    persistActiveWorkout();
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
    _persistWorkoutHistory();
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
    _persistWorkoutHistory();
    notifyListeners();
  }

  void replaceExercise(String oldId, String nextId) {
    final target = workout.firstWhere((item) => item.id == oldId);
    target.exerciseId = nextId;
    notifyListeners();
  }

  void removeExercise(WorkoutExercise exercise) {
    workout.remove(exercise);
    persistActiveWorkout();
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
    _persistTrainingLibrary();
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
    _persistTrainingLibrary();
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
    _persistTrainingLibrary();
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
    _persistTrainingLibrary();
    notifyListeners();
  }

  void renameRoutine(Routine routine, String name) {
    routine.name = name.trim().isEmpty ? routine.name : name.trim();
    routine.updatedAt = DateTime.now();
    _persistTrainingLibrary();
    notifyListeners();
  }

  void deleteRoutine(Routine routine) {
    routines.remove(routine);
    _persistTrainingLibrary();
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
    _persistTrainingLibrary();
    notifyListeners();
  }

  void addRoutineFolder(String folder) {
    final value = folder.trim();
    if (value.isEmpty || routineFolders.contains(value)) return;
    routineFolders.add(value);
    _persistTrainingLibrary();
    notifyListeners();
  }

  void schedule(DateTime date, String label) {
    final value =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (!scheduled.contains(value)) scheduled.add(value);
    scheduledLabels[value] = label;
    _persistTrainingLibrary();
    notifyListeners();
  }

  void reschedule(String date, String label) {
    if (!scheduled.contains(date)) scheduled.add(date);
    scheduledLabels[date] = label;
    _persistTrainingLibrary();
    notifyListeners();
  }

  void unschedule(String date) {
    scheduled.remove(date);
    scheduledLabels.remove(date);
    _persistTrainingLibrary();
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
    if (recognitionStatus != RecognitionStatus.ready &&
        recognitionStatus != RecognitionStatus.error) {
      return;
    }
    if (selectedMediaPath == null || selectedMediaPath!.isEmpty) return;
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    recognitionStatus = RecognitionStatus.processing;
    recognitionStage = RecognitionStage.preparing;
    recognitionProgress = 0;
    recognitionElapsedSeconds = 0;
    recognitionResult = null;
    mediaError = null;
    _recognitionTicker?.cancel();
    _recognitionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      recognitionElapsedSeconds += 1;
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
    unawaited(_submitRecognition());
  }

  void setRecognitionIncludeOverlay(bool value) {
    if (recognitionStatus == RecognitionStatus.processing) return;
    recognitionIncludeOverlay = value;
    notifyListeners();
  }

  void _updateRecognitionProgress(RecognitionProgressUpdate update) {
    if (_disposed || recognitionStatus != RecognitionStatus.processing) return;
    recognitionStage = update.stage;
    if (update.fraction != null) {
      recognitionProgress = update.fraction!.clamp(0, 1);
    }
    notifyListeners();
  }

  Future<void> _submitRecognition() async {
    try {
      final api = await _activeRecognitionApi();
      if (!isAuthenticated) {
        throw const RecognitionApiException('recognition_unauthenticated');
      }
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
        _recognitionTicker?.cancel();
        notifyListeners();
        return;
      }
      final mediaPath = selectedMediaPath;
      if (mediaPath == null || mediaPath.isEmpty) {
        throw const RecognitionApiException('recognition_file_missing');
      }
      final result = await api.analyze(
        exerciseId: recognitionExerciseId,
        camera: recognitionCamera,
        scenario: scenario,
        mediaPath: mediaPath,
        includeOverlay: recognitionIncludeOverlay,
        onProgress: _updateRecognitionProgress,
      );
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
    } on RecognitionApiException catch (error) {
      _recognitionReservation?.rollback();
      _recognitionReservation = null;
      recognitionStatus = RecognitionStatus.error;
      recognitionResult = RecognitionResult(
        status: RecognitionStatus.error,
        confidence: 0,
        repetitions: 0,
        summary: recognitionErrorMessage(error.code),
        error: error.code,
      );
    } catch (error) {
      _recognitionReservation?.rollback();
      _recognitionReservation = null;
      recognitionStatus = RecognitionStatus.error;
      recognitionResult = RecognitionResult(
        status: RecognitionStatus.error,
        confidence: 0,
        repetitions: 0,
        summary: recognitionErrorMessage('unexpected_error'),
        error: 'unexpected_error',
      );
    }
    _recognitionTicker?.cancel();
    notifyListeners();
  }

  void addExercises(Iterable<String> ids) {
    WorkoutExercise? latest;
    for (final id in ids) {
      if (workout.any((item) => item.exerciseId == id)) continue;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      latest = freeWorkout
          ? WorkoutExercise(
              id: 'we-$stamp-$id',
              exerciseId: id,
              sets: <WorkoutSet>[],
              restSeconds: defaultRestSeconds,
            )
          : createBlankWorkoutExercise(id, 'we-$stamp-$id');
      workout.add(latest);
    }
    workoutDraft = true;
    _syncPlatformWorkoutState(latest);
    persistActiveWorkout();
    notifyListeners();
  }

  void resetRecognition() {
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    recognitionStatus = RecognitionStatus.idle;
    recognitionStage = RecognitionStage.idle;
    recognitionProgress = 0;
    recognitionElapsedSeconds = 0;
    _recognitionTicker?.cancel();
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

  Future<RecognitionApi> _activeRecognitionApi() async {
    final injected = recognitionApi;
    if (injected != null) return injected;

    final baseUrl = aiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const RecognitionApiException('recognition_base_url_missing');
    }
    if (_defaultRecognitionApi == null ||
        _defaultRecognitionApiBaseUrl != baseUrl) {
      _defaultRecognitionApi = HttpRecognitionApi(baseUrl: baseUrl);
      _defaultRecognitionApiBaseUrl = baseUrl;
    }
    final api = _defaultRecognitionApi!;
    if (!api.hasSession) {
      final identifier = currentUser?.identifier;
      if (identifier != '123' && identifier != '1234') {
        throw const RecognitionApiException('recognition_account_not_synced');
      }
      await api.signIn(identifier: identifier!, password: identifier);
    }
    return api;
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
    final lines = <String>[];
    if (workoutStarted || workoutDraft) {
      lines.add(
        '当前训练「$workoutName」：训练时长 ${currentElapsed ~/ 60} 分钟，'
        '已完成 $completedSets/$totalSets 组，当前训练量 ${workoutVolume.toStringAsFixed(1)} kg。',
      );
      for (final exercise in workout.take(12)) {
        final sets = exercise.sets
            .take(12)
            .map((set) {
              final status = set.completed ? '已完成' : '未完成';
              return '$status ${set.weight.toStringAsFixed(1)} kg × ${set.reps}'
                  '${set.note.trim().isEmpty ? '' : '，备注：${set.note.trim()}'}';
            })
            .join('；');
        if (sets.isNotEmpty) {
          lines.add(
            '${findExercise(exercise.exerciseId).name}'
            '${exercise.note.trim().isEmpty ? '' : '，动作备注：${exercise.note.trim()}'}：$sets',
          );
        }
      }
    }
    if (history.isEmpty && lines.isEmpty) return '用户尚无训练记录。';
    if (history.isNotEmpty) lines.add('最近已完成训练：');
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
                  '${set.note.trim().isEmpty ? '' : '，备注：${set.note.trim()}'}',
            )
            .join('；');
        lines.add(
          '${findExercise(exercise.exerciseId).name}'
          '${exercise.note.trim().isEmpty ? '' : '，动作备注：${exercise.note.trim()}'}：$sets',
        );
      }
    }
    return lines.join('\n');
  }

  List<AiContextSelection> get availableAiContexts {
    final now = DateTime.now();
    return [
      if (workoutStarted || workoutDraft)
        AiContextSelection(
          type: AiContextType.activeWorkout,
          id: 'active',
          label: '当前训练',
        ),
      for (final record in history.take(30))
        AiContextSelection(
          type: AiContextType.workoutRecord,
          id: record.id,
          label: '${record.date.month}/${record.date.day} ${record.name}',
        ),
      for (final routine in routines.take(30))
        AiContextSelection(
          type: AiContextType.routine,
          id: routine.id,
          label: '计划 · ${routine.name}',
        ),
      AiContextSelection(
        type: AiContextType.week,
        id: '${now.year}-w${_weekNumber(now)}',
        label: '本周训练汇总',
      ),
      AiContextSelection(
        type: AiContextType.month,
        id: '${now.year}-${now.month}',
        label: '本月训练汇总',
      ),
    ];
  }

  int _weekNumber(DateTime date) {
    final first = DateTime(date.year, 1, 1);
    return ((date.difference(first).inDays + first.weekday) / 7).ceil();
  }

  String _recordAiSummary(WorkoutRecord record) {
    final lines = <String>[
      '${record.date.toIso8601String().split('T').first} ${record.name}：'
          '${record.durationSeconds ~/ 60} 分钟，总容量 '
          '${record.volume.toStringAsFixed(1)} kg，完成 ${record.effectiveSets} 组。',
    ];
    if (record.note.trim().isNotEmpty) lines.add('训练备注：${record.note.trim()}');
    for (final exercise in record.exercises) {
      final values = exercise.sets
          .where((set) => set.completed)
          .map(
            (set) =>
                '${set.weight.toStringAsFixed(1)} kg×${set.reps}'
                '${set.note.trim().isEmpty ? '' : '（${set.note.trim()}）'}',
          )
          .join('；');
      lines.add(
        '${displayExerciseName(findExercise(exercise.exerciseId))}'
        '${exercise.note.trim().isEmpty ? '' : '（动作备注：${exercise.note.trim()}）'}：'
        '${values.isEmpty ? '没有完成组' : values}',
      );
    }
    return lines.join('\n');
  }

  String _routineAiSummary(Routine routine) {
    final lines = <String>['训练计划「${routine.name}」：'];
    for (final exercise in routine.exercises) {
      final sets = exercise.sets
          .map(
            (set) =>
                '${set.plannedWeight == null ? '重量待定' : '${set.plannedWeight!.toStringAsFixed(1)} kg'}'
                '×${set.targetMax > 0 ? set.targetMax : set.reps}，休息 ${set.restSeconds} 秒',
          )
          .join('；');
      lines.add(
        '${displayExerciseName(findExercise(exercise.exerciseId))}：'
        '${sets.isEmpty ? '组数待定' : sets}',
      );
    }
    return lines.join('\n');
  }

  String _buildSelectedAiContext(List<AiContextSelection> selections) {
    final blocks = <String>[];
    for (final selection in selections) {
      switch (selection.type) {
        case AiContextType.activeWorkout:
          blocks.add(_buildAiTrainingSummary().split('最近已完成训练：').first);
        case AiContextType.workoutRecord:
          final matches = history.where((item) => item.id == selection.id);
          if (matches.isNotEmpty) blocks.add(_recordAiSummary(matches.first));
        case AiContextType.routine:
          final matches = routines.where((item) => item.id == selection.id);
          if (matches.isNotEmpty) blocks.add(_routineAiSummary(matches.first));
        case AiContextType.week:
          final now = DateTime.now();
          final start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1));
          final records = history.where((item) => !item.date.isBefore(start));
          blocks.add('本周训练汇总：\n${records.map(_recordAiSummary).join('\n\n')}');
        case AiContextType.month:
          final now = DateTime.now();
          final records = history.where(
            (item) =>
                item.date.year == now.year && item.date.month == now.month,
          );
          blocks.add('本月训练汇总：\n${records.map(_recordAiSummary).join('\n\n')}');
      }
    }
    return blocks.where((item) => item.trim().isNotEmpty).join('\n\n---\n\n');
  }

  Future<CoachAnswer> _requestCoachAnswer(
    String prompt, {
    bool includeTrainingContext = false,
    String? selectedTrainingContext,
  }) async {
    final requestsPlan = _isAiPlanRequest(prompt);
    final includeSummary =
        aiUseTrainingData ||
        includeTrainingContext ||
        selectedTrainingContext != null;
    Future<CoachAnswer> request() async {
      final api = await _activeCoachApi();
      return api.answer(
        prompt: prompt,
        includeTrainingSummary: includeSummary,
        locale: appLanguage.storageValue,
        trainingSummary: includeSummary
            ? selectedTrainingContext ?? _buildAiTrainingSummary()
            : null,
        exerciseCatalog: requestsPlan ? _aiExerciseCatalog() : const [],
        skills: _activeAiSkillPayload(),
      );
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await request();
      } on CoachApiException catch (error) {
        // Re-authenticate once after an expired session. Transient upstream and
        // network failures also receive one bounded retry so users do not lose
        // a plan request because of a short queue spike or tunnel reconnect.
        final retryable =
            error.code == 'coach_http_502' ||
            error.code == 'coach_http_503' ||
            error.code == 'coach_http_504' ||
            error.code == 'coach_timeout' ||
            error.code == 'coach_network';
        if (attempt == 0 &&
            (retryable ||
                (coachApi == null && error.code == 'coach_http_401'))) {
          await Future<void>.delayed(const Duration(milliseconds: 650));
          continue;
        }
        rethrow;
      }
    }
    throw const CoachApiException('coach_retry_exhausted');
  }

  bool _isAiPlanRequest(String prompt) {
    final normalized = prompt.toLowerCase();
    final asksToCreate = RegExp(
      r'(生成|制定|安排|创建|做一份|设计|帮我做|帮我排|generate|create|build|make)',
    ).hasMatch(normalized);
    final mentionsPlan = RegExp(
      r'(计划|方案|workout plan|training plan)',
    ).hasMatch(normalized);
    final shortPlanIntent = RegExp(
      r'(今日|今天|明天|本周|这周|练胸|练背|练腿|练肩|练手臂)',
    ).hasMatch(normalized);
    return mentionsPlan && (asksToCreate || shortPlanIntent);
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

  List<Map<String, String>> _activeAiSkillPayload() => [
    for (final skill in enabledAiSkills)
      {'id': skill.id, 'name': skill.name, 'instructions': skill.instructions},
  ];

  WorkoutExercise _makeAiWorkout(AiPlanExerciseDraft draft, String id) =>
      WorkoutExercise(
        id: id,
        exerciseId: draft.exerciseId,
        restSeconds: draft.sets.isEmpty
            ? defaultRestSeconds
            : draft.sets.first.restSeconds,
        sets: [
          for (var index = 0; index < draft.sets.length; index++)
            WorkoutSet(
              id: '$id-set-$index',
              type: draft.sets[index].type,
              weight: draft.sets[index].weight,
              plannedWeight: draft.sets[index].weight,
              reps: draft.sets[index].reps,
              targetMin: draft.sets[index].reps,
              targetMax: draft.sets[index].reps,
              restSeconds: draft.sets[index].restSeconds,
            ),
        ],
      );

  void saveAiPlan(
    AiPlanDraft plan, {
    required bool scheduleCalendar,
    DateTime? scheduleStartDate,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final scheduleAnchor = scheduleStartDate ?? DateTime.now();
    for (
      var sessionIndex = 0;
      sessionIndex < plan.sessions.length;
      sessionIndex++
    ) {
      final session = plan.sessions[sessionIndex];
      final validIds = session.effectiveExerciseIds
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
          exercises: session.exercises.isNotEmpty
              ? [
                  for (
                    var exerciseIndex = 0;
                    exerciseIndex < session.exercises.length;
                    exerciseIndex++
                  )
                    if (validIds.contains(
                      session.exercises[exerciseIndex].exerciseId,
                    ))
                      _makeAiWorkout(
                        session.exercises[exerciseIndex],
                        'ai-$stamp-$sessionIndex-$exerciseIndex',
                      ),
                ]
              : [
                  for (
                    var exerciseIndex = 0;
                    exerciseIndex < validIds.length;
                    exerciseIndex++
                  )
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
          scheduleAnchor.add(Duration(days: dayOffset + week * 7)),
          routineName,
        );
      }
    }
    _persistTrainingLibrary();
    notifyListeners();
  }

  Future<void> sendTodayWorkoutForReview() => sendChat(
    '请评价我今天正在进行或最近完成的训练：总结完成情况、训练容量和主要肌群，'
    '指出下一次可调整的重量或次数。每条增减重量建议都必须说明依据；如果数据不足，请明确说明。',
    includeTrainingContext: true,
  );

  Future<void> sendChat(
    String text, {
    bool includeTrainingContext = false,
    List<AiContextSelection> contexts = const [],
  }) async {
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
    _aiCancelled = false;
    aiWaitingSeconds = 0;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      aiWaitingSeconds++;
      notifyListeners();
    });
    final answerMessage = ChatMessage(
      id: 'answer-${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      body: '',
    );
    chat.add(answerMessage);
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
          final selected = contexts.isEmpty
              ? null
              : _buildSelectedAiContext(contexts);
          final api = await _activeCoachApi();
          final includeSummary =
              aiUseTrainingData || includeTrainingContext || selected != null;
          if (api is StreamingCoachApi && !_isAiPlanRequest(trimmed)) {
            final streamingApi = api as StreamingCoachApi;
            final done = Completer<CoachAnswer>();
            _activeAiCompleter = done;
            _aiStreamSubscription = streamingApi
                .streamAnswer(
                  prompt: trimmed,
                  includeTrainingSummary: includeSummary,
                  locale: appLanguage.storageValue,
                  trainingSummary: includeSummary
                      ? selected ?? _buildAiTrainingSummary()
                      : null,
                  exerciseCatalog: _isAiPlanRequest(trimmed)
                      ? _aiExerciseCatalog()
                      : const [],
                  skills: _activeAiSkillPayload(),
                )
                .listen(
                  (event) {
                    if (event is CoachStreamDelta) {
                      answerMessage.body += event.text;
                      notifyListeners();
                    } else if (event is CoachStreamDone && !done.isCompleted) {
                      done.complete(event.answer);
                    }
                  },
                  onError: (Object error) {
                    if (!done.isCompleted) done.completeError(error);
                  },
                );
            remoteAnswer = await done.future;
            if (_aiCancelled) {
              throw const CoachApiException('coach_cancelled');
            }
          } else {
            remoteAnswer = await _requestCoachAnswer(
              trimmed,
              includeTrainingContext: includeTrainingContext,
              selectedTrainingContext: selected,
            );
          }
          answerMessage
            ..body = remoteAnswer.body
            ..citations = remoteAnswer.citations
            ..plan = remoteAnswer.plan;
          if (remoteAnswer.body.trim().isNotEmpty) {
            aiReservation?.commit();
          } else {
            aiReservation?.rollback();
            serviceError =
                '\u0041\u0049 \u670d\u52a1\u672a\u8fd4\u56de\u53ef\u7528\u56de\u7b54\u3002';
          }
        } on CoachApiException catch (error) {
          aiReservation?.rollback();
          serviceError = switch (error.code) {
            'coach_cancelled' =>
              answerMessage.body.trim().isEmpty ? '已停止回答。' : null,
            'coach_account_not_synced' => '当前账号尚未同步到云端，请先使用测试账号 123 或 1234。',
            'coach_timeout' => 'AI 响应超时，已自动重试一次，请稍后再试。',
            'coach_network' => '当前网络无法连接 AI 服务，请检查网络后重试。',
            'coach_http_429' ||
            'coach_http_503' => 'AI 当前请求较多，已自动重试但仍在排队，请稍后再试。',
            'coach_http_502' || 'coach_http_504' => 'AI 上游服务短暂波动，已自动重试，请稍后再试。',
            _ => 'AI 服务暂时不可用（${error.code}），请稍后重试。',
          };
        } catch (_) {
          aiReservation?.rollback();
          serviceError = 'AI 服务暂时不可用，请稍后重试。';
        }
      }
    }
    aiTyping = false;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = null;
    _aiStreamSubscription = null;
    _activeAiCompleter = null;
    if (answerMessage.body.trim().isEmpty) {
      answerMessage.body = remoteAnswer?.body.isNotEmpty == true
          ? remoteAnswer!.body
          : serviceError ?? 'AI 服务未返回可用回答。';
    }
    _saveActiveConversation();
    notifyListeners();
  }

  Future<void> cancelAiResponse() async {
    if (!aiTyping) return;
    _aiCancelled = true;
    final assistants = chat.where((item) => item.role == 'assistant');
    final partial = assistants.isEmpty ? '' : assistants.last.body.trim();
    if (_activeAiCompleter?.isCompleted == false) {
      _activeAiCompleter!.complete(CoachAnswer(body: partial));
    }
    await _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = null;
    aiTyping = false;
    if (assistants.isNotEmpty && assistants.last.body.trim().isEmpty) {
      assistants.last.body = '已停止回答。';
    }
    _saveActiveConversation();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    accountService.removeListener(_handleAccountChanged);
    PlatformTimerBridge.setSystemActionHandlers();
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    _recognitionTicker?.cancel();
    _completionBurstTimer?.cancel();
    _aiWaitingTimer?.cancel();
    unawaited(_aiStreamSubscription?.cancel());
    super.dispose();
  }
}
