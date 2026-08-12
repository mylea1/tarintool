import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/workout_history_persistence.dart';

class _CapturingCoachApi implements CoachApi {
  bool? includeTrainingSummary;
  String? trainingSummary;

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
  }) async {
    this.includeTrainingSummary = includeTrainingSummary;
    this.trainingSummary = trainingSummary;
    return const CoachAnswer(body: '训练评价已生成');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('today workout review includes live sets and notes for AI', () async {
    final api = _CapturingCoachApi();
    final controller = AppController(coachApi: api);
    try {
      controller.startWorkout(name: '今日练胸', autoStartTimer: false);
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.updateExerciseNote(exercise, '器械第 7 档，肩胛收紧');
      controller.addSet(exercise);
      exercise.sets.single
        ..weight = 50
        ..reps = 8
        ..note = '最后两次速度变慢'
        ..completed = true;

      await controller.sendTodayWorkoutForReview();

      expect(api.includeTrainingSummary, isTrue);
      expect(api.trainingSummary, contains('今日练胸'));
      expect(api.trainingSummary, contains('50.0 kg × 8'));
      expect(api.trainingSummary, contains('最后两次速度变慢'));
      expect(api.trainingSummary, contains('器械第 7 档，肩胛收紧'));
      expect(controller.chat.last.body, '训练评价已生成');
    } finally {
      controller.dispose();
    }
  });

  test('completed history survives controller recreation per user', () async {
    final persistence = InMemoryWorkoutHistoryPersistence();
    AppController buildController() {
      final account = AccountService(allowTestAdmin: true);
      account.loginWithPhone('123', password: '123');
      return AppController(
        accountService: account,
        workoutHistoryPersistence: persistence,
      );
    }

    final first = buildController();
    await first.hydrateWorkoutHistory();
    first.startWorkout(name: '持久化训练');
    first.addExercise('bench_press');
    final exercise = first.workout.single;
    first.addSet(exercise);
    exercise.sets.single
      ..weight = 72.5
      ..reps = 6
      ..note = '动作稳定'
      ..completed = true;
    first.finishWorkout(note: '状态良好');
    await first.flushWorkoutHistoryPersistence();
    first.dispose();

    final second = buildController();
    await second.hydrateWorkoutHistory();
    expect(second.history, hasLength(1));
    expect(second.history.single.name, '持久化训练');
    expect(second.history.single.note, '状态良好');
    expect(second.history.single.exercises.single.sets.single.weight, 72.5);
    expect(second.history.single.exercises.single.sets.single.note, '动作稳定');

    second.updateRecordNote(second.history.single, '重启后编辑');
    await second.flushWorkoutHistoryPersistence();
    second.dispose();

    final third = buildController();
    await third.hydrateWorkoutHistory();
    expect(third.history.single.note, '重启后编辑');
    third.deleteRecord(third.history.single);
    await third.flushWorkoutHistoryPersistence();
    third.dispose();

    final fourth = buildController();
    await fourth.hydrateWorkoutHistory();
    expect(fourth.history, isEmpty);
    fourth.dispose();
  });

  test(
    'saved plans and calendar survive controller recreation per user',
    () async {
      final persistence = InMemoryTrainingLibraryPersistence();
      AppController buildController() {
        final account = AccountService(allowTestAdmin: true);
        account.loginWithPhone('123', password: '123');
        return AppController(
          accountService: account,
          trainingLibraryPersistence: persistence,
        );
      }

      final first = buildController();
      await first.hydrateTrainingLibrary();
      first.saveRoutineFromExerciseIds('上肢力量', const ['bench_press']);
      first.schedule(DateTime(2026, 8, 18), '月计划 · 上肢力量');
      await first.flushTrainingLibraryPersistence();
      first.dispose();

      final second = buildController();
      await second.hydrateTrainingLibrary();
      expect(second.routines, hasLength(1));
      expect(second.routines.single.name, '上肢力量');
      expect(second.scheduledLabels['2026-08-18'], contains('上肢'));
      second.dispose();
    },
  );

  test('workout timer stays independent from rest timer', () async {
    const channel = MethodChannel('kilo.platform.timer');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });

    final controller = AppController();
    try {
      final source = [
        controller.createWorkoutExercise('bench_press', 'test-bench'),
      ];
      controller.startWorkout(source: source, name: '计时测试');
      await Future<void>.delayed(Duration.zero);

      expect(controller.workoutStarted, isTrue);
      expect(calls, isNot(contains('startTimer')));

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final elapsedBeforeRest = controller.currentElapsed;
      final exercise = controller.workout.single;
      controller.completeSet(exercise.sets.first, exercise);
      await Future<void>.delayed(Duration.zero);

      expect(controller.restRunning, isTrue);
      expect(calls, contains('startTimer'));

      controller.skipRest();
      await Future<void>.delayed(Duration.zero);
      expect(controller.restRunning, isFalse);
      expect(controller.workoutStarted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controller.currentElapsed, greaterThan(elapsedBeforeRest));
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('first completed set starts a prepared workout and its rest timer', () {
    const channel = MethodChannel('kilo.platform.timer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final controller = AppController();
    try {
      controller.startWorkout(name: '准备训练', autoStartTimer: false);
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      controller.updateExerciseRest(exercise, 45);
      final set = exercise.sets.single;

      expect(controller.workoutTimerStarted, isFalse);
      controller.completeSet(set, exercise);

      expect(controller.workoutTimerStarted, isTrue);
      expect(set.completed, isTrue);
      expect(controller.restRunning, isTrue);
      expect(controller.restRemainingSeconds, 45);
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'planned weight flows from plan to workout record without overwriting',
    () {
      const channel = MethodChannel('kilo.platform.timer');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      final controller = AppController();
      try {
        final draft = controller.createWorkoutExercise(
          'bench_press',
          'draft-bench',
        );
        final plannedSet = draft.sets.first;
        controller.updatePlannedWeight(plannedSet, 82.5);
        expect(plannedSet.plannedWeight, 82.5);
        expect(plannedSet.weight, 82.5);

        controller.saveRoutineFromDraft('计划重量链路', [draft]);
        final routine = controller.routines.first;
        expect(routine.exercises.single.sets.first.plannedWeight, 82.5);

        controller.startRoutine(routine);
        final liveSet = controller.workout.single.sets.first;
        expect(liveSet.plannedWeight, 82.5);
        expect(liveSet.weight, 82.5);
        liveSet.weight = 85;
        liveSet.completed = true;
        controller.finishWorkout();

        final record = controller.history.first;
        final snapshotSet = record.exercises.single.sets.first;
        expect(snapshotSet.plannedWeight, 82.5);
        expect(snapshotSet.weight, 85);
        expect(record.volume, 85 * snapshotSet.reps);

        final legacy = WorkoutSet(id: 'legacy', weight: 40);
        expect(legacy.plannedWeight, isNull);
        expect(legacy.plannedWeightOrActual, 40);
      } finally {
        controller.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );

  test('new controller starts empty and free training persists real data', () {
    const channel = MethodChannel('kilo.platform.timer');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    final controller = AppController();
    try {
      expect(controller.workout, isEmpty);
      expect(controller.routines, isEmpty);
      expect(controller.history, isEmpty);
      expect(controller.scheduled, isEmpty);
      expect(controller.chat, isEmpty);

      controller.startWorkout(name: '自由训练');
      expect(controller.workoutStarted, isTrue);
      expect(controller.workoutDraft, isTrue);
      expect(calls, contains('startWorkout'));

      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      expect(exercise.sets, isEmpty);
      controller.addSet(exercise);
      expect(exercise.sets, hasLength(1));
      expect(exercise.sets.first.plannedWeight, isNull);
      expect(exercise.sets.first.weight, 0);
      expect(exercise.sets.first.reps, 0);
      exercise.sets.first.weight = 62.5;
      exercise.sets.first.reps = 5;
      controller.addSet(exercise);
      expect(exercise.sets.last.plannedWeight, isNull);
      expect(exercise.sets.last.weight, 0);
      exercise.sets.first.completed = true;
      controller.finishWorkout();

      expect(controller.workoutStarted, isFalse);
      expect(controller.history, hasLength(1));
      expect(controller.history.first.name, '自由训练');
      expect(controller.history.first.volume, 312.5);
      expect(controller.history.first.exercises.single.sets.first.weight, 62.5);
      expect(
        controller.history.first.exercises.single.sets.first.plannedWeight,
        isNull,
      );
      expect(calls, contains('finishTimer'));
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('routine editor draft commit does not mutate on cancel', () {
    final controller = AppController();
    try {
      final source = controller.createWorkoutExercise('bench_press', 'fixture');
      controller.saveRoutineFromDraft('测试计划', [source]);
      final routine = controller.routines.single;
      final originalName = routine.name;
      final draft = Routine(
        id: routine.id,
        name: '取消后的名字',
        folder: routine.folder,
        exercises: routine.exercises.map((item) => item.copy()).toList(),
        updatedAt: routine.updatedAt,
      );
      draft.exercises.first.sets.first.reps = 99;
      expect(routine.name, originalName);
      expect(routine.exercises.first.sets.first.reps, isNot(99));

      controller.updateRoutineFromDraft(routine, draft);
      expect(routine.name, '取消后的名字');
      expect(routine.exercises.first.sets.first.reps, 99);
    } finally {
      controller.dispose();
    }
  });

  test(
    'free-workout rest starts for every action without manual setup',
    () async {
      const channel = MethodChannel('kilo.platform.timer');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
      final controller = AppController();
      try {
        controller.startWorkout(name: '自由训练');
        controller.addExercise('bench_press');
        final exercise = controller.workout.single;
        controller.addSet(exercise);
        expect(exercise.restSeconds, controller.defaultRestSeconds);
        expect(exercise.sets.single.restSeconds, controller.defaultRestSeconds);
        exercise
          ..restSeconds = 0
          ..sets.single.restSeconds = 0;
        exercise.sets.single.type = 'warmup';
        final burstBefore = controller.completionBurstId;
        controller.completeSet(exercise.sets.single, exercise);
        await Future<void>.delayed(Duration.zero);
        expect(controller.restRunning, isTrue);
        expect(controller.restRemainingSeconds, 60);
        expect(calls, contains('startTimer'));
        expect(controller.completionBurstId, burstBefore + 1);
        controller.completeSet(exercise.sets.single, exercise);
        expect(controller.completionBurstId, burstBefore + 1);

        controller.addExercise('squat');
        final secondExercise = controller.workout.last;
        controller.addSet(secondExercise);
        expect(secondExercise.restSeconds, controller.defaultRestSeconds);
        expect(
          secondExercise.sets.single.restSeconds,
          controller.defaultRestSeconds,
        );
        controller.updateExerciseRest(secondExercise, 75);
        controller.completeSet(secondExercise.sets.single, secondExercise);
        await Future<void>.delayed(Duration.zero);
        expect(controller.restRunning, isTrue);
        expect(controller.restRemainingSeconds, 75);

        controller.completeSet(secondExercise.sets.single, secondExercise);
      } finally {
        controller.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );

  test('system workout action reopens the active live workout', () async {
    const channel = MethodChannel('kilo.platform.timer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    final controller = AppController();
    try {
      controller.startWorkout(name: '锁屏入口');
      controller.closeLiveWorkout();
      controller.selectTrainView(TrainView.history);
      expect(controller.liveWorkoutVisible, isFalse);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openWorkoutFromSystem'),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.trainView, TrainView.workout);
      expect(controller.liveWorkoutVisible, isTrue);
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('active workout survives process recreation and system open', () async {
    const channel = MethodChannel('kilo.platform.timer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    final persistence = InMemoryActiveWorkoutPersistence();
    AccountService signedInAccount() {
      final account = AccountService(allowTestAdmin: true);
      account.loginWithPhone('123', password: '123');
      return account;
    }

    final first = AppController(
      accountService: signedInAccount(),
      activeWorkoutPersistence: persistence,
    );
    first.startWorkout(name: '可恢复训练');
    first.addExercise('bench_press');
    final firstExercise = first.workout.single;
    first.addSet(firstExercise);
    firstExercise.sets.single
      ..type = 'warmup'
      ..weight = 30
      ..reps = 12
      ..completed = true;
    first.updateExerciseNote(firstExercise, '器械第 7 档');
    first.updateSetNote(firstExercise.sets.single, '左肩略紧');
    first.persistActiveWorkout();
    await first.flushActiveWorkoutPersistence();
    first.dispose();

    final restored = AppController(
      accountService: signedInAccount(),
      activeWorkoutPersistence: persistence,
    );
    try {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('openWorkoutFromSystem'),
        ),
        (_) {},
      );
      await restored.hydrateActiveWorkout();
      await Future<void>.delayed(Duration.zero);

      expect(restored.workoutStarted, isTrue);
      expect(restored.workoutName, '可恢复训练');
      expect(restored.workout.single.note, '器械第 7 档');
      expect(restored.workout.single.sets.single.note, '左肩略紧');
      expect(restored.page, PageId.train);
      expect(restored.liveWorkoutVisible, isTrue);
    } finally {
      restored.finishWorkout();
      await restored.flushActiveWorkoutPersistence();
      restored.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('free finish can save a non-empty plan while non-free ignores flag', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '自由训练');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      exercise.sets.single.weight = 67.5;
      exercise.sets.single.reps = 6;
      controller.finishWorkout(saveAsRoutine: true, routineName: '自由模板');
      expect(controller.history, hasLength(1));
      expect(controller.routines, hasLength(1));
      final savedSet = controller.routines.single.exercises.single.sets.single;
      expect(savedSet.plannedWeight, 67.5);
      expect(savedSet.weight, 67.5);
      expect(savedSet.reps, 6);
      expect(savedSet.completed, isFalse);

      final source = [controller.createWorkoutExercise('bench_press', 'plan')];
      controller.startWorkout(source: source, name: '计划训练');
      controller.finishWorkout(saveAsRoutine: true, routineName: '不应保存');
      expect(controller.routines, hasLength(1));
    } finally {
      controller.dispose();
    }
  });

  test('previousSetFor uses real history and returns null without a match', () {
    const channel = MethodChannel('kilo.platform.timer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    final controller = AppController();
    try {
      controller.startWorkout(name: 'history source');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      final set = exercise.sets.single;
      set.weight = 67.5;
      set.reps = 6;
      set.completed = true;
      controller.finishWorkout();

      final current = WorkoutSet(id: 'current', weight: 80, reps: 5);
      expect(controller.previousSetFor('bench_press', 0)?.weight, 67.5);
      // A new set index falls back to the most recent completed set for the
      // same exercise, instead of reading a plan/default weight.
      expect(controller.previousSetFor('bench_press', 1)?.reps, 6);
      expect(controller.previousSetFor('deadlift', 0), isNull);
      expect(current.plannedWeight, isNull);
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('AI plan preserves prescriptions and schedules from chosen date', () {
    final controller = AppController();
    try {
      final plan = AiPlanDraft(
        title: '今日练胸',
        weeks: 1,
        sessions: [
          AiPlanSession(
            dayOffset: 2,
            name: '胸部训练',
            exerciseIds: const ['bench_press'],
            exercises: const [
              AiPlanExerciseDraft(
                exerciseId: 'bench_press',
                sets: [
                  AiPlanSetDraft(
                    type: 'work',
                    weight: 52.5,
                    reps: 8,
                    restSeconds: 120,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      controller.saveAiPlan(
        plan,
        scheduleCalendar: true,
        scheduleStartDate: DateTime(2026, 8, 10),
      );

      expect(controller.routines, hasLength(1));
      final set = controller.routines.single.exercises.single.sets.single;
      expect(set.plannedWeight, 52.5);
      expect(set.weight, 52.5);
      expect(set.reps, 8);
      expect(set.restSeconds, 120);
      expect(controller.scheduled, contains('2026-08-12'));
      expect(controller.scheduledLabels['2026-08-12'], contains('胸部训练'));
    } finally {
      controller.dispose();
    }
  });
}
