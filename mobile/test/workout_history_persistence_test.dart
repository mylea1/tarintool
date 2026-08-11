import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/workout_history_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'SharedPreferences restores complete records and isolates users',
    () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = SharedPreferencesWorkoutHistoryPersistence();
      final record = WorkoutRecord(
        id: 'history-1',
        name: '上肢训练',
        date: DateTime.utc(2026, 8, 10, 18, 30),
        startTime: '18:30',
        durationSeconds: 3600,
        volume: 4350.5,
        effectiveSets: 1,
        note: '训练备注',
        exerciseIds: const ['bench_press'],
        prs: const ['bench_press'],
        exercises: [
          WorkoutExercise(
            id: 'exercise-1',
            exerciseId: 'bench_press',
            restSeconds: 90,
            note: '肩胛收紧，窄握',
            supersetId: 'superset-1',
            sets: [
              WorkoutSet(
                id: 'set-1',
                type: 'work',
                weight: 72.5,
                plannedWeight: 70,
                reps: 6,
                restSeconds: 90,
                completed: true,
                note: '组备注',
              ),
            ],
          ),
        ],
      );

      await persistence.write('phone:123', [record]);

      final restored = await SharedPreferencesWorkoutHistoryPersistence().read(
        'phone:123',
      );
      expect(restored, hasLength(1));
      expect(restored.single.date, DateTime.utc(2026, 8, 10, 18, 30));
      expect(restored.single.volume, 4350.5);
      expect(restored.single.exercises.single.supersetId, 'superset-1');
      expect(restored.single.exercises.single.note, '肩胛收紧，窄握');
      expect(restored.single.exercises.single.sets.single.plannedWeight, 70);
      expect(restored.single.exercises.single.sets.single.note, '组备注');
      expect(
        await SharedPreferencesWorkoutHistoryPersistence().read('phone:1234'),
        isEmpty,
      );
    },
  );
}
