import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(exercise.sets.last.weight, 62.5);
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

  test('free workout rest settings and zero rest do not start timer', () async {
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
      expect(calls, isNot(contains('startTimer')));
      expect(controller.completionBurstId, burstBefore + 1);
      controller.completeSet(exercise.sets.single, exercise);
      expect(controller.completionBurstId, burstBefore + 1);

      controller.updateExerciseRest(exercise, 45);
      expect(exercise.restSeconds, 45);
      expect(exercise.sets.single.restSeconds, 45);
      controller.completeSet(exercise.sets.single, exercise);
      await Future<void>.delayed(Duration.zero);
      expect(controller.restRunning, isTrue);
      expect(calls, contains('startTimer'));
    } finally {
      controller.dispose();
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
}
