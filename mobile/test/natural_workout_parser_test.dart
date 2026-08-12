import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/natural_workout_parser.dart';

void main() {
  test('converts natural Chinese notes into editable sets', () {
    final parsed = NaturalWorkoutParser.parse(
      '杠铃卧推 80kg 8,8,7 休息120秒\n高位下拉 50kg 10×3\n备注：最后一组接近力竭',
      catalog,
    );

    expect(
      parsed.exercises,
      hasLength(2),
      reason: 'unmatched=${parsed.unmatched}',
    );
    expect(parsed.exercises.first.sets.map((set) => set.reps), [8, 8, 7]);
    expect(parsed.exercises.first.sets.first.weight, 80);
    expect(parsed.exercises.first.restSeconds, 120);
    expect(parsed.exercises.last.sets, hasLength(3));
    expect(parsed.exercises.last.sets.every((set) => set.reps == 10), isTrue);
    expect(parsed.note, '最后一组接近力竭');
    expect(parsed.unmatched, isEmpty);
  });

  test(
    'keeps unrecognised lines visible instead of silently dropping them',
    () {
      final parsed = NaturalWorkoutParser.parse('神秘动作 40kg 10×3', catalog);

      expect(parsed.exercises, isEmpty);
      expect(parsed.unmatched, ['神秘动作 40kg 10×3']);
    },
  );
}
