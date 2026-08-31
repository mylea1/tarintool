import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';

void main() {
  testWidgets('live exercise history reveals notes from the selected session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.history.add(
      WorkoutRecord(
        id: 'history-notes',
        name: '胸部训练',
        date: DateTime(2026, 8, 20),
        startTime: '18:30',
        durationSeconds: 1800,
        volume: 1920,
        effectiveSets: 1,
        note: '整次训练右肩状态良好',
        exerciseIds: const ['bench_press'],
        exercises: [
          WorkoutExercise(
            id: 'history-exercise',
            exerciseId: 'bench_press',
            note: '座椅第 6 档',
            sets: [
              WorkoutSet(
                id: 'history-set',
                weight: 80,
                reps: 8,
                completed: true,
                note: '最后两次速度变慢',
              ),
            ],
          ),
        ],
      ),
    );
    controller.startWorkout(name: '自由训练', autoStartTimer: false);
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();

    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('previous-notes-bench_press')), findsOneWidget);
    expect(
      find.byKey(const Key('previous-exercise-note-bench_press')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('previous-set-note-bench_press-0')),
      findsOneWidget,
    );
    final historyButton = find.byKey(
      Key('exercise-history-${controller.workout.single.id}'),
    );
    await tester.scrollUntilVisible(
      historyButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(historyButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('座椅第 6 档'), findsWidgets);
    expect(find.textContaining('最后两次速度变慢'), findsWidgets);
    expect(find.textContaining('整次训练右肩状态良好'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('exercise-history-record-history-notes')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('record-detail-history-notes')),
      findsOneWidget,
    );
    expect(find.textContaining('动作备注 · 座椅第 6 档'), findsWidgets);
  });
}
