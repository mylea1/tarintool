import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_details_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('folder deletion preserves plans and unfiles them', () {
    final c = AppController();
    addTearDown(c.dispose);
    c.saveRoutineFromDraft('测试', [
      WorkoutExercise(
        id: 'e',
        exerciseId: 'bench_press',
        sets: [WorkoutSet(id: 's', weight: 42, reps: 9)],
      ),
    ]);
    final routine = c.routines.last;
    expect(routine.folder, '');
    c.addRoutineFolder('推日');
    c.moveRoutine(routine, '推日');
    c.deleteRoutineFolder('推日');
    expect(c.routines, contains(routine));
    expect(routine.folder, '');
    expect(routine.exercises.single.sets.single.weight, 42);
    expect(c.routineFolders, isNot(contains('推日')));
  });
  test('finishing stores optional plan in selected folder or unfiled', () {
    final c = AppController();
    addTearDown(c.dispose);
    for (final folder in ['', '上肢']) {
      c.startWorkout(name: '测试');
      c.addExercise('bench_press');
      c.addSet(c.workout.single);
      c.finishWorkout(saveAsRoutine: true, routineFolder: folder);
      expect(c.routines.first.folder, folder);
    }
  });
  test('friend plan saves independently without implicit folder', () {
    final c = AppController();
    addTearDown(c.dispose);
    c.saveFriendPlan({
      'name': '朋友的计划',
      'plan': {
        'exercises': [
          {
            'exerciseId': 'bench_press',
            'sets': [
              {'weight': 55, 'reps': 12},
            ],
          },
        ],
      },
    });
    expect(c.routines.last.folder, '');
    expect(c.routines.last.exercises.single.sets.single.reps, 12);
    expect(c.routines.last.exercises.single.sets.single.weight, 55);
  });
  testWidgets('ordinary summaries stay compact for long workouts', (
    tester,
  ) async {
    for (final count in [2, 20]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingDetailsCard(
              title: '训练记录',
              exercises: List.generate(
                count,
                (i) => WorkoutExercise(
                  id: '$i',
                  exerciseId: 'bench_press',
                  sets: List.generate(
                    12,
                    (j) => WorkoutSet(id: '$i-$j', weight: 50, reps: 10),
                  ),
                ),
              ),
              nameFor: (_) => '卧推',
              summary: '60 分钟 · 3000 kg · 12 组',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TrainingDetailsCard)).height,
        lessThan(220),
      );
      expect(find.textContaining('kg ×'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'long friend preview opens every exercise without losing set data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrainingDetailsCard(
                branded: true,
                title: '好友训练',
                exercises: List.generate(
                  20,
                  (i) => WorkoutExercise(
                    id: '$i',
                    exerciseId: 'bench_press',
                    sets: [WorkoutSet(id: '$i', weight: 52.5, reps: 12)],
                  ),
                ),
                nameFor: (_) => '卧推',
                summary: '45 分钟',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('卧推'), findsNWidgets(3));
      expect(find.text('另 17 个动作 · 点击查看'), findsOneWidget);
      expect(find.text('45 分钟'), findsNothing);
      await tester.tap(find.byType(TrainingDetailsCard));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TrainingExerciseDetails),
          matching: find.text('卧推'),
        ),
        findsNWidgets(20),
      );
      expect(find.textContaining('52.5 kg × 12 次'), findsNWidgets(20));
      expect(find.text('45 分钟'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 375.0, 414.0]) {
    testWidgets('detailed card wraps at $width and large text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TrainingDetailsCard(
                  branded: true,
                  title: '很长的训练名称用于验证卡片布局不会溢出',
                  exercises: [
                    WorkoutExercise(
                      id: 'e',
                      exerciseId: 'bench_press',
                      sets: [
                        WorkoutSet(id: '1', weight: 52.5, reps: 12),
                        WorkoutSet(id: '2', weight: 50, reps: 10),
                      ],
                    ),
                  ],
                  nameFor: (_) => '单臂高位器械划船超长动作名称测试',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('52.5 kg × 12 次'), findsNothing);
      await tester.tap(find.byType(TrainingDetailsCard));
      await tester.pumpAndSettle();
      expect(find.textContaining('52.5 kg × 12 次'), findsOneWidget);
      expect(find.textContaining('50 kg × 10 次'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
