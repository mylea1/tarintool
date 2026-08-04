import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';

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
}
