import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CapturingCoach implements CoachApi {
  String? summary;
  String? prompt;
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
    this.prompt = prompt;
    summary = trainingSummary;
    return const CoachAnswer(body: '已根据本次训练回答');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppController controller() {
    final c = AppController(coachApi: CapturingCoach());
    c.startWorkout(
      source: [
        WorkoutExercise(
          id: 'live',
          exerciseId: 'bench_press',
          note: '动作备注',
          sets: [
            WorkoutSet(id: 's1', weight: 60, reps: 8, note: '第一组备注'),
            WorkoutSet(id: 's2', weight: 60, reps: 8),
          ],
        ),
      ],
      name: '胸部训练',
      autoStartTimer: false,
    );
    c.workout.first.sets.first.completed = true;
    return c;
  }

  test(
    'fresh snapshot separates completed sets and keeps per-set notes; normal chat untouched',
    () async {
      final c = controller();
      addTearDown(c.dispose);
      await c.requestWorkoutCoach('为什么第二组下降', selectedIds: ['bench_press']);
      final api = c.coachApi as CapturingCoach;
      final data = jsonDecode(api.summary!) as Map;
      final sets = data['training']['exercises'][0]['sets'] as List;
      expect(sets[0]['completed'], true);
      expect(sets[1]['completed'], false);
      expect(sets[0]['note'], '第一组备注');
      expect(data['selectedExerciseIds'], ['bench_press']);
      expect(api.prompt, contains('默认替换'));
      expect(c.chat, isEmpty);
      c.workout.first.sets[1].reps = 6;
      await c.requestWorkoutCoach('现在呢');
      expect(
        jsonDecode(api.summary!)['training']['exercises'][0]['sets'][1]['reps'],
        6,
      );
    },
  );
  test(
    'apply remaining plan preserves completed set, undo guarded after new records',
    () {
      final c = controller();
      addTearDown(c.dispose);
      final before = c.workout.map((e) => e.copy()).toList();
      final plan = c.remainingCoachPlan();
      c.applyCoachRemainingPlan(plan, c.coachWorkoutFingerprint);
      expect(c.workout.first.sets.single.completed, true);
      expect(c.workout.first.sets.single.note, '第一组备注');
      expect(c.workout.last.sets.single.completed, false);
      final applied = c.coachWorkoutFingerprint;
      c.restoreCoachWorkout(before, applied);
      expect(c.workout.single.sets.length, 2);
      c.workout.single.sets[1].completed = true;
      expect(() => c.applyCoachRemainingPlan(plan, applied), throwsStateError);
    },
  );
  test(
    'plan edit round trip changes draft only and keeps schedule offsets',
    () {
      final c = controller();
      addTearDown(c.dispose);
      final original = c.remainingCoachPlan();
      final draft = c.editableCoachPlan(original);
      draft.first.exercises.first.sets.first
        ..plannedWeight = 65
        ..reps = 10
        ..restSeconds = 180;
      final next = c.coachPlanFromRoutines('新计划', 2, draft, dayOffsets: [4]);
      expect(next.sessions.single.dayOffset, 4);
      expect(next.sessions.single.exercises.single.sets.single.weight, 65);
      expect(original.sessions.single.exercises.single.sets.single.weight, 60);
      expect(c.routines.where((r) => r.name == '新计划'), isEmpty);
    },
  );
  test('large snapshots stay within server limit with valid JSON', () {
    final c = controller();
    addTearDown(c.dispose);
    for (var i = 0; i < 60; i++) {
      c.workout.add(c.workout.first.copy(newId: 'copy$i'));
    }
    final result = c.boundedWorkoutCoachSnapshot(['bench_press']);
    expect(result.length, lessThanOrEqualTo(5800));
    expect(jsonDecode(result)['trainingTruncated'], isNotNull);
  });
  testWidgets(
    'small-screen training coach opens, sends selected exercise, reopens with history',
    (tester) async {
      final c = controller();
      addTearDown(c.dispose);
      c.openLiveWorkout();
      c.selectPage(PageId.train);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: KiloShell(controller: c)));
      await tester.tap(find.byKey(const Key('workout-coach-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilterChip).last);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('workout-coach-input')),
        '这个动作怎么练',
      );
      await tester.tap(find.byKey(const Key('workout-coach-send')));
      await tester.pumpAndSettle();
      expect(c.workoutCoachMessages.first.body, contains('这个动作怎么练'));
      expect(c.workoutCoachMessages.last.body, '已根据本次训练回答');
      expect(c.chat, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workout-coach-open')));
      await tester.pumpAndSettle();
      expect(find.text('已根据本次训练回答'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
