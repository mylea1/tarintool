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

const backExercise = Exercise(
  id: 'barbell_row',
  name: '杠铃划船',
  englishName: 'Barbell row',
  family: '背部',
  muscle: '背部',
  secondary: '肱二头、后束',
  equipment: '杠铃',
  camera: '侧面',
  cue: '保持躯干稳定',
);

const legExercise = Exercise(
  id: 'barbell_squat',
  name: '杠铃深蹲',
  englishName: 'Barbell squat',
  family: '腿部',
  muscle: '股四头',
  secondary: '臀、腘绳肌',
  equipment: '杠铃',
  camera: '侧面',
  cue: '保持膝盖轨迹稳定',
);

WorkoutRecord record({
  required String id,
  required DateTime date,
  required List<int> reps,
  double weight = 80,
  double? rir,
  double? rpe,
  String? gymId,
  String exerciseId = 'bench_press',
  String name = 'Push',
}) => WorkoutRecord(
  id: id,
  name: name,
  date: date,
  startTime: '18:00',
  durationSeconds: 3600,
  volume: reps.fold(0, (sum, value) => sum + value * weight),
  effectiveSets: reps.length,
  exerciseIds: [exerciseId],
  gymId: gymId,
  exercises: [
    WorkoutExercise(
      id: 'workout-$id',
      exerciseId: exerciseId,
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

Routine routine({
  required String id,
  required String name,
  required String exerciseId,
}) => Routine(
  id: id,
  name: name,
  folder: '测试',
  updatedAt: DateTime(2026, 8, 1),
  exercises: [
    WorkoutExercise(
      id: 'plan-$id',
      exerciseId: exerciseId,
      sets: [
        WorkoutSet(
          id: 'plan-set-$id',
          weight: 80,
          reps: 8,
          targetMin: 8,
          targetMax: 10,
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

  test(
    'does not invent a personalised recommendation without completed data',
    () {
      final result = engine.calculate(
        history: const [],
        exercises: const [exercise],
        routines: [
          routine(id: 'push', name: 'Push', exerciseId: 'bench_press'),
        ],
        techniques: const [],
        profile: const TrainingProfile(),
        now: DateTime(2026, 9, 2, 12),
      );

      expect(result.today.hasTrainingData, isFalse);
      expect(result.today.title, '暂无训练数据');
      expect(result.today.muscles, isEmpty);
      expect(result.today.routineId, isNull);
    },
  );

  test(
    'complete onboarding baseline produces the first training suggestion',
    () {
      final result = engine.calculate(
        history: const [],
        exercises: const [exercise],
        routines: [
          routine(id: 'push', name: 'Push', exerciseId: 'bench_press'),
        ],
        techniques: const [],
        profile: const TrainingProfile(
          gender: 'female',
          age: 28,
          goal: 'body_recomp',
          heightCm: 168,
          weightKg: 60,
          weeklyTrainingDays: 3,
          preferredWeekdays: [1, 3, 5],
          sessionMinutes: 60,
          focusMuscles: ['胸'],
        ),
        now: DateTime(2026, 9, 2, 12),
      );

      expect(result.today.hasTrainingData, isTrue);
      expect(result.today.title, 'Push');
      expect(result.today.routineId, 'push');
      expect(result.today.reason, contains('首份建议'));
    },
  );

  test('does not recommend back again when back was trained yesterday', () {
    final now = DateTime(2026, 9, 2, 12);
    final result = engine.calculate(
      history: [
        record(
          id: 'yesterday-pull',
          name: 'Pull',
          exerciseId: 'barbell_row',
          date: DateTime(2026, 9, 1, 20),
          reps: [8, 8, 8],
          rir: 2,
        ),
      ],
      exercises: const [backExercise, legExercise],
      routines: [
        routine(id: 'pull', name: 'Pull', exerciseId: 'barbell_row'),
        routine(id: 'legs', name: 'Legs', exerciseId: 'barbell_squat'),
      ],
      techniques: const [],
      profile: const TrainingProfile(),
      scheduledRoutineName: 'Pull',
      now: now,
    );

    expect(result.today.hasTrainingData, isTrue);
    expect(result.today.routineId, 'legs');
    expect(result.today.title, isNot('Pull'));
    expect(result.today.muscles, isNot(contains('背')));
    expect(result.today.reason, contains('恢复'));
  });
}
