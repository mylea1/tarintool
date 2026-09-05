part of 'main.dart';

String _coachError(Object error) {
  final code = error is CoachApiException ? error.code : '';
  return switch (code) {
    'membership_required' => '重新生成计划需要会员，可继续手动编辑。',
    'quota_exhausted' => '今日 AI 额度已用完，请明天再试或查看会员权益。',
    'coach_http_401' || 'coach_session_expired' => '登录已过期，请重新登录。',
    'coach_plan_missing' => '这次未生成可用计划，请补充要求后重试，原计划已保留。',
    'coach_network' => '网络连接失败，请检查网络后重试。',
    _ =>
      error is TimeoutException ? '等待超时，请重试。原内容已保留。' : '暂时无法完成请求，请重试。原内容已保留。',
  };
}

void _showWorkoutCoach(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _WorkoutCoachSheet(controller: controller),
  );
}

class _WorkoutCoachSheet extends StatefulWidget {
  const _WorkoutCoachSheet({required this.controller});
  final AppController controller;
  @override
  State<_WorkoutCoachSheet> createState() => _WorkoutCoachSheetState();
}

class _WorkoutCoachSheetState extends State<_WorkoutCoachSheet> {
  final input = TextEditingController();
  final selected = <String>{};
  bool busy = false;
  int request = 0;
  String? error;
  AiPlanDraft? proposal;
  String? snapshot;
  AiPlanDraft? previous;
  AppController get c => widget.controller;
  @override
  void dispose() {
    request++;
    input.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || input.text.trim().isEmpty) return;
    final text = input.text.trim();
    final ids = c.workout
        .where((e) => selected.contains(e.id))
        .map((e) => e.exerciseId)
        .toList();
    final labels = ids
        .map((id) => c.displayExerciseName(c.exerciseFor(id)))
        .join('、');
    final generation = c.workoutCoachGeneration;
    final account = c.currentUser?.id;
    final token = ++request;
    final before = c.coachWorkoutFingerprint;
    final originalPlan = c.remainingCoachPlan();
    final message = ChatMessage(
      id: 'coach-${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      body: '',
    );
    c.workoutCoachMessages.add(
      ChatMessage(
        id: 'user-${message.id}',
        role: 'user',
        body: '${labels.isEmpty ? '' : '[$labels]\n'}$text',
      ),
    );
    c.workoutCoachMessages.add(message);
    input.clear();
    setState(() {
      busy = true;
      error = null;
      proposal = null;
      selected.clear();
    });
    bool valid() =>
        mounted &&
        token == request &&
        generation == c.workoutCoachGeneration &&
        account == c.currentUser?.id;
    try {
      final answer = await c.requestWorkoutCoach(
        text,
        selectedIds: ids,
        onDelta: (delta) {
          if (valid()) setState(() => message.body += delta);
        },
      );
      if (!valid()) return;
      setState(() {
        message.body = answer.body;
        message.plan = answer.plan;
        proposal = answer.plan;
        snapshot = before;
        previous = originalPlan;
      });
    } catch (e) {
      if (valid()) setState(() => error = _coachError(e));
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: DraggableScrollableSheet(
      initialChildSize: .65,
      minChildSize: .4,
      maxChildSize: .95,
      expand: false,
      builder: (context, scroll) => AnimatedBuilder(
        animation: c,
        builder: (context, _) => Column(
          children: [
            ListTile(
              dense: true,
              title: const Text('本次训练 AI 教练'),
              subtitle: Text('${c.workoutName} · 已完成 ${c.completedSets} 组'),
              trailing: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  if (c.workoutCoachMessages.isEmpty)
                    const Text('可以问下一组怎么安排，或告诉我想换掉哪个动作。我会结合本次训练和相关历史回答。'),
                  for (final m in c.workoutCoachMessages)
                    if (m.body.isNotEmpty)
                      Card(
                        color: m.role == 'user'
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: MarkdownBody(data: m.body, selectable: true),
                        ),
                      ),
                  if (busy) ...[
                    const LinearProgressIndicator(),
                    TextButton(
                      onPressed: () {
                        request++;
                        setState(() => busy = false);
                      },
                      child: const Text('停止显示回答'),
                    ),
                  ],
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (proposal != null)
                    OutlinedButton.icon(
                      onPressed: () => _openCoachPlanEditor(
                        context,
                        c,
                        plan: proposal,
                        activeSnapshot: snapshot,
                        comparisonPlan: previous,
                      ),
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('查看调整方案 · 已完成组保持不变'),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in c.workout)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selected.contains(e.id),
                        avatar: _ExerciseThumb(
                          exerciseId: e.exerciseId,
                          size: 30,
                        ),
                        label: SizedBox(
                          width: 104,
                          child: Text(
                            '${c.displayExerciseName(c.exerciseFor(e.exerciseId))}\n${e.sets.where((s) => s.completed).length}/${e.sets.length} 组',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onSelected: busy
                            ? null
                            : (value) => setState(() {
                                if (value) {
                                  selected.add(e.id);
                                } else {
                                  selected.remove(e.id);
                                }
                              }),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('workout-coach-input'),
                      controller: input,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '例如：不想练这个动作，换一个',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('workout-coach-send'),
                    tooltip: '发送',
                    onPressed: busy ? null : send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openCoachPlanEditor(
  BuildContext context,
  AppController controller, {
  AiPlanDraft? plan,
  Routine? originalRoutine,
  String? activeSnapshot,
  AiPlanDraft? comparisonPlan,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _CoachPlanEditor(
    controller: controller,
    initial: plan,
    originalRoutine: originalRoutine,
    activeSnapshot: activeSnapshot,
    comparisonPlan: comparisonPlan,
  ),
);

class _CoachPlanEditor extends StatefulWidget {
  const _CoachPlanEditor({
    required this.controller,
    this.initial,
    this.originalRoutine,
    this.activeSnapshot,
    this.comparisonPlan,
  });
  final AppController controller;
  final AiPlanDraft? initial;
  final Routine? originalRoutine;
  final String? activeSnapshot;
  final AiPlanDraft? comparisonPlan;
  @override
  State<_CoachPlanEditor> createState() => _CoachPlanEditorState();
}

class _CoachPlanEditorState extends State<_CoachPlanEditor> {
  final requirements = TextEditingController();
  AiPlanDraft? current;
  AiPlanDraft? old;
  List<Routine> drafts = [];
  bool busy = false;
  String? error;
  int token = 0;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    current = widget.initial;
    old = widget.comparisonPlan;
    if (current != null) drafts = c.editableCoachPlan(current!);
    c.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    token++;
    c.removeListener(changed);
    requirements.dispose();
    super.dispose();
  }

  AiPlanDraft? get edited => current == null
      ? null
      : c.coachPlanFromRoutines(
          current!.title,
          current!.weeks,
          drafts,
          dayOffsets: current!.sessions.map((s) => s.dayOffset).toList(),
        );

  Future<void> regenerate() async {
    if (busy) return;
    final query = current == null
        ? requirements.text
        : await showDialog<String>(
            context: context,
            builder: (_) => _CoachRequirementsDialog(),
          );
    if (query == null || !mounted) return;
    final previous = edited;
    final operation = ++token;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await c.requestWorkoutCoach(
        '${widget.activeSnapshot == null ? '' : '只生成本次剩余训练的单个训练日，已完成组不得包含。'}${query.trim().isEmpty ? '根据我的目标生成训练计划' : query}',
        previousPlan: previous,
        generatePlan: true,
      );
      if (!mounted || operation != token) return;
      setState(() {
        old = previous;
        current = response.plan!;
        drafts = c.editableCoachPlan(current!);
      });
    } catch (e) {
      if (mounted && operation == token) setState(() => error = _coachError(e));
    } finally {
      if (mounted && operation == token) setState(() => busy = false);
    }
  }

  Future<void> save({bool calendar = false}) async {
    final plan = edited;
    if (plan == null ||
        drafts.isEmpty ||
        drafts.any((d) => d.exercises.isEmpty)) {
      setState(() => error = '每个训练日请至少添加一个动作。');
      return;
    }
    if (drafts
        .expand((d) => d.exercises)
        .any(
          (e) =>
              e.sets.isEmpty ||
              !c.selectableExercises.any((x) => x.id == e.exerciseId),
        )) {
      setState(() => error = '请替换不可用动作，并为每个动作添加组数。');
      return;
    }
    DateTime? date;
    if (calendar) {
      final now = DateTime.now();
      date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now,
        lastDate: DateTime(now.year + 2),
      );
      if (date == null || !mounted) return;
    }
    try {
      if (widget.activeSnapshot != null) {
        final previous = c.workout.map((e) => e.copy()).toList();
        c.applyCoachRemainingPlan(plan, widget.activeSnapshot!);
        final applied = c.coachWorkoutFingerprint;
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: const Text('已调整剩余训练'),
              action: SnackBarAction(
                label: '撤销',
                onPressed: () {
                  try {
                    c.restoreCoachWorkout(previous, applied);
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('训练已有新记录，无法撤销此次调整')),
                    );
                  }
                },
              ),
            ),
          );
        }
        return;
      } else if (widget.originalRoutine != null) {
        if (drafts.length != 1) {
          setState(() => error = '替换这份计划时请选择单个训练日。');
          return;
        }
        c.updateRoutineFromDraft(widget.originalRoutine!, drafts.single);
      } else {
        c.saveAiPlan(plan, scheduleCalendar: calendar, scheduleStartDate: date);
      }
      if (mounted) {
        Navigator.pop(context);
        showKiloSnack(context, '计划已保存');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError ? e.message.toString() : _coachError(e),
        );
      }
    }
  }

  String summary(AiPlanDraft p) =>
      '${p.weeks}周 · ${p.sessions.length}天 · ${p.sessions.fold<int>(0, (n, s) => n + s.effectiveExerciseIds.length)}动作 · ${p.sessions.fold<int>(0, (n, s) => n + s.totalSets)}组';
  Widget comparison() => ExpansionTile(
    title: const Text('新旧计划对比'),
    initiallyExpanded: true,
    children: [
      ListTile(title: const Text('原计划'), subtitle: Text(summary(old!))),
      ListTile(title: const Text('新计划'), subtitle: Text(summary(edited!))),
      for (final entry in [('原', old!), ('新', edited!)])
        ExpansionTile(
          title: Text('${entry.$1}计划完整明细'),
          children: [
            for (final s in entry.$2.sessions)
              ListTile(
                title: Text('第${s.dayOffset + 1}天 · ${s.name}'),
                subtitle: Text(
                  s.exercises
                      .map(
                        (e) =>
                            '${c.displayExerciseName(c.exerciseFor(e.exerciseId))}：${e.sets.map((v) => '${v.weight == 0 ? '重量待定' : '${v.weight}kg'}×${v.reps}次/${v.restSeconds}s').join('；')}',
                      )
                      .join('\n'),
                ),
              ),
          ],
        ),
      TextButton(
        onPressed: busy
            ? null
            : () => setState(() {
                current = old;
                old = null;
                drafts = c.editableCoachPlan(current!);
              }),
        child: const Text('保留原计划'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          ListTile(
            title: Text(widget.activeSnapshot != null ? '调整剩余训练' : 'AI 定制训练计划'),
            subtitle: const Text('动作、组数、重量、次数和休息均可手动编辑'),
            trailing: IconButton(
              key: const Key('coach-plan-refresh'),
              tooltip: '重新生成计划',
              onPressed: busy ? null : regenerate,
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (current == null) ...[
                  TextField(
                    key: const Key('ai-workout-details'),
                    controller: requirements,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '目标、时长、可用器械与限制',
                    ),
                  ),
                  FilledButton(
                    key: const Key('ai-workout-generate'),
                    onPressed: busy ? null : regenerate,
                    child: Text(busy ? '正在生成…' : '生成训练计划'),
                  ),
                ],
                if (old != null) comparison(),
                for (final d in drafts)
                  ExpansionTile(
                    title: Text(d.name),
                    initiallyExpanded: true,
                    children: [
                      for (var i = 0; i < d.exercises.length; i++)
                        _RoutineExerciseEditor(
                          controller: c,
                          routine: d,
                          exercise: d.exercises[i],
                          index: i,
                          onChanged: () => setState(() {}),
                        ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => _showExercisePicker(
                                context,
                                c,
                                routine: d,
                                onChanged: () => setState(() {}),
                              ),
                        icon: const Icon(Icons.add),
                        label: const Text('添加动作'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  if (current != null)
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(
                        widget.activeSnapshot != null
                            ? '应用到剩余训练'
                            : old != null
                            ? '使用新计划'
                            : '保存计划',
                      ),
                    ),
                  if (current != null &&
                      widget.activeSnapshot == null &&
                      widget.originalRoutine == null)
                    OutlinedButton(
                      onPressed: busy ? null : () => save(calendar: true),
                      child: const Text('保存并安排日历'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoachRequirementsDialog extends StatefulWidget {
  @override
  State<_CoachRequirementsDialog> createState() =>
      _CoachRequirementsDialogState();
}

class _CoachRequirementsDialogState extends State<_CoachRequirementsDialog> {
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('重新生成计划'),
    content: TextField(
      controller: text,
      autofocus: true,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(hintText: '例如：保留卧推，缩短到45分钟'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, text.text),
        child: const Text('生成并对比'),
      ),
    ],
  );
}
