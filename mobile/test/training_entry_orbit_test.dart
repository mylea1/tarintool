import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
      expect(find.byKey(const Key('coach-orbit-other')), findsOneWidget);
      expect(find.byKey(const Key('coach-orbit-more')), findsOneWidget);
      expect(find.byKey(const Key('workout-coach-input')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('coach-orbit-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('coach-orbit-${c.workout[2].id}')), findsOneWidget);
    },
  );
}
