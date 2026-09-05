import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';

void main() {
  test(
    'public identity is ten digits and survives profile edits and reload',
    () {
      final storage = InMemoryAccountPersistence();
      final service = AccountService(persistence: storage);
      service.loginWithPhone('13800138099');
      final id = service.currentUser!.publicId;
      expect(id, matches(RegExp(r'^[1-9]\d{9}$')));
      service.updateCurrentProfile(displayName: '训练者');
      final restored = AccountService(persistence: storage);
      expect(restored.currentUser!.publicId, id);
      expect(restored.currentUser!.identifier, '13800138099');
      expect(safeAccountName('apple:000349.8a9359abcdef'), '形域用户');
      service.dispose();
      restored.dispose();
    },
  );

  test(
    'reused historical notes stay in history and new notes remain editable',
    () {
      final c = AppController();
      addTearDown(c.dispose);
      final previous = WorkoutExercise(
        id: 'old',
        exerciseId: 'bench_press',
        note: '上次动作备注',
        sets: [
          WorkoutSet(
            id: 's',
            weight: 50,
            reps: 10,
            completed: true,
            note: '上次组备注',
          ),
        ],
      );
      c.history.add(
        WorkoutRecord(
          id: 'record',
          name: '上肢',
          date: DateTime(2026, 9, 1),
          startTime: '12:00',
          durationSeconds: 60,
          volume: 500,
          effectiveSets: 1,
          exerciseIds: const ['bench_press'],
          exercises: [previous],
        ),
      );
      c.startWorkout(source: [previous], autoStartTimer: false);
      expect(c.workout.single.note, isEmpty);
      expect(c.workout.single.sets.single.note, isEmpty);
      expect(previous.note, '上次动作备注');
      expect(c.previousExactSetFor('bench_press', 0)!.note, '上次组备注');
      c.workout.single.note = '本次新备注';
      expect(previous.note, '上次动作备注');
    },
  );

  testWidgets('records is independent and AI moves only after a long press', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController();
    addTearDown(c.dispose);
    c.startWorkout(autoStartTimer: false);
    c.openLiveWorkout();
    await tester.pumpWidget(KiloApp(initialController: c));
    await tester.pumpAndSettle();
    final coach = find.byKey(const Key('workout-coach-open'));
    final origin = tester.getCenter(coach);
    final gesture = await tester.startGesture(origin);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-100, -100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(coach).dx, lessThan(origin.dx - 50));
    expect(tester.getCenter(coach).dy, lessThan(origin.dy - 50));
    c.selectPage(PageId.records);
    await tester.pumpAndSettle();
    expect(find.byType(RecordsPage), findsOneWidget);
    expect(coach, findsNothing);
    c.selectPage(PageId.today);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-friends-entry')), findsOneWidget);
    expect(find.byKey(const Key('global-training-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
