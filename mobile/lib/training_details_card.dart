import 'package:flutter/material.dart';
import 'controller.dart';
import 'models.dart';
import 'workout_share_card.dart';

/// Shared, read-only presentation. Never includes private workout/set notes.
class TrainingExerciseDetails extends StatelessWidget {
  const TrainingExerciseDetails({
    super.key,
    required this.exercises,
    required this.nameFor,
    this.record = false,
    this.compact = false,
  });
  final List<WorkoutExercise> exercises;
  final String Function(String) nameFor;
  final bool record;
  final bool compact;

  static String number(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  static String setLabel(WorkoutSet set) {
    final weight = set.weightText.trim().isNotEmpty
        ? set.weightText
        : '${number(set.weight)} kg';
    final values = <String>[
      if ((set.durationSeconds ?? 0) > 0)
        '${set.durationSeconds} 秒'
      else
        '$weight × ${set.reps} 次',
      if (set.speedKph != null) '${number(set.speedKph!)} km/h',
      if (set.inclinePercent != null) '坡度 ${number(set.inclinePercent!)}%',
    ];
    return values.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final exercise in exercises)
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  exerciseAsset(exercise.exerciseId),
                  width: compact ? 28 : 48,
                  height: compact ? 28 : 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SizedBox(
                    width: compact ? 28 : 48,
                    height: compact ? 28 : 48,
                    child: Icon(Icons.fitness_center),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameFor(exercise.exerciseId),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                    Text(
                      record
                          ? '${exercise.sets.where((s) => s.completed).length}/${exercise.sets.length} 组完成'
                          : '${exercise.sets.length} 组',
                      style: TextStyle(fontSize: compact ? 10 : 12),
                    ),
                    if (exercise.sets.isEmpty) const Text('暂无逐组明细'),
                    for (var index = 0; index < exercise.sets.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${index + 1}. ${setLabel(exercise.sets[index])}${exercise.sets[index].type == 'warmup' ? ' · 热身' : ''}${record && !exercise.sets[index].completed ? ' · 未完成' : ''}',
                          style: TextStyle(fontSize: compact ? 11 : 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class TrainingDetailsCard extends StatelessWidget {
  const TrainingDetailsCard({
    super.key,
    required this.title,
    required this.exercises,
    required this.nameFor,
    this.date,
    this.summary = '',
    this.record = false,
    this.onTap,
    this.footer,
    this.showExercises = true,
    this.overview,
  });
  factory TrainingDetailsCard.fromRecord({
    Key? key,
    required AppController controller,
    required WorkoutRecord record,
    VoidCallback? onTap,
    bool showExercises = true,
  }) => TrainingDetailsCard(
    key: key,
    title: trainingDisplayName(record.name, record.date),
    date: record.date,
    record: true,
    onTap: onTap,
    showExercises: showExercises,
    overview: Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        for (final metric in [
          ('${TrainingExerciseDetails.number(record.volume)} kg', '总容量'),
          ('${record.effectiveSets}', '完成组'),
          ('${(record.durationSeconds / 60).round()} 分', '时长'),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.$1,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(metric.$2, style: const TextStyle(fontSize: 11)),
            ],
          ),
      ],
    ),
    exercises: record.exercises.isNotEmpty
        ? record.exercises
        : [
            for (final id in record.exerciseIds)
              WorkoutExercise(id: id, exerciseId: id, sets: []),
          ],
    nameFor: (id) => controller.displayExerciseName(controller.exerciseFor(id)),
    summary:
        '${(record.durationSeconds / 60).round()} 分钟 · ${TrainingExerciseDetails.number(record.volume)} kg · ${record.effectiveSets} 有效组',
  );
  final String title;
  final List<WorkoutExercise> exercises;
  final String Function(String) nameFor;
  final DateTime? date;
  final String summary;
  final bool record;
  final bool showExercises;
  final VoidCallback? onTap;
  final Widget? footer;
  final Widget? overview;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.brightness == Brightness.dark
          ? const Color(0xff171719)
          : const Color(0xfffaf4e9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: BrandedTrainingHero(
          title: trainingDisplayName(title, date),
          record: record,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showExercises)
                TrainingExerciseDetails(
                  exercises: exercises,
                  nameFor: nameFor,
                  record: record,
                  compact: true,
                )
              else
                ?overview,
              ?footer,
            ],
          ),
          footer: Text(
            [
              if (date != null)
                '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}',
              if (showExercises && summary.isNotEmpty) summary,
            ].join(' · '),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }
}
