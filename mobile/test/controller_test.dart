import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/secure_session_store.dart';
import 'package:kilo_strength/workout_history_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingCoachApi implements CoachApi {
  bool? includeTrainingSummary;
  String? trainingSummary;
  List<Map<String, String>> skills = const [];

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? conversationId,
  }) async {
    this.includeTrainingSummary = includeTrainingSummary;
    this.trainingSummary = trainingSummary;
    this.skills = skills;
    return const CoachAnswer(body: '训练评价已生成');
  }
}

class _OfficialPlansApiStub implements OfficialPlansApi {
  _OfficialPlansApiStub({this.fail = false});

  final bool fail;

  @override
  Future<List<Map<String, dynamic>>> fetchOfficialPlans() async {
    if (fail) throw const CoachApiException('offline');
    return [
      {
        'id': 'backend-plan',
        'title': '后端计划',
        'sessions': [
          {
            'name': '第一天',
            'exerciseIds': ['bench_press'],
          },
        ],
      },
    ];
  }
}

class _StreamingAgentCoachApi
    implements CoachApi, AgentCoachApi, StreamingCoachApi {
  _StreamingAgentCoachApi({this.toolCallCount = 1});

  final int toolCallCount;
  bool streamedToolContinuation = false;

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> availableTools = const [],
    List<Map<String, dynamic>> toolResults = const [],
  }) async {
    if (toolResults.isNotEmpty) {
      streamedToolContinuation = true;
      return const CoachAnswer(body: '你的计划可以这样调整');
    }
    final calls = List.generate(
      5,
      (index) => CoachToolCall(
        id: 'plans_$index',
        name: 'read_training_plans',
        arguments: const {},
      ),
    );
    return CoachAnswer(
      body: '',
      toolCalls: calls.take(toolCallCount).toList(growable: false),
    );
  }

  @override
  Stream<CoachStreamEvent> streamAnswer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> toolResults = const [],
  }) async* {
    streamedToolContinuation = toolResults.isNotEmpty;
    yield const CoachStreamDelta('你的计划');
    yield const CoachStreamDelta('可以这样调整');
    yield const CoachStreamDone(CoachAnswer(body: '你的计划可以这样调整'));
  }

  @override
  Future<void> rollbackQuotaReservation(String requestId) async {}
}

void main() {
  test('text load and cardio metrics survive workout history encoding', () {
    final set = WorkoutSet(
      id: 'set-cardio',
      weight: 0,
      weightText: '自重',
      reps: 0,
      durationSeconds: 1500,
      speedKph: 8.5,
      inclinePercent: 6,
      completed: true,
    );
    final record = WorkoutRecord(
      id: 'record-cardio',
      name: '有氧训练',
      date: DateTime(2026, 9, 4),
      startTime: '09:00',
      durationSeconds: 1500,
      volume: 0,
      effectiveSets: 1,
      exerciseIds: const ['dataset_0670'],
      exercises: [
        WorkoutExercise(
          id: 'exercise-cardio',
          exerciseId: 'dataset_0670',
          sets: [set],
        ),
      ],
    );

    final restored = decodeWorkoutRecords(
      encodeWorkoutRecords([record]),
    ).single;
    final restoredSet = restored.exercises.single.sets.single;
    expect(restoredSet.weightText, '自重');
    expect(restoredSet.durationSeconds, 1500);
    expect(restoredSet.speedKph, 8.5);
    expect(restoredSet.inclinePercent, 6);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('official plans use the last backend cache while offline', () async {
    final online = AppController(officialPlansApi: _OfficialPlansApiStub());
    addTearDown(online.dispose);
    final fresh = await online.loadOfficialPlans();
    expect(fresh.single.id, 'backend-plan');

    final offline = AppController(
      officialPlansApi: _OfficialPlansApiStub(fail: true),
    );
    addTearDown(offline.dispose);
    final cached = await offline.loadOfficialPlans();

    expect(cached.single.id, 'backend-plan');
    expect(offline.officialPlansError, contains('缓存'));
  });

  test('dark appearance mode persists across controller instances', () async {
    final first = AppController();
    addTearDown(first.dispose);
    await first.setDarkMode(true);

    final restored = AppController();
    addTearDown(restored.dispose);
    await restored.hydrateTheme();

    expect(restored.darkMode, isTrue);
  });

  test(
    'statistics exercise and metric choices persist per local profile',
    () async {
      final exerciseId = catalog.first.id;
      final first = AppController();
      addTearDown(first.dispose);
      await first.setTrackedExercises([exerciseId, exerciseId, 'missing']);
      await first.setTrackedExerciseMetric('reps');

      final restored = AppController();
      addTearDown(restored.dispose);
      await restored.hydratePersonalAgentData();
      expect(restored.trackedExerciseIds, [exerciseId]);
      expect(restored.trackedExerciseMetric, 'reps');
    },
  );

  test(
    'exercise numbers stay one-based and searchable after soft deletion',
    () {
      final controller = AppController();
      addTearDown(controller.dispose);
      final first = catalog.first;
      expect(controller.exerciseNumberFor(first), 1);
      controller.search = '1';
      expect(
        controller.visibleExercises.map((item) => item.id),
        contains(first.id),
      );
      expect(selectableCatalog.length, lessThan(catalog.length - 300));
    },
  );

  test('nutrition entries use sequential meal labels', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    expect(controller.nextMealLabelFor(now), '第1餐');
    await controller.addNutritionEntry(
      NutritionEntry(
        id: 'meal-one',
        recordedAt: now,
        mealType: controller.nextMealLabelFor(now),
        foodName: '鸡胸肉',
        calories: 220,
      ),
    );
    expect(controller.nextMealLabelFor(now), '第2餐');
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI plan-reading advice streams after local tool execution', () async {
    final api = _StreamingAgentCoachApi();
    final controller = AppController(coachApi: api);
    try {
      await controller.sendChat('直接查看我的训练计划并给出建议');

      expect(api.streamedToolContinuation, isTrue);
      expect(controller.chat.last.body, '你的计划可以这样调整');
      expect(controller.aiToolUses.single.name, 'read_training_plans');
    } finally {
      controller.dispose();
    }
  });

  test('AI customized plan accepts all published read-only tools', () async {
    final api = _StreamingAgentCoachApi(toolCallCount: 5);
    final controller = AppController(coachApi: api);
    try {
      await controller.requestAiCustomizedWorkout(details: '每周训练四天');

      expect(api.streamedToolContinuation, isTrue);
      expect(controller.chat.last.body, '你的计划可以这样调整');
      expect(controller.aiToolUses.single.count, 5);
      expect(controller.aiToolError, isNull);
    } finally {
      controller.dispose();
    }
  });

  test('agent tool registry exposes approved read-only agent data tools', () {
    final controller = AppController();
    try {
      expect(controller.aiUseTrainingData, isTrue);
      final names = controller.aiAvailableTools
          .map((item) => (item['function'] as Map)['name'])
          .toList();
      expect(names, [
        'read_training_intelligence',
        'read_training_plans',
        'read_workout_history',
        'read_active_workout',
        'read_nutrition_history',
      ]);

      final plansBefore = controller.routines.length;
      final historyBefore = controller.history.length;
      final planResult = controller.executeAiTool(
        const CoachToolCall(
          id: 'plans',
          name: 'read_training_plans',
          arguments: {},
        ),
      );
      final historyResult = controller.executeAiTool(
        const CoachToolCall(
          id: 'history',
          name: 'read_workout_history',
          arguments: {},
        ),
      );
      final activeResult = controller.executeAiTool(
        const CoachToolCall(
          id: 'active',
          name: 'read_active_workout',
          arguments: {},
        ),
      );

      expect(planResult['tool'], 'read_training_plans');
      expect(historyResult['tool'], 'read_workout_history');
      expect(activeResult['tool'], 'read_active_workout');
      expect(activeResult['active'], false);
      expect(controller.routines.length, plansBefore);
      expect(controller.history.length, historyBefore);
      expect(
        () => controller.executeAiTool(
          const CoachToolCall(
            id: 'write',
            name: 'delete_all_data',
            arguments: {},
          ),
        ),
        throwsArgumentError,
      );
    } finally {
      controller.dispose();
    }
  });

  test(
    'AI skills support create update delete and a three-enabled limit',
    () async {
      final api = _CapturingCoachApi();
      final controller = AppController(coachApi: api);
      try {
        for (var index = 1; index <= 3; index++) {
          expect(
            controller.saveAiSkill(
              name: 'Skill $index',
              instructions: 'Focus on rule $index',
            ),
            isTrue,
          );
        }
        expect(
          controller.saveAiSkill(
            name: 'Skill 4',
            instructions: 'Focus on rule 4',
          ),
          isFalse,
        );
        for (final skill in controller.aiSkills.take(3)) {
          expect(controller.setAiSkillEnabled(skill.id, true), isTrue);
        }
        final first = controller.aiSkills.first;
        controller.saveAiSkill(
          id: first.id,
          name: 'Updated skill',
          instructions: 'Updated instructions',
        );
        expect(controller.aiSkills.first.name, 'Updated skill');

        await controller.sendChat('test skills');
        expect(api.skills, hasLength(3));
        expect(api.skills.first['name'], 'Updated skill');

        controller.deleteAiSkill(first.id);
        expect(controller.aiSkills.any((item) => item.id == first.id), isFalse);
        expect(controller.enabledAiSkills, hasLength(2));
      } finally {
        controller.dispose();
      }
    },
  );

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

  test(
    'AI can compare multiple selected workout records with dates and notes',
    () async {
      final api = _CapturingCoachApi();
      final controller = AppController(coachApi: api);
      try {
        WorkoutRecord record(String id, int day, double weight, String note) =>
            WorkoutRecord(
              id: id,
              name: '胸部训练',
              date: DateTime(2026, 8, day),
              startTime: '18:00',
              durationSeconds: 3000,
              volume: weight * 24,
              effectiveSets: 3,
              note: note,
              exerciseIds: const ['bench_press'],
              exercises: [
                WorkoutExercise(
                  id: 'exercise-$id',
                  exerciseId: 'bench_press',
                  sets: [
                    WorkoutSet(
                      id: 'set-$id',
                      weight: weight,
                      reps: 8,
                      completed: true,
                      note: '最后一组偏慢',
                    ),
                  ],
                ),
              ],
            );
        controller.history
          ..clear()
          ..addAll([
            record('recent', 12, 60, '右肩略紧'),
            record('older', 5, 65, '睡眠不足'),
          ]);

        final selected = controller.availableAiContexts
            .where((item) => item.type == AiContextType.workoutRecord)
            .toList();
        await controller.sendChat('为什么重量变轻了？', contexts: selected);

        expect(api.trainingSummary, contains('2026-08-12'));
        expect(api.trainingSummary, contains('2026-08-05'));
        expect(api.trainingSummary, contains('60.0 kg×8'));
        expect(api.trainingSummary, contains('65.0 kg×8'));
        expect(api.trainingSummary, contains('右肩略紧'));
        expect(api.trainingSummary, contains('睡眠不足'));
      } finally {
        controller.dispose();
      }
    },
  );

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

  test('Apple Watch bridge receives exercise icon, rest and completion action', () async {
    const channel = MethodChannel('kilo.platform.timer');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getAppleWatchStatus') return true;
          return null;
        });

    final controller = AppController();
    try {
      final exercise = controller.createBlankWorkoutExercise(
        'bench_press',
        'watch-bench',
      )..restSeconds = 75;
      exercise.sets.add(
        WorkoutSet(id: 'watch-set', reps: 8, restSeconds: 75),
      );
      controller.startWorkout(source: [exercise], name: '手表训练');
      await Future<void>.delayed(Duration.zero);

      final start = calls.lastWhere((call) => call.method == 'startWorkout');
      final startArguments = start.arguments! as Map<Object?, Object?>;
      expect(startArguments['exercise'], isNotEmpty);
      expect(startArguments['exerciseSymbol'], isNotEmpty);
      expect(startArguments['nextRestSeconds'], 75);
      expect(controller.appleWatch, isTrue);

      final liveExercise = controller.workout.single;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('completeSetFromNotification', {'completedSets': 1}),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(liveExercise.sets.first.completed, isTrue);
      expect(controller.restRunning, isTrue);
      expect(controller.restRemainingSeconds, 75);
      expect(calls.map((call) => call.method), contains('startTimer'));
    } finally {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('prepared workout becomes active only when its timer starts', () {
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

      expect(controller.workoutStarted, isFalse);
      expect(controller.workoutDraft, isTrue);
      expect(controller.workoutTimerStarted, isFalse);
      controller.beginWorkoutTimer();

      expect(controller.workoutStarted, isTrue);
      expect(controller.workoutDraft, isFalse);
      expect(controller.workoutTimerStarted, isTrue);
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
      expect(controller.workoutDraft, isFalse);
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

  test(
    'aborting an active workout discards it without creating history',
    () async {
      const channel = MethodChannel('kilo.platform.timer');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
      final persistence = InMemoryActiveWorkoutPersistence();
      final account = AccountService()..loginWithPhone('abort-user');
      final controller = AppController(
        accountService: account,
        activeWorkoutPersistence: persistence,
      );
      try {
        controller.startWorkout(name: '不会保存的训练');
        controller.addExercise('bench_press');
        final exercise = controller.workout.single;
        controller.addSet(exercise);
        exercise.sets.single
          ..weight = 60
          ..reps = 8
          ..completed = true;
        controller.persistActiveWorkout();
        await controller.flushActiveWorkoutPersistence();

        controller.abortWorkout();
        await controller.flushActiveWorkoutPersistence();

        expect(controller.workoutStarted, isFalse);
        expect(controller.workout, isEmpty);
        expect(controller.history, isEmpty);
        expect(await persistence.read(account.currentUser!.id), isNull);
        expect(calls, contains('finishTimer'));
      } finally {
        controller.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );

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
    'free-workout asks once for rest, then applies it to the session',
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
        expect(exercise.restSeconds, 0);
        expect(exercise.sets.single.restSeconds, 0);
        final burstBefore = controller.completionBurstId;
        controller.completeSet(exercise.sets.single, exercise);
        await Future<void>.delayed(Duration.zero);
        expect(controller.restRunning, isFalse);
        expect(controller.restRemainingSeconds, 0);
        expect(controller.restSetupPending, isTrue);
        expect(controller.pendingRestSetId, exercise.sets.single.id);
        expect(calls, isNot(contains('startTimer')));
        expect(controller.completionBurstId, burstBefore + 1);
        controller.completeSet(exercise.sets.single, exercise);
        expect(controller.completionBurstId, burstBefore + 1);

        // Re-complete the set and confirm the one-time setup. A confirmation
        // starts the pending set's rest immediately and fills future rows.
        controller.completeSet(exercise.sets.single, exercise);
        controller.applyInitialRestSeconds(180);
        expect(controller.restSetupPending, isFalse);
        expect(controller.defaultRestSeconds, 180);
        expect(controller.restRunning, isTrue);
        expect(controller.restRemainingSeconds, 180);

        controller.addExercise('squat');
        final secondExercise = controller.workout.last;
        controller.addSet(secondExercise);
        expect(secondExercise.restSeconds, 180);
        expect(secondExercise.sets.single.restSeconds, 180);
        controller.completeSet(secondExercise.sets.single, secondExercise);
        await Future<void>.delayed(Duration.zero);
        expect(controller.restRunning, isTrue);
        expect(controller.restRemainingSeconds, 180);

        controller.completeSet(secondExercise.sets.single, secondExercise);
      } finally {
        controller.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );

  test('new exercises inherit the first exercise rest duration', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '继承休息时间');
      controller.addExercise('bench_press');
      final first = controller.workout.first;
      controller.updateExerciseRest(first, 95);

      controller.addExercise('squat');
      controller.addExercises(const ['deadlift', 'shoulder_press']);

      expect(controller.workout, hasLength(4));
      for (final exercise in controller.workout.skip(1)) {
        expect(exercise.restSeconds, 95);
        expect(exercise.sets.every((set) => set.restSeconds == 95), isTrue);
      }
    } finally {
      controller.dispose();
    }
  });

  test('lock-screen completion appends and completes an extra set', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '锁屏加组');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      final first = exercise.sets.single
        ..weight = 72.5
        ..reps = 9;
      controller.completeSet(first, exercise);
      controller.skipRest();

      controller.syncCompletedSetsFromSystem(2);

      expect(exercise.sets, hasLength(2));
      final extra = exercise.sets.last;
      expect(extra.completed, isTrue);
      expect(extra.weight, 72.5);
      expect(extra.reps, 9);
      expect(extra.plannedWeight, isNull);
      expect(controller.completedSets, 2);
      expect(controller.totalSets, 2);
    } finally {
      controller.dispose();
    }
  });

  test('active rest edit becomes the default for all upcoming sets', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '统一休息');
      controller.addExercise('bench_press');
      controller.addExercise('squat');
      final first = controller.workout.first;
      final second = controller.workout.last;
      controller.addSet(first);
      controller.addSet(first);
      controller.addSet(second);
      first.sets.first.completed = true;
      controller.startRest(exercise: '器械推胸', seconds: 53);

      controller.updateActiveAndUpcomingRest(90);

      expect(controller.restRemainingSeconds, 90);
      expect(controller.defaultRestSeconds, 90);
      expect(first.restSeconds, 90);
      expect(second.restSeconds, 90);
      expect(first.sets.first.restSeconds, isNot(90));
      expect(first.sets.last.restSeconds, 90);
      expect(second.sets.single.restSeconds, 90);
    } finally {
      controller.dispose();
    }
  });

  test('rest countdown uses its wall-clock deadline after background time', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '后台计时');
      controller.startRest(exercise: '器械推胸', seconds: 180);
      final startedAt = DateTime.now();

      controller.reconcileRestClock(startedAt.add(const Duration(seconds: 60)));

      expect(controller.restRunning, isTrue);
      expect(controller.restRemainingSeconds, inInclusiveRange(119, 120));
      controller.reconcileRestClock(
        startedAt.add(const Duration(seconds: 181)),
      );
      expect(controller.restRunning, isFalse);
      expect(controller.restRemainingSeconds, 0);
    } finally {
      controller.dispose();
    }
  });

  test('finished workout PRs cite the previous same-exercise record', () {
    final controller = AppController();
    try {
      final baselineDate = DateTime(2026, 8, 10);
      controller.history.add(
        WorkoutRecord(
          id: 'baseline-bench',
          name: '上次胸部训练',
          date: baselineDate,
          startTime: '18:00',
          durationSeconds: 1800,
          volume: 1920,
          effectiveSets: 3,
          exerciseIds: const ['bench_press'],
          exercises: [
            WorkoutExercise(
              id: 'baseline-exercise',
              exerciseId: 'bench_press',
              sets: [
                WorkoutSet(
                  id: 'baseline-set',
                  weight: 80,
                  reps: 8,
                  completed: true,
                ),
              ],
            ),
          ],
        ),
      );
      controller.startWorkout(name: '本次胸部训练');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      exercise.sets.single
        ..weight = 82.5
        ..reps = 8
        ..completed = true;

      final record = controller.finishWorkout()!;

      expect(record.prDetails, isNotEmpty);
      expect(
        record.prDetails.map((item) => item.metric),
        containsAll(<String>['estimated1rm', 'weight', 'volume']),
      );
      for (final detail in record.prDetails) {
        expect(detail.previousRecordId, 'baseline-bench');
        expect(detail.previousDate, baselineDate);
        expect(detail.currentValue, greaterThan(detail.previousValue));
      }
    } finally {
      controller.dispose();
    }
  });

  test('first exercise record establishes a baseline instead of a fake PR', () {
    final controller = AppController();
    try {
      controller.startWorkout(name: '第一次训练');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      exercise.sets.single
        ..weight = 60
        ..reps = 8
        ..completed = true;

      final record = controller.finishWorkout()!;

      expect(record.prDetails, isEmpty);
      expect(record.prs, isEmpty);
    } finally {
      controller.dispose();
    }
  });

  test('authenticated redemption replaces the local entitlement', () async {
    final requests = <http.Request>[];
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/v1/redemptions/redeem') {
          return http.Response(
            jsonEncode({
              'entitlement': {
                'membership': 'threeMonths',
                'membershipExpiresAt': '2026-12-04T00:00:00.000Z',
                'aiRemaining': 20,
                'aiDailyLimit': 20,
                'recognitionRemaining': 5,
                'recognitionWeeklyGrant': 3,
              },
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    api.restoreSession(
      const RemoteSession(
        token: 'redemption-session',
        accountIdentifier: '+8613800138000',
        apiOrigin: 'https://api.example.test',
      ),
      accountIdentifier: '+8613800138000',
    );
    final account = AccountService(persistence: InMemoryAccountPersistence())
      ..loginAuthenticatedRemote(
        identifier: '+8613800138000',
        displayName: '13800138000',
        isAdmin: false,
      );
    final controller = AppController(accountService: account, coachApi: api);
    try {
      final result = await controller.redeemCode(' pro-2026 ');

      expect(result.isSuccess, isTrue);
      expect(controller.entitlements?.membership, MembershipPlan.threeMonths);
      final redeemRequest = requests.singleWhere(
        (request) => request.url.path == '/v1/redemptions/redeem',
      );
      expect(
        redeemRequest.headers['authorization'],
        'Bearer redemption-session',
      );
      expect(jsonDecode(redeemRequest.body), {'code': 'PRO-2026'});
    } finally {
      controller.dispose();
    }
  });

  test(
    'workout trial activation observes duration and effective-set boundaries',
    () async {
      Future<List<http.Request>> finishAndCapture({
        required int durationSeconds,
        required bool completeSet,
      }) async {
        final requests = <http.Request>[];
        final firstRequest = Completer<void>();
        final identifier = 'trial-boundary-$durationSeconds-$completeSet';
        final api = HttpCoachApi(
          baseUrl: 'https://api.example.test',
          client: MockClient((request) async {
            requests.add(request);
            if (!firstRequest.isCompleted) firstRequest.complete();
            return http.Response('{"error":"trial_test"}', 500);
          }),
        );
        api.restoreSession(
          RemoteSession(
            token: 'trial-session',
            accountIdentifier: identifier,
            apiOrigin: 'https://api.example.test',
          ),
          accountIdentifier: identifier,
        );
        final account = AccountService(
          persistence: InMemoryAccountPersistence(),
        )..loginWithPhone(identifier);
        final controller = AppController(
          accountService: account,
          coachApi: api,
        );
        try {
          controller.startWorkout(name: '试用边界训练', autoStartTimer: false);
          controller.addExercise('bench_press');
          final exercise = controller.workout.single;
          controller.addSet(exercise);
          exercise.sets.single.completed = completeSet;
          controller.workoutElapsedSeconds = durationSeconds;
          controller.finishWorkout();
          if (durationSeconds >= 1800 && completeSet) {
            await firstRequest.future.timeout(const Duration(seconds: 1));
          } else {
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          // A second finish call has no active workout and must not enqueue a
          // duplicate activation request.
          controller.finishWorkout();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return requests;
        } finally {
          controller.dispose();
        }
      }

      expect(
        await finishAndCapture(durationSeconds: 1799, completeSet: true),
        isEmpty,
      );
      expect(
        await finishAndCapture(durationSeconds: 1800, completeSet: false),
        isEmpty,
      );
      final qualifying = await finishAndCapture(
        durationSeconds: 1800,
        completeSet: true,
      );
      expect(qualifying, hasLength(1));
      expect(qualifying.single.url.path, '/v1/membership/trial/activate');
      expect(jsonDecode(qualifying.single.body), {
        'workoutId': isA<String>(),
        'durationSeconds': 1800,
        'effectiveSets': 1,
      });
    },
  );

  test('previous value action is available only for matching history', () {
    final controller = AppController();
    try {
      controller.history.add(
        WorkoutRecord(
          id: 'history-with-bench',
          name: '历史卧推',
          date: DateTime(2026, 8, 1),
          startTime: '18:00',
          durationSeconds: 900,
          volume: 600,
          effectiveSets: 1,
          exerciseIds: const ['bench_press'],
          exercises: [
            WorkoutExercise(
              id: 'history-exercise',
              exerciseId: 'bench_press',
              sets: [
                WorkoutSet(
                  id: 'history-set',
                  weight: 60,
                  reps: 10,
                  completed: true,
                ),
              ],
            ),
          ],
        ),
      );
      final bench = controller.createBlankWorkoutExercise(
        'bench_press',
        'bench',
      );
      final squat = controller.createBlankWorkoutExercise('squat', 'squat');
      expect(controller.hasPreviousValues(bench), isTrue);
      expect(controller.hasPreviousValues(squat), isFalse);
    } finally {
      controller.dispose();
    }
  });

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

  test(
    'prepared workout survives recreation without becoming active',
    () async {
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
      first.startWorkout(name: '待开始训练', autoStartTimer: false);
      first.addExercise('bench_press');
      await first.flushActiveWorkoutPersistence();
      first.dispose();

      final restored = AppController(
        accountService: signedInAccount(),
        activeWorkoutPersistence: persistence,
      );
      try {
        await restored.hydrateActiveWorkout();

        expect(restored.workoutDraft, isTrue);
        expect(restored.workoutStarted, isFalse);
        expect(restored.workoutTimerStarted, isFalse);
        expect(restored.workoutName, '待开始训练');
        expect(restored.workout, hasLength(1));

        restored.beginWorkoutTimer();
        expect(restored.workoutDraft, isFalse);
        expect(restored.workoutStarted, isTrue);
      } finally {
        restored.abortWorkout();
        await restored.flushActiveWorkoutPersistence();
        restored.dispose();
      }
    },
  );

  test('active rest deadline survives process recreation', () async {
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
    first.startWorkout(name: '休息恢复测试');
    first.startRest(exercise: '器械推胸', seconds: 180);
    await first.flushActiveWorkoutPersistence();
    first.dispose();

    final restored = AppController(
      accountService: signedInAccount(),
      activeWorkoutPersistence: persistence,
    );
    try {
      await restored.hydrateActiveWorkout();

      expect(restored.restRunning, isTrue);
      expect(restored.restExerciseName, '器械推胸');
      expect(restored.restRemainingSeconds, inInclusiveRange(178, 180));
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

  test('previous set follows latest exact exercise across workout names', () {
    final controller = AppController();
    WorkoutRecord record({
      required String id,
      required String exerciseId,
      required DateTime date,
      required double weight,
      int sets = 1,
    }) => WorkoutRecord(
      id: id,
      name: id == 'newer' ? '完全不同的计划' : '旧计划',
      date: date,
      startTime: '10:00',
      durationSeconds: 1200,
      volume: weight * 8 * sets,
      effectiveSets: sets,
      exerciseIds: [exerciseId],
      exercises: [
        WorkoutExercise(
          id: '$id-exercise',
          exerciseId: exerciseId,
          sets: [
            for (var index = 0; index < sets; index++)
              WorkoutSet(
                id: '$id-set-$index',
                weight: weight + index,
                reps: 8,
                completed: true,
              ),
          ],
        ),
      ],
    );
    try {
      // Deliberately insert out of chronological order to verify that storage
      // order and workout name do not affect the selected exercise history.
      controller.history
        ..add(
          record(
            id: 'newer',
            exerciseId: 'bench_press',
            date: DateTime(2026, 8, 24),
            weight: 82.5,
          ),
        )
        ..add(
          record(
            id: 'older',
            exerciseId: 'bench_press',
            date: DateTime(2026, 8, 20),
            weight: 70,
            sets: 3,
          ),
        )
        ..add(
          record(
            id: 'other',
            exerciseId: 'dumbbell_bench_press',
            date: DateTime(2026, 8, 25),
            weight: 100,
          ),
        );

      expect(controller.previousSetFor('bench_press', 0)?.weight, 82.5);
      // The latest bench session had one set, so a new second row repeats that
      // session instead of leaking the older plan's second set.
      expect(controller.previousSetFor('bench_press', 1)?.weight, 82.5);
      expect(controller.previousSetFor('dumbbell_bench_press', 0)?.weight, 100);
      expect(
        controller.exerciseHistoryFor('bench_press').map((item) => item.id),
        ['newer', 'older'],
      );
    } finally {
      controller.dispose();
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
                note: '肩胛稳定，杠铃稳定触胸。',
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
      expect(controller.routines.single.exercises.single.note, '肩胛稳定，杠铃稳定触胸。');
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

  test('completion comparison prefers the previous session with same plan', () {
    final controller = AppController();
    try {
      WorkoutRecord record({
        required String id,
        required String name,
        required DateTime date,
        required double weight,
        required int reps,
      }) {
        final exercise = WorkoutExercise(
          id: '$id-exercise',
          exerciseId: 'bench_press',
          sets: [
            WorkoutSet(
              id: '$id-set',
              weight: weight,
              reps: reps,
              completed: true,
            ),
          ],
        );
        return WorkoutRecord(
          id: id,
          name: name,
          date: date,
          startTime: '18:00',
          durationSeconds: 2400,
          volume: weight * reps,
          effectiveSets: 1,
          exerciseIds: const ['bench_press'],
          exercises: [exercise],
        );
      }

      final baseline = record(
        id: 'previous-plan',
        name: '上肢 A',
        date: DateTime(2026, 8, 10),
        weight: 70,
        reps: 8,
      );
      final newerDifferentName = record(
        id: 'newer-overlap',
        name: '临时训练',
        date: DateTime(2026, 8, 12),
        weight: 75,
        reps: 6,
      );
      final current = record(
        id: 'current-plan',
        name: '上肢 A',
        date: DateTime(2026, 8, 14),
        weight: 75,
        reps: 9,
      );
      controller.history.addAll([current, newerDifferentName, baseline]);

      final comparison = controller.comparisonFor(current);
      expect(comparison?.baseline.id, baseline.id);
      expect(comparison?.volumeDelta, 115);
      expect(comparison?.exerciseProgress.single.weightDelta, 5);
      expect(comparison?.exerciseProgress.single.repsDelta, 1);
    } finally {
      controller.dispose();
    }
  });
}
