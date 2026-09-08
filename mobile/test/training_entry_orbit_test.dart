import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'empty preparation is new, active workout resumes without resetting time',
    () {
      final c = AppController();
      addTearDown(c.dispose);
      c.startWorkout(autoStartTimer: false);
      expect(c.canResumeWorkout, isFalse);
      c.openNewOrResumeWorkout();
      expect(c.workoutTimerStarted, isFalse);
      c.addExercise('bench_press');
      c.beginWorkoutTimer();
      final exerciseId = c.workout.single.id;
      c.workoutElapsedSeconds = 75;
      c.selectPage(PageId.today);
      expect(c.canResumeWorkout, isTrue);
      c.openNewOrResumeWorkout();
      expect(c.workout.single.id, exerciseId);
      expect(c.workoutElapsedSeconds, 75);
      expect(c.workoutTimerStarted, isTrue);
    },
  );

  testWidgets('folders expand independently and unfiled plans stay visible', (
    tester,
  ) async {
    final c = AppController();
    addTearDown(c.dispose);
    c.saveRoutineFromDraft('文件夹内计划', [
      c.createBlankWorkoutExercise('bench_press', 'filed'),
    ], folder: '力量');
    c.saveRoutineFromDraft('独立计划', [
      c.createBlankWorkoutExercise('bench_press', 'loose'),
    ]);
    c.selectPage(PageId.train);
    c.selectTrainView(TrainView.plans);
    await tester.pumpWidget(KiloApp(initialController: c));
    await tester.pumpAndSettle();
    final folder = find.byKey(const ValueKey('plan-folder-力量'));
    await Scrollable.ensureVisible(tester.element(folder), alignment: .2);
    await tester.pumpAndSettle();
    expect(find.text('文件夹内计划'), findsNothing);
    expect(find.text('独立计划'), findsOneWidget);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(find.text('文件夹内计划'), findsOneWidget);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(find.text('文件夹内计划'), findsNothing);
  });

  testWidgets('first training tap expands even with a restored workout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = AppController();
    addTearDown(c.dispose);
    c.startWorkout(
      source: [c.createBlankWorkoutExercise('bench_press', 'restored')],
    );
    c.selectPage(PageId.today);
    await tester.pumpWidget(KiloApp(initialController: c));
    await tester.pumpAndSettle();
    final original = c.workout.first.id;
    await tester.tap(find.byKey(const Key('global-training-entry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('training-menu-plans')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('training-menu-new')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('返回\n训练'), findsOneWidget);
    await tester.tap(find.byKey(const Key('training-menu-new')));
    await tester.pumpAndSettle();
    expect(c.workout.first.id, original);
    expect(c.liveWorkoutVisible, isTrue);
    c.abortWorkout();
  });

  testWidgets(
    'AI moves immediately after swipe threshold but tiny motion remains a tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = AppController();
      addTearDown(c.dispose);
      c.startWorkout(autoStartTimer: false);
      c.openLiveWorkout();
      await tester.pumpWidget(KiloApp(initialController: c));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('workout-coach-open'));
      final before = tester.getCenter(button);
      final drag = await tester.startGesture(before);
      await drag.moveBy(const Offset(-25, -25));
      await tester.pump(const Duration(milliseconds: 16));
      await drag.moveBy(const Offset(-55, -35));
      await tester.pump(const Duration(milliseconds: 16));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(button).dx, lessThan(before.dx - 40));
      expect(find.byKey(const Key('coach-orbit-other')), findsNothing);
      final tap = await tester.startGesture(tester.getCenter(button));
      await tap.moveBy(const Offset(2, 1));
      await tap.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coach-orbit-other')), findsOneWidget);
    },
  );
  testWidgets(
    'quick training stays untimed and orbit preserves visible workout',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController();
      addTearDown(c.dispose);
      await tester.pumpWidget(KiloApp(initialController: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('global-training-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('training-menu-new')));
      await tester.pumpAndSettle();
      expect(c.liveWorkoutVisible, isTrue);
      expect(c.workoutTimerStarted, isFalse);
      c.startWorkout(
        source: [
          for (var i = 0; i < 5; i++)
            c.createBlankWorkoutExercise('bench_press', 'orbit-$i'),
        ],
        autoStartTimer: false,
      );
      c.openLiveWorkout();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workout-coach-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('coach-orbit-more')), findsNothing);
      expect(find.byKey(const Key('workout-coach-input')), findsNothing);
      await tester.drag(
        find.byKey(const Key('coach-exercise-scroll')),
        const Offset(-190, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('coach-orbit-${c.workout[3].id}')).hitTestable(),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const Key('coach-exercise-scroll')),
        const Offset(-190, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coach-orbit-other')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
