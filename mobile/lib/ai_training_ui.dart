import 'package:flutter/material.dart';

import 'controller.dart';
import 'membership_ui.dart';
import 'models.dart';
import 'training_intelligence.dart';

class AiTrainingHomeCard extends StatelessWidget {
  const AiTrainingHomeCard({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.trainingIntelligence;
    final today = snapshot.today;
    final active = controller.workoutStarted;
    final routine = controller.routines
        .where((item) => item.id == today.routineId)
        .firstOrNull;
    final scheduled = controller.scheduledLabels[_homeDateKey(DateTime.now())];
    final scheduledRoutine = scheduled == null
        ? null
        : controller.routines
              .where((item) => item.name == scheduled)
              .firstOrNull;
    // A plan stored in the calendar is not training evidence. Until at least
    // one completed set exists, keep the card honest and route the user to a
    // first-session plan flow instead of presenting a pseudo-personalised
    // recommendation.
    final hasTrainingData = today.hasTrainingData;
    final todayRoutine = hasTrainingData ? (routine ?? scheduledRoutine) : null;
    final planned = todayRoutine != null;
    final title = active
        ? (controller.workoutName == '自由训练' ? '本次训练' : controller.workoutName)
        : !hasTrainingData
        ? '暂无训练数据'
        : todayRoutine != null
        ? todayRoutine.name
        : '今天尚未安排训练';
    final count = active
        ? controller.workout.length
        : todayRoutine != null
        ? todayRoutine.exercises.length
        : 0;
    final minutes = active
        ? (controller.currentElapsed ~/ 60).clamp(0, 999)
        : planned
        ? today.estimatedMinutes
        : 0;
    final isMember = controller.entitlements?.isMember == true;
    final colors = Theme.of(context).colorScheme;
    return KeyedSubtree(
      key: const Key('home-overview-section'),
      child: Card(
        key: const Key('ai-training-home-card'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '今日安排',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (active)
                    Text(
                      '训练中',
                      style: TextStyle(color: colors.primary, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                active
                    ? '完成 ${controller.completedSets}/${controller.totalSets} 组 · $count 个动作'
                    : planned
                    ? '$count 个动作 · 约 $minutes 分钟'
                    : '选择计划，或从自由训练开始',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('home-start-today-workout'),
                onPressed: active
                    ? controller.openLiveWorkout
                    : todayRoutine == null
                    ? () => _openPlanEntry(context, controller)
                    : () => controller.startRoutine(todayRoutine),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  active
                      ? '继续今日训练'
                      : planned
                      ? '开始今日训练'
                      : '选择训练计划',
                ),
              ),
              ExpansionTile(
                key: const Key('home-why-training'),
                tilePadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: const Text('查看训练建议', style: TextStyle(fontSize: 12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: isMember
                        ? Text(
                            hasTrainingData
                                ? _conciseMemberReason(today)
                                : '完成第一次训练后，将根据真实记录给出安排建议。',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () => showMembershipPaywall(
                              context,
                              controller: controller,
                              reason: MembershipPaywallReason.premiumFeature,
                            ),
                            icon: const Icon(Icons.lock_outline, size: 16),
                            label: const Text('了解 PRO 训练建议'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _conciseMemberReason(DailyTrainingRecommendation today) {
  final muscles = today.muscles.take(2).join(' + ');
  if (muscles.isEmpty) return '根据近期训练记录和恢复状态安排。';
  return '$muscles 的近期训练分布与恢复状态适合今天安排。';
}

String _homeDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

void _openPlanEntry(BuildContext context, AppController controller) {
  controller.selectPage(PageId.train);
  controller.selectTrainView(TrainView.plans);
  if (controller.routines.isEmpty &&
      controller.entitlements?.isMember != true) {
    showMembershipPaywall(
      context,
      controller: controller,
      reason: MembershipPaywallReason.premiumFeature,
    );
  }
}

class GymLocationsPage extends StatelessWidget {
  const GymLocationsPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _edit(
    BuildContext context, [
    GymLocationProfile? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    var clearedExistingName = false;
    final selectedExerciseIds = <String>{...?existing?.exerciseIds};
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? '添加训练地点' : '编辑训练地点',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      onTap: () {
                        if (existing == null || clearedExistingName) return;
                        clearedExistingName = true;
                        name.clear();
                      },
                      decoration: const InputDecoration(labelText: '地点名称'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '这个健身房的动作',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('gym-pick-exercises'),
                          onPressed: () async {
                            final result = await _pickGymExercises(
                              sheetContext,
                              controller,
                              selectedExerciseIds,
                            );
                            if (result == null) return;
                            setSheetState(() {
                              selectedExerciseIds
                                ..clear()
                                ..addAll(result);
                            });
                          },
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: const Text('选择动作'),
                        ),
                      ],
                    ),
                    Text(
                      selectedExerciseIds.isEmpty
                          ? '尚未添加动作。添加后，训练计划的动作选择器可直接切换到这个健身房。'
                          : '已添加 ${selectedExerciseIds.length} 个动作',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (selectedExerciseIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final id in selectedExerciseIds.take(8))
                            InputChip(
                              label: Text(
                                controller.displayExerciseName(
                                  controller.exerciseFor(id),
                                ),
                              ),
                              onDeleted: () => setSheetState(
                                () => selectedExerciseIds.remove(id),
                              ),
                            ),
                          if (selectedExerciseIds.length > 8)
                            Chip(
                              label: Text(
                                '还有 ${selectedExerciseIds.length - 8} 个',
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('save-gym-location'),
                      onPressed: () async {
                        final locationName = name.text.trim();
                        if (locationName.isEmpty) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('请填写地点名称')),
                          );
                          return;
                        }
                        final values = selectedExerciseIds
                            .map(controller.exerciseFor)
                            .map((exercise) => exercise.equipment.trim())
                            .where((value) => value.isNotEmpty)
                            .toSet()
                            .toList(growable: false);
                        await controller.saveGymLocation(
                          GymLocationProfile(
                            id:
                                existing?.id ??
                                'gym-${DateTime.now().microsecondsSinceEpoch}',
                            name: locationName,
                            equipment: values,
                            exerciseIds: selectedExerciseIds.toList(),
                          ),
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: Text(existing == null ? '保存并设为当前地点' : '保存地点配置'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      // The modal route can still render one final reverse-animation frame
      // after its result completes. Dispose after that frame so its text
      // fields never observe an already-disposed controller.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      name.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('训练地点')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('添加地点'),
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        children: [
          const Text(
            '机器类动作按地点分别理解力量变化；杠铃、哑铃和自重仍跨地点比较。',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          if (controller.gymLocations.isEmpty)
            const _EmptyGym()
          else
            for (final gym in controller.gymLocations)
              Card(
                child: ListTile(
                  onTap: () => controller.selectGym(gym.id),
                  leading: Icon(
                    gym.isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: gym.isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(
                    gym.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${gym.exerciseIds.length} 个动作${gym.equipment.isEmpty ? '' : ' · ${gym.equipment.join(' · ')}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    key: Key('edit-gym-${gym.id}'),
                    tooltip: '编辑地点动作与器械',
                    onPressed: () => _edit(context, gym),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
}

class _EmptyGym extends StatelessWidget {
  const _EmptyGym();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.home_work_outlined, size: 38),
          SizedBox(height: 10),
          Text('还没有训练地点'),
          SizedBox(height: 5),
          Text('添加地点并选择可用动作，之后可直接从该健身房动作库加入训练计划。', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<Set<String>?> _pickGymExercises(
  BuildContext context,
  AppController controller,
  Set<String> initial,
) async {
  final selected = <String>{...initial};
  var query = '';
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final needle = query.trim().toLowerCase();
        final items = controller.selectableExercises
            .where((exercise) {
              if (needle.isEmpty) return true;
              return controller
                      .displayExerciseName(exercise)
                      .toLowerCase()
                      .contains(needle) ||
                  exercise.muscle.toLowerCase().contains(needle);
            })
            .toList(growable: false);
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('gym-exercise-search'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: '搜索动作',
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final exercise = items[index];
                    return CheckboxListTile(
                      key: Key('gym-exercise-${exercise.id}'),
                      value: selected.contains(exercise.id),
                      secondary: _GymExerciseThumb(exercise: exercise),
                      title: Text(controller.displayExerciseName(exercise)),
                      subtitle: Text(exercise.muscle),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(exercise.id);
                        } else {
                          selected.remove(exercise.id);
                        }
                      }),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('gym-exercise-confirm'),
                    onPressed: () => Navigator.pop(context, selected),
                    child: Text('保存 ${selected.length} 个动作'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _GymExerciseThumb extends StatelessWidget {
  const _GymExerciseThumb({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('gym-exercise-thumb-${exercise.id}'),
    width: 46,
    height: 46,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: exercise.id.startsWith('custom-')
        ? Icon(
            Icons.fitness_center_rounded,
            color: Theme.of(context).colorScheme.primary,
          )
        : Image.asset(
            exerciseAsset(exercise.id),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.fitness_center_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
  );
}
