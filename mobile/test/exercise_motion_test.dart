import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/exercise_reorder.dart';
import 'package:kilo_strength/motion_filter_tag.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';

WorkoutExercise item(String id, {String? group}) => WorkoutExercise(
  id: id,
  exerciseId: 'bench_press',
  supersetId: group,
  sets: [WorkoutSet(id: 'set-$id', weight: 42.5, reps: 9, completed: true)],
);

void main() {
  test('reorder retains exact objects, set data and superset units', () {
    final a = item('a', group: 'pair');
    final b = item('b');
    final c = item('c', group: 'pair');
    final items = [a, b, c];
    expect(
      exerciseOrderGroups(
        items,
      ).map((g) => g.map((e) => e.id).toList()).toList(),
      [
        ['a', 'c'],
        ['b'],
      ],
    );
    expect(applyExerciseOrder(items, ['b', 'a', 'c']), isTrue);
    expect(identical(items[1], a), isTrue);
    expect(items[1].sets.single.weight, 42.5);
    expect(items[1].sets.single.completed, isTrue);
    expect(applyExerciseOrder(items, ['a', 'a', 'b']), isFalse);
    expect(items.map((e) => e.id), ['b', 'a', 'c']);
  });
  test('live reordering keeps elapsed time and actual data', () {
    final c = AppController();
    addTearDown(c.dispose);
    c.startWorkout(autoStartTimer: false);
    c.workout.addAll([item('a'), item('b')]);
    c.workoutElapsedSeconds = 90;
    c.reorderWorkoutExercises(['b', 'a']);
    expect(c.workout.map((e) => e.id), ['b', 'a']);
    expect(c.workoutElapsedSeconds, 90);
    expect(c.workoutTimerStarted, isFalse);
    expect(c.workout.last.sets.single.reps, 9);
  });
  test('rapid multi-add assigns distinct stable instance IDs', () {
    final c = AppController();
    addTearDown(c.dispose);
    c.startWorkout(autoStartTimer: false);
    for (final exercise in c.selectableExercises.take(30)) {
      c.addExercise(exercise.id);
    }
    expect(c.workout.length, 30);
    expect(c.workout.map((e) => e.id).toSet().length, 30);
  });
  testWidgets('handle drag moves first to last without losing field state', (
    tester,
  ) async {
    final items = [item('a'), item('b'), item('c')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => ExerciseReorderList(
              items: items,
              onOrder: (ids) => update(() {
                applyExerciseOrder(items, ids);
              }),
              itemBuilder: (item, index, dragIndex) => SizedBox(
                height: 100,
                child: Row(
                  children: [
                    ExerciseDragHandle(
                      key: ValueKey('drag-${item.id}'),
                      index: dragIndex,
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('input-${item.id}'),
                        initialValue: item.id,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('input-a')), '42.5');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('drag-a'))),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 310));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(items.map((e) => e.id), ['b', 'c', 'a']);
    expect(find.text('42.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 375.0, 414.0]) {
    testWidgets('tags reserve layout space at $width and 200 percent text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = '胸部';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in [
                        '胸部',
                        '史密斯器械',
                        'Cable machine long name',
                      ])
                        MotionFilterTag(
                          label: label,
                          selected: selected == label,
                          onTap: () => update(() => selected = label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('史密斯器械'));
      await tester.pump(const Duration(milliseconds: 80));
      final first = tester.getRect(find.byType(MotionFilterTag).at(0));
      final second = tester.getRect(find.byType(MotionFilterTag).at(1));
      expect(first.right <= second.left, isTrue);
      await tester.pumpAndSettle();
      expect(selected, '史密斯器械');
      expect(tester.takeException(), isNull);
    });
  }
}
