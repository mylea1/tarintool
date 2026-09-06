import 'package:flutter/material.dart';
import 'controller.dart';
import 'models.dart';

/// Shared, read-only presentation. Never includes private workout/set notes.
class TrainingExerciseDetails extends StatelessWidget {
  const TrainingExerciseDetails({
    super.key,
    required this.exercises,
    required this.nameFor,
    this.record = false,
  });
  final List<WorkoutExercise> exercises;
  final String Function(String) nameFor;
  final bool record;

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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  exerciseAsset(exercise.exerciseId),
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.fitness_center),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameFor(exercise.exerciseId),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      record
                          ? '${exercise.sets.where((s) => s.completed).length}/${exercise.sets.length} 组完成'
                          : '${exercise.sets.length} 组',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (exercise.sets.isEmpty) const Text('暂无逐组明细'),
                    for (var index = 0; index < exercise.sets.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${index + 1}. ${setLabel(exercise.sets[index])}${exercise.sets[index].type == 'warmup' ? ' · 热身' : ''}${record && !exercise.sets[index].completed ? ' · 未完成' : ''}',
                          style: const TextStyle(fontSize: 13),
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
  });
  factory TrainingDetailsCard.fromRecord({
    Key? key,
    required AppController controller,
    required WorkoutRecord record,
    VoidCallback? onTap,
    bool showExercises = true,
  }) => TrainingDetailsCard(
    key: key,
    title: record.name,
    date: record.date,
    record: true,
    onTap: onTap,
    showExercises: showExercises,
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = theme.brightness == Brightness.dark
        ? 'assets/branding/kilo-orange-metal-logo.png'
        : 'assets/branding/kilo-orange-metal-logo-light.png';
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(logo, width: 38, height: 38),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '形域 · ${record ? '训练记录' : '训练计划'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showExercises) ...[
                const SizedBox(height: 8),
                TrainingExerciseDetails(
                  exercises: exercises,
                  nameFor: nameFor,
                  record: record,
                ),
              ],
              ?footer,
              const Divider(height: 20),
              Text(
                [
                  if (date != null)
                    '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}',
                  if (summary.isNotEmpty) summary,
                ].join(' · '),
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
