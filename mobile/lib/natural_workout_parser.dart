import 'models.dart';

class ParsedWorkoutNote {
  const ParsedWorkoutNote({
    required this.exercises,
    required this.unmatched,
    this.note = '',
  });
  final List<WorkoutExercise> exercises;
  final List<String> unmatched;
  final String note;
}

class NaturalWorkoutParser {
  static ParsedWorkoutNote parse(String input, List<Exercise> catalog) {
    final exercises = <WorkoutExercise>[];
    final unmatched = <String>[];
    var note = '';
    var index = 0;
    for (final raw in input.split(RegExp(r'[\r\n;；]+'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^(备注|note)\s*[:：]', caseSensitive: false).hasMatch(line)) {
        note = line.replaceFirst(
          RegExp(r'^(备注|note)\s*[:：]\s*', caseSensitive: false),
          '',
        );
        continue;
      }
      String searchableName(Exercise item) =>
          item.name.replaceAll(RegExp(r'[（(].*?[）)]'), '').trim();
      final exercise = catalog
          .where(
            (item) =>
                line.toLowerCase().contains(item.name.toLowerCase()) ||
                (searchableName(item).isNotEmpty &&
                    line.toLowerCase().contains(
                      searchableName(item).toLowerCase(),
                    )) ||
                (item.englishName.trim().isNotEmpty &&
                    line.toLowerCase().contains(
                      item.englishName.toLowerCase(),
                    )),
          )
          .fold<Exercise?>(
            null,
            (best, item) => best == null || item.name.length > best.name.length
                ? item
                : best,
          );
      if (exercise == null) {
        unmatched.add(line);
        continue;
      }
      final weight =
          double.tryParse(
            RegExp(
                  r'(\d+(?:\.\d+)?)\s*(?:kg|公斤)',
                  caseSensitive: false,
                ).firstMatch(line)?.group(1) ??
                '',
          ) ??
          0;
      final rest =
          int.tryParse(
            RegExp(
                  r'(?:休息|rest)\s*(\d+)\s*(?:秒|s)?',
                  caseSensitive: false,
                ).firstMatch(line)?.group(1) ??
                '',
          ) ??
          0;
      final afterWeight = line
          .replaceFirst(
            RegExp(
              '^.*?(?:${RegExp.escape(exercise.name)}|${RegExp.escape(searchableName(exercise))}|${RegExp.escape(exercise.englishName)})',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\d+(?:\.\d+)?\s*(?:kg|公斤)', caseSensitive: false),
            '',
          );
      final repeated = RegExp(r'(\d+)\s*[x×*]\s*(\d+)').firstMatch(afterWeight);
      List<int> reps;
      if (repeated != null) {
        final first = int.parse(repeated.group(1)!);
        final second = int.parse(repeated.group(2)!);
        // Fitness notes commonly use reps x sets; keep the smaller value as sets when ambiguous.
        reps = List.filled(second.clamp(1, 20), first);
      } else {
        reps = RegExp(r'\d+')
            .allMatches(
              afterWeight
                  .split(RegExp(r'(?:休息|rest)', caseSensitive: false))
                  .first,
            )
            .map((m) => int.parse(m.group(0)!))
            .where((v) => v > 0 && v <= 100)
            .toList();
      }
      if (reps.isEmpty) {
        unmatched.add(line);
        continue;
      }
      final id = 'natural-${DateTime.now().microsecondsSinceEpoch}-${index++}';
      exercises.add(
        WorkoutExercise(
          id: id,
          exerciseId: exercise.id,
          restSeconds: rest,
          sets: [
            for (var setIndex = 0; setIndex < reps.length; setIndex++)
              WorkoutSet(
                id: '$id-set-$setIndex',
                weight: weight,
                plannedWeight: null,
                reps: reps[setIndex],
                targetMin: reps[setIndex],
                targetMax: reps[setIndex],
                restSeconds: rest,
              ),
          ],
        ),
      );
    }
    return ParsedWorkoutNote(
      exercises: exercises,
      unmatched: unmatched,
      note: note,
    );
  }
}
