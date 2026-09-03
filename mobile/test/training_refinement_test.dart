import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/exercise_growth.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/muscle_palette.dart';

WorkoutSet _set({
  required String id,
  required double weight,
  required int reps,
  String type = 'work',
  bool completed = true,
}) => WorkoutSet(
  id: id,
  type: type,
  weight: weight,
  reps: reps,
  completed: completed,
);

WorkoutRecord _record({
  required String id,
  required DateTime date,
  required String startTime,
  required String exerciseId,
  required List<WorkoutSet> sets,
  String? gymId,
}) => WorkoutRecord(
  id: id,
  name: '测试训练',
  date: date,
  startTime: startTime,
  durationSeconds: 1800,
  volume: 0,
  effectiveSets: sets.length,
  exerciseIds: [exerciseId],
  exercises: [
    WorkoutExercise(id: '$id-exercise', exerciseId: exerciseId, sets: sets),
  ],
  gymId: gymId,
);

const _machine = Exercise(
  id: 'machine_row',
  name: '器械划船',
  englishName: 'machine row',
  family: '划船',
  muscle: '背部',
  secondary: '二头肌',
  equipment: '固定器械',
  camera: '侧面',
  cue: '保持躯干稳定',
);

void main() {
  test('muscle palette distinguishes missing, zero, and multiple bands', () {
    expect(
      MusclePalette.volumeColorFor(const <String, num>{}, '胸部'),
      MusclePalette.missing,
    );
    expect(MusclePalette.volumeColor(0), MusclePalette.missing);
    expect(
      MusclePalette.volumeColorFor(const <String, num>{'胸部': 0}, '胸部'),
      MusclePalette.missing,
    );

    final volumeBandColors = <Color>[
      MusclePalette.volumeColor(0),
      MusclePalette.volumeColor(4),
      MusclePalette.volumeColor(8),
      MusclePalette.volumeColor(12),
      MusclePalette.volumeColor(16),
      MusclePalette.volumeColor(20),
      MusclePalette.volumeColor(30),
    ];
    expect(volumeBandColors.toSet(), hasLength(7));
    expect(
      MusclePalette.volumeColor(2),
      isNot(equals(MusclePalette.volumeColor(7))),
    );

    expect(MusclePalette.recoveryColor(null), MusclePalette.missing);
    expect(MusclePalette.recoveryColor(0), MusclePalette.recoveryRed);
    expect(
      MusclePalette.recoveryColorFor(const <String, num>{'胸部': 0}, '胸部'),
      MusclePalette.recoveryRed,
    );
    expect(
      MusclePalette.recoveryColorFor(const <String, num>{}, '胸部'),
      MusclePalette.missing,
    );
    expect(
      MusclePalette.recoveryColor(40),
      isNot(equals(MusclePalette.recoveryColor(0))),
    );
    expect(
      MusclePalette.recoveryColor(80),
      isNot(equals(MusclePalette.recoveryColor(40))),
    );
  });

  test(
    'growth point keeps weight and reps from the same representative set',
    () {
      final record = _record(
        id: 'paired',
        date: DateTime(2026, 9, 1),
        startTime: '09:00',
        exerciseId: 'bench_press',
        sets: [
          _set(id: 'heavy-set', weight: 100, reps: 3),
          _set(id: 'high-rep-set', weight: 80, reps: 10),
          _set(id: 'warmup-set', weight: 130, reps: 8, type: 'warmup'),
        ],
      );

      final point = buildExerciseGrowthSeries([record], 'bench_press').single;
      expect(point.setId, 'heavy-set');
      expect(point.weight, 100);
      expect(point.reps, 3);
      expect(point.pairLabel, '100 kg × 3 次');
    },
  );

  test('growth history uses startTime to order sessions on the same date', () {
    final day = DateTime(2026, 9, 3);
    final points = buildExerciseGrowthSeries([
      _record(
        id: 'late-a',
        date: day,
        startTime: '21:00',
        exerciseId: 'bench_press',
        sets: [_set(id: 'late-set', weight: 90, reps: 5)],
      ),
      _record(
        id: 'early-z',
        date: day,
        startTime: '07:30',
        exerciseId: 'bench_press',
        sets: [_set(id: 'early-set', weight: 80, reps: 5)],
      ),
    ], 'bench_press');

    expect(points.map((point) => point.recordId), ['early-z', 'late-a']);
    expect(points.first.date.hour, 7);
    expect(points.last.date.hour, 21);
  });

  test('machine growth history keeps different gym locations incomparable', () {
    final points = buildExerciseGrowthSeries(
      [
        _record(
          id: 'gym-a-record',
          date: DateTime(2026, 8, 1),
          startTime: '10:00',
          exerciseId: _machine.id,
          sets: [_set(id: 'gym-a-set', weight: 60, reps: 8)],
          gymId: 'gym-a',
        ),
        _record(
          id: 'gym-b-record',
          date: DateTime(2026, 8, 8),
          startTime: '10:00',
          exerciseId: _machine.id,
          sets: [_set(id: 'gym-b-set', weight: 70, reps: 8)],
          gymId: 'gym-b',
        ),
      ],
      _machine.id,
      definition: _machine,
    );

    expect(points.map((point) => point.historyKey), [
      'machine_row@gym-a',
      'machine_row@gym-b',
    ]);
    expect(hasMixedExerciseGrowthHistory(points), isTrue);
    final comparable = comparableExerciseGrowthSeries(points);
    expect(comparable, hasLength(1));
    expect(comparable.single.recordId, 'gym-b-record');
    expect(comparable.single.gymId, 'gym-b');
  });
}
