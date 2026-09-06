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
      expect(find.textContaining('52.5 kg × 12 次'), findsOneWidget);
      expect(find.textContaining('50 kg × 10 次'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
