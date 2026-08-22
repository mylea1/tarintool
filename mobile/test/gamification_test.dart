import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/gamification.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutRecord record({
  required String id,
  required double weight,
  int reps = 8,
  int sets = 1,
  List<String> prs = const [],
  DateTime? date,
}) => WorkoutRecord(
  id: id,
  name: '卧推训练',
  date: date ?? DateTime(2026, 8, 22),
  startTime: '18:00',
  durationSeconds: 1800,
  volume: weight * reps * sets,
  effectiveSets: sets,
  exerciseIds: const ['bench_press'],
  prs: prs,
  exercises: [
    WorkoutExercise(
      id: '$id-exercise',
      exerciseId: 'bench_press',
      sets: [
        for (var index = 0; index < sets; index++)
          WorkoutSet(
            id: '$id-set-$index',
            weight: weight,
            reps: reps,
            completed: true,
          ),
      ],
    ),
  ],
);

const resolver = MuscleContribution(
  primary: MuscleGroup.chest,
  secondary: MuscleGroup.arms,
);

void main() {
  test('strength progress is worth more than adding junk volume', () {
    final baseline = record(id: 'baseline', weight: 75);
    final improved = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record(id: 'improved', weight: 80, prs: const ['卧推']),
      history: [baseline],
      resolveMuscles: (_) => resolver,
    );
    final moreSets = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record(id: 'more-sets', weight: 75, sets: 8),
      history: [baseline],
      resolveMuscles: (_) => resolver,
    );
    expect(improved.settlement.xp, greaterThan(moreSets.settlement.xp));
    expect(
      improved.settlement.performanceScore,
      greaterThan(moreSets.settlement.performanceScore),
    );
  });

  test('settlement is idempotent and splits muscle experience', () {
    final first = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record(id: 'workout-1', weight: 80),
      history: const [],
      resolveMuscles: (_) => resolver,
    );
    final duplicate = GamificationEngine.settle(
      progress: first.progress,
      record: record(id: 'workout-1', weight: 80),
      history: const [],
      resolveMuscles: (_) => resolver,
    );
    expect(
      first.settlement.muscleXp[MuscleGroup.chest],
      greaterThan(first.settlement.muscleXp[MuscleGroup.arms]!),
    );
    expect(duplicate.settlement.duplicate, isTrue);
    expect(duplicate.progress.trainingXp, first.progress.trainingXp);
  });

  test('gamification state persists per account', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = SharedPreferencesGamificationPersistence();
    final state = const PlayerProgress().copyWith(
      trainingXp: 321,
      sparkCoins: 18,
      showAtVenue: true,
      venueCode: 'GYM-01',
      processedWorkoutIds: {'w1'},
    );
    await persistence.write('user-a', state);
    final restored = await persistence.read('user-a');
    final other = await persistence.read('user-b');
    expect(restored.trainingXp, 321);
    expect(restored.venueCode, 'GYM-01');
    expect(restored.processedWorkoutIds, contains('w1'));
    expect(other.trainingXp, 0);
  });

  test('daily quest is stable for the same date', () {
    final first = questForDay(DateTime(2026, 8, 22, 8));
    final later = questForDay(DateTime(2026, 8, 22, 23));
    expect(first.dayKey, later.dayKey);
    expect(first.kind, later.kind);
  });

  test('empty completed workout cannot grant XP or currency', () {
    final record = WorkoutRecord(
      id: 'empty-workout',
      name: '空训练',
      date: DateTime(2026, 8, 22),
      startTime: '18:00',
      durationSeconds: 1800,
      volume: 0,
      effectiveSets: 0,
      exerciseIds: const ['bench_press'],
      exercises: [
        WorkoutExercise(
          id: 'empty-exercise',
          exerciseId: 'bench_press',
          sets: [
            WorkoutSet(
              id: 'empty-set',
              type: 'work',
              weight: 0,
              reps: 0,
              targetMin: 0,
              targetMax: 0,
              restSeconds: 0,
              completed: true,
            ),
          ],
        ),
      ],
    );
    final result = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record,
      history: const [],
      resolveMuscles: (_) =>
          const MuscleContribution(primary: MuscleGroup.chest),
    );

    expect(result.settlement.xp, 0);
    expect(result.settlement.coins, 0);
    expect(result.progress.processedWorkoutIds, contains(record.id));
  });

  test('zero load is valid only for bodyweight exercises', () {
    WorkoutRecord record(String id) => WorkoutRecord(
      id: id,
      name: '零重量记录',
      date: DateTime(2026, 8, 22),
      startTime: '18:00',
      durationSeconds: 600,
      volume: 0,
      effectiveSets: 1,
      exerciseIds: const ['push_up'],
      exercises: [
        WorkoutExercise(
          id: 'exercise-$id',
          exerciseId: 'push_up',
          sets: [
            WorkoutSet(
              id: 'set-$id',
              type: 'work',
              weight: 0,
              reps: 12,
              targetMin: 0,
              targetMax: 0,
              restSeconds: 0,
              completed: true,
            ),
          ],
        ),
      ],
    );

    final loadedMachine = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record('machine'),
      history: const [],
      resolveMuscles: (_) =>
          const MuscleContribution(primary: MuscleGroup.chest),
    );
    final bodyweight = GamificationEngine.settle(
      progress: const PlayerProgress(),
      record: record('bodyweight'),
      history: const [],
      resolveMuscles: (_) => const MuscleContribution(
        primary: MuscleGroup.chest,
        allowsZeroWeight: true,
      ),
    );

    expect(loadedMachine.settlement.xp, 0);
    expect(bodyweight.settlement.xp, greaterThan(0));
  });
}
