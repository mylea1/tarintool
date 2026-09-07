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
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < exercise.sets.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.only(top: 3, right: 12),
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
          ),
        ),
    ],
  );
}

/// Bounded preview: exact per-exercise counts, no weights or durations.
class TrainingExerciseSummary extends StatelessWidget {
  const TrainingExerciseSummary({
    super.key,
    required this.exercises,
    required this.nameFor,
    this.setCounts = const {},
  });
  final List<WorkoutExercise> exercises;
  final String Function(String) nameFor;
  final Map<String, int> setCounts;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in exercises.take(3))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Image.asset(
                exerciseAsset(e.exerciseId),
                width: 26,
                height: 26,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.fitness_center, size: 26),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nameFor(e.exerciseId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${setCounts[e.exerciseId] ?? e.sets.length} 组',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      if (exercises.length > 3)
        Text(
          '另 ${exercises.length - 3} 个动作 · 点击查看',
          style: const TextStyle(fontSize: 11),
        ),
    ],
  );
}

/// Height follows content; hidden children retain state without focus or semantics.
class TrainingDisclosure extends StatelessWidget {
  const TrainingDisclosure({
    super.key,
    required this.expanded,
    required this.child,
  });
  final bool expanded;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final content = ExcludeFocus(
      excluding: !expanded,
      child: Offstage(offstage: !expanded, child: child),
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

class TrainingExerciseAccordion extends StatelessWidget {
  const TrainingExerciseAccordion({
    super.key,
    required this.exercises,
    required this.nameFor,
    this.record = false,
    this.allowPrivateNotes = false,
    this.setCounts = const {},
  });
  final List<WorkoutExercise> exercises;
  final String Function(String) nameFor;
  final bool record;
  final bool allowPrivateNotes;
  final Map<String, int> setCounts;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final e in exercises)
        _ExerciseDisclosureRow(
          key: ValueKey(e.id),
          exercise: e,
          name: nameFor(e.exerciseId),
          record: record,
          allowPrivateNotes: allowPrivateNotes,
          count: setCounts[e.exerciseId] ?? e.sets.length,
        ),
    ],
  );
}

class _ExerciseDisclosureRow extends StatefulWidget {
  const _ExerciseDisclosureRow({
    super.key,
    required this.exercise,
    required this.name,
    required this.record,
    required this.allowPrivateNotes,
    required this.count,
  });
  final WorkoutExercise exercise;
  final String name;
  final bool record;
  final bool allowPrivateNotes;
  final int count;
  @override
  State<_ExerciseDisclosureRow> createState() => _ExerciseDisclosureRowState();
}

class _ExerciseDisclosureRowState extends State<_ExerciseDisclosureRow> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          button: true,
          child: InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Image.asset(
                    exerciseAsset(e.exerciseId),
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.fitness_center, size: 32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${widget.count} 组'),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
        ),
        TrainingDisclosure(
          expanded: expanded,
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.allowPrivateNotes && e.note.trim().isNotEmpty)
                  Text('动作备注：${e.note}'),
                if (e.sets.isEmpty) const Text('暂无逐组明细'),
                for (var i = 0; i < e.sets.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${TrainingExerciseDetails.setLabel(e.sets[i])}${e.sets[i].type == 'warmup' ? ' · 热身' : ''}${widget.record && !e.sets[i].completed ? ' · 未完成' : ''}',
                        ),
                        Text(
                          '休息 ${!widget.record && e.sets[i].restSeconds == 0 ? e.restSeconds : e.sets[i].restSeconds} 秒',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.allowPrivateNotes &&
                            e.sets[i].note.trim().isNotEmpty)
                          Text('备注：${e.sets[i].note}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class TrainingDetailsCard extends StatelessWidget {
  const TrainingDetailsCard({
    super.key,
    required this.title,
    required this.exercises,
    required this.nameFor,
    this.date,
    this.startTime,
    this.summary = '',
    this.record = false,
    this.onTap,
    this.footer,
    this.showExercises = true,
    this.overview,
    this.branded = false,
    this.plainExpandable = false,
    this.setCounts = const {},
    this.durationSeconds,
    this.volume,
    this.effectiveSets,
  });
  factory TrainingDetailsCard.fromRecord({
    Key? key,
    required AppController controller,
    required WorkoutRecord record,
    VoidCallback? onTap,
    bool showExercises = true,
    bool branded = false,
    bool plainExpandable = false,
  }) => TrainingDetailsCard(
    key: key,
    branded: branded,
    plainExpandable: plainExpandable,
    durationSeconds: record.durationSeconds,
    volume: record.volume,
    effectiveSets: record.effectiveSets,
    title: trainingDisplayName(record.name, record.date),
    date: record.date,
    startTime: record.startTime,
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
  final String? startTime;
  final String summary;
  final bool record;
  final bool showExercises;
  final bool branded;
  final bool plainExpandable;
  final int? durationSeconds;
  final double? volume;
  final int? effectiveSets;
  int get totalSets =>
      effectiveSets ??
      exercises.fold(
        0,
        (n, e) =>
            n +
            (setCounts[e.exerciseId] ??
                (record
                    ? e.sets.where((s) => s.completed).length
                    : e.sets.length)),
      );
  double get totalVolume =>
      volume ??
      exercises
          .expand((e) => e.sets)
          .where((s) => !record || s.completed)
          .fold(0.0, (n, s) => n + s.weight * s.reps);
  final Map<String, int> setCounts;
  final VoidCallback? onTap;
  final Widget? footer;
  final Widget? overview;
  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trainingDisplayName(title, date),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (date != null)
                        Text(
                          '${date!.year}-${date!.month}-${date!.day} · ${startTime ?? '${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}'}',
                        ),
                      if (!plainExpandable) _metalCard(),
                      const SizedBox(height: 16),
                      if (summary.isNotEmpty) Text(summary),
                      if (plainExpandable)
                        TrainingExerciseAccordion(
                          exercises: exercises,
                          nameFor: nameFor,
                          record: record,
                          setCounts: setCounts,
                        )
                      else
                        TrainingExerciseDetails(
                          exercises: footer == null
                              ? exercises
                              : exercises
                                    .where((e) => e.sets.isNotEmpty)
                                    .toList(),
                          nameFor: nameFor,
                          record: record,
                        ),
                      ?footer,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metalCard() => WorkoutShareCard(
    workoutName: trainingDisplayName(title, date),
    date: date ?? DateTime.now(),
    durationSeconds: durationSeconds ?? 0,
    volume: totalVolume,
    effectiveSets: totalSets,
    localized: true,
    isPlan: durationSeconds == null,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (plainExpandable) {
      return Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap ?? () => _openDetails(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trainingDisplayName(title, date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            TrainingExerciseAccordion(
              exercises: exercises,
              nameFor: nameFor,
              record: record,
              setCounts: setCounts,
            ),
          ],
        ),
      );
    }
    final names = exercises
        .take(4)
        .map((e) => nameFor(e.exerciseId))
        .join(' · ');
    final content = branded
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metalCard(),
              if (showExercises && names.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    names,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          )
        : Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trainingDisplayName(title, date),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                if (date != null)
                  Text(
                    '${date!.month}月${date!.day}日 · ${startTime ?? '${date!.hour.toString().padLeft(2, '0')}:${date!.minute.toString().padLeft(2, '0')}'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    for (final metric in [
                      (
                        durationSeconds == null
                            ? '—'
                            : '${(durationSeconds! / 60).round()} 分钟',
                        '时长',
                      ),
                      (
                        '${TrainingExerciseDetails.number(totalVolume)} kg',
                        '总容量',
                      ),
                      ('$totalSets 组', '完成组'),
                    ])
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.$1,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(metric.$2, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                  ],
                ),
                if (showExercises && names.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    names,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          );
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: showExercises ? (onTap ?? () => _openDetails(context)) : onTap,
        child: content,
      ),
    );
  }
}
