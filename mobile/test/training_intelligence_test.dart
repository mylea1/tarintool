import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_intelligence.dart';

const exercise = Exercise(
  id: 'bench_press',
  name: '杠铃卧推',
  englishName: 'Bench press',
  family: '胸部',
  muscle: '胸部',
  secondary: '肱三头、肩部',
  equipment: '杠铃',
  camera: '侧面',
  cue: '稳定完成',
);

WorkoutRecord record({
  required String id,
  required DateTime date,
  required List<int> reps,
  double weight = 80,
  double? rir,
  double? rpe,
  String? gymId,
}) => WorkoutRecord(
  id: id,
  name: 'Push',
  date: date,
  startTime: '18:00',
  durationSeconds: 3600,
  volume: reps.fold(0, (sum, value) => sum + value * weight),
  effectiveSets: reps.length,
  exerciseIds: const ['bench_press'],
  gymId: gymId,
  exercises: [
    WorkoutExercise(
      id: 'workout-$id',
      exerciseId: 'bench_press',
      sets: [
        for (var index = 0; index < reps.length; index++)
          WorkoutSet(
            id: '$id-$index',
            weight: weight,
            reps: reps[index],
            targetMin: 8,
            targetMax: 10,
            completed: true,
            rir: rir,
            rpe: rpe,
          ),
      ],
    ),
  ],
);

void main() {
  const engine = TrainingIntelligenceEngine();

  test('does not mechanically add weight after an incomplete target', () {
    final result = engine.recommendProgression(
      exerciseId: 'bench_press',
      history: [
        record(
          id: 'latest',
          date: DateTime(2026, 9),
          reps: [10, 10, 9],
          rir: 2,
        ),
      ],
      techniques: const [],
      recoveryPercent: 91,
    );
    expect(result.weight, 80);
    expect(result.decision, '保持重量');
  });

  test(
    'adds a small increment only after two complete low-fatigue sessions',
    () {
      final result = engine.recommendProgression(
        exerciseId: 'bench_press',
        history: [
          record(
            id: 'latest',
            date: DateTime(2026, 9),
            reps: [10, 10, 10],
            rir: 2,
          ),
          record(
            id: 'previous',
            date: DateTime(2026, 8, 25),
            reps: [10, 10, 10],
            rir: 3,
          ),
        ],
        techniques: const [],
        recoveryPercent: 91,
      );
      expect(result.weight, 82.5);
      expect(result.decision, '增加重量');
    },
  );

  test('technique stability blocks an otherwise valid load increase', () {
    final result = engine.recommendProgression(
      exerciseId: 'bench_press',
      history: [
        record(
          id: 'latest',
          date: DateTime(2026, 9),
          reps: [10, 10, 10],
          rir: 2,
        ),
        record(
          id: 'previous',
          date: DateTime(2026, 8, 25),
          reps: [10, 10, 10],
          rir: 2,
        ),
      ],
      techniques: [
        TechniqueAssessment(
          id: 'tech-1',
          exerciseId: 'bench_press',
          createdAt: DateTime(2026, 9),
          scoreable: true,
          overall: 78,
          rom: 86,
          stability: 72,
          symmetry: 80,
          tempo: 76,
          trajectory: 83,
        ),
      ],
      recoveryPercent: 91,
    );
    expect(result.weight, 80);
    expect(result.reason, contains('稳定性 72'));
  });

  test('recent hard sets lower recovery and preserve explicit reasoning', () {
    final recovery = engine.calculateRecovery(
      [
        record(
          id: 'today',
          date: DateTime(2026, 9, 1, 8),
          reps: [10, 10, 10, 10],
          rir: 0,
        ),
      ],
      const [exercise],
      now: DateTime(2026, 9, 1, 10),
    );
    final chest = recovery.firstWhere((item) => item.muscle == '胸');
    expect(chest.percent, lessThan(70));
    expect(chest.reason, contains('组数与接近力竭'));
  });

  test('machine histories are isolated by gym', () {
    final result = engine.recommendProgression(
      exerciseId: 'bench_press',
      history: [
        record(
          id: 'gym-b',
          date: DateTime(2026, 9),
          reps: [10, 10, 10],
          weight: 55,
          gymId: 'b',
        ),
        record(
          id: 'gym-a',
          date: DateTime(2026, 8, 25),
          reps: [10, 10, 10],
          weight: 70,
          gymId: 'a',
        ),
      ],
      techniques: const [],
      recoveryPercent: 90,
      gymId: 'b',
      machineExercise: true,
    );
    expect(result.weight, 55);
  });
}
