part of 'main.dart';

/// Rebuild only the floating controls during a drag, not the live set editor.
class _WorkoutCoachOrbit extends StatefulWidget {
  const _WorkoutCoachOrbit({
    required this.controller,
    required this.bottomInset,
  });
  final AppController controller;
  final double bottomInset;
  @override
  State<_WorkoutCoachOrbit> createState() => _WorkoutCoachOrbitState();
}

class _WorkoutCoachOrbitState extends State<_WorkoutCoachOrbit> {
  Offset? position;
  Offset dragOrigin = Offset.zero;
  bool expanded = false;
  int page = 0;
  bool chatOpen = false;
  String? chatExerciseId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const size = 48.0;
      final maxX = math.max(8.0, box.maxWidth - size - 8);
      final maxY = math.max(
        8.0,
        box.maxHeight - widget.bottomInset - size - 12,
      );
      final p = position ?? Offset(maxX - 8, maxY);
      final anchor = Offset(p.dx.clamp(8.0, maxX), p.dy.clamp(8.0, maxY));
      final exercises = widget.controller.workout;
      final pages = math.max(1, (exercises.length / 2).ceil());
      final current = page.clamp(0, pages - 1);
      final visible = exercises.skip(current * 2).take(2).toList();
      final count = visible.length + 1 + (pages > 1 ? 1 : 0);
      final inward = anchor.dx > box.maxWidth / 2 ? -1.0 : 1.0;
      return Stack(
        children: [
          if (expanded)
            for (var i = 0; i < count; i++)
              Builder(
                builder: (context) {
                  final angle =
                      -math.pi / 2 + math.pi * i / math.max(1, count - 1);
                  final x = (anchor.dx + inward * (66 + 85 * math.cos(angle)))
                      .clamp(4.0, math.max(4.0, box.maxWidth - 68));
                  final centerY = anchor.dy.clamp(
                    105.0,
                    math.max(105.0, maxY - 105),
                  );
                  final y = (centerY + 100 * math.sin(angle)).clamp(
                    4.0,
                    math.max(4.0, maxY - 18),
                  );
                  final exercise = i < visible.length ? visible[i] : null;
                  final isOther = i == visible.length;
                  final label = exercise != null
                      ? widget.controller.displayExerciseName(
                          widget.controller.exerciseFor(exercise.exerciseId),
                        )
                      : isOther
                      ? '其他'
                      : '更多动作';
                  return Positioned(
                    left: x.toDouble(),
                    top: y.toDouble(),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(
                        milliseconds: MediaQuery.of(context).disableAnimations
                            ? 0
                            : 180,
                      ),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: SizedBox(
                        width: 64,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              elevation: 5,
                              shape: const CircleBorder(),
                              color: Theme.of(context).colorScheme.surface,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: Key(
                                  exercise != null
                                      ? 'coach-orbit-${exercise.id}'
                                      : isOther
                                      ? 'coach-orbit-other'
                                      : 'coach-orbit-more',
                                ),
                                onTap: () {
                                  if (exercise == null && !isOther) {
                                    setState(
                                      () => page = (current + 1) % pages,
                                    );
                                    return;
                                  }
                                  setState(() {
                                    expanded = false;
                                    chatOpen = true;
                                    chatExerciseId = exercise?.id;
                                  });
                                },
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: exercise == null
                                      ? Icon(
                                          isOther
                                              ? Icons.chat_bubble_outline
                                              : Icons.more_horiz,
                                        )
                                      : IgnorePointer(
                                          child: _ExerciseThumb(
                                            exerciseId: exercise.exerciseId,
                                            size: 48,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          if (!chatOpen)
            Positioned(
              left: anchor.dx,
              top: anchor.dy,
              child: RepaintBoundary(
                child: GestureDetector(
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (_) => setState(() {
                    expanded = false;
                    dragOrigin = anchor;
                  }),
                  onPanUpdate: (details) => setState(() {
                    final next = (position ?? dragOrigin) + details.delta;
                    position = Offset(
                      next.dx.clamp(8.0, maxX),
                      next.dy.clamp(8.0, maxY),
                    );
                  }),
                  child: FloatingActionButton.small(
                    key: const Key('workout-coach-open'),
                    heroTag: 'workout-coach',
                    shape: const CircleBorder(),
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? '×' : 'AI'),
                  ),
                ),
              ),
            ),
          if (chatOpen)
            Positioned(
              left: (anchor.dx - 310).clamp(
                8.0,
                math.max(8.0, box.maxWidth - 368),
              ),
              top: (anchor.dy - 430).clamp(
                8.0,
                math.max(8.0, box.maxHeight - 438),
              ),
              width: math.min(360.0, box.maxWidth - 16),
              height: math.min(430.0, box.maxHeight - 16),
              child: Material(
                key: const Key('workout-coach-panel'),
                elevation: 12,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: _WorkoutCoachSheet(
                  controller: widget.controller,
                  selectedId: chatExerciseId,
                  onClose: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => chatOpen = false);
                  },
                ),
              ),
            ),
        ],
      );
    },
  );
}

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

Future<void> _openCoachLink(BuildContext context, String? href) async {
  final uri = normalizeTrainingUri(href ?? '');
  if (uri == null || !await launchTrainingUri(uri)) {
    if (context.mounted) showKiloSnack(context, '链接暂时无法打开，请稍后重试');
  }
}

class _WorkoutCoachLesson extends StatelessWidget {
  const _WorkoutCoachLesson({
    required this.controller,
    required this.exerciseId,
    required this.expanded,
    required this.onToggle,
  });
  final AppController controller;
  final String exerciseId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final exercise = controller.exerciseFor(exerciseId);
    final media = mediaForExercise(exerciseId);
    final steps = media?.steps ?? [exercise.cue];
    final saved = normalizeTrainingUri(
      controller.resourceFor(exerciseId, 'library').link,
    );
    final search = douyinTeachingSearchUri(
      controller.displayExerciseName(exercise),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('coach-lesson-toggle'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '动作示范与教学',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(
                height: 132,
                width: double.infinity,
                child: Image.asset(
                  MediaQuery.of(context).disableAnimations
                      ? (media?.imagePath ?? exerciseAsset(exerciseId))
                      : (media?.gifPath ?? exerciseAsset(exerciseId)),
                  key: Key('coach-lesson-gif-$exerciseId'),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Image.asset(
                    media?.imagePath ?? exerciseAsset(exerciseId),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('示范暂不可用')),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (media == null)
            const Text('暂无动态示范', style: TextStyle(fontSize: 12)),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          if (media != null)
            Text(
              media.attribution,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          TextButton.icon(
            key: const Key('coach-teaching-video'),
            onPressed: () => _openCoachLink(context, search.toString()),
            icon: const Icon(Icons.ondemand_video, size: 18),
            label: const Text('在抖音搜索该动作教学'),
          ),
          if (saved != null)
            TextButton(
              onPressed: () => _openCoachLink(context, saved.toString()),
              child: const Text('打开已保存的教学链接'),
            ),
        ],
      ],
    );
  }
}

class _WorkoutCoachSheet extends StatefulWidget {
  const _WorkoutCoachSheet({
    required this.controller,
    required this.onClose,
    this.selectedId,
  });
  final AppController controller;
  final String? selectedId;
  final VoidCallback onClose;
  @override
  State<_WorkoutCoachSheet> createState() => _WorkoutCoachSheetState();
}

class _WorkoutCoachSheetState extends State<_WorkoutCoachSheet> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final selected = <String>{};
  bool busy = false;
  bool lessonExpanded = true;
  int request = 0;
  String? error;
  AiPlanDraft? proposal;
  String? snapshot;
  AiPlanDraft? previous;
  AppController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) selected.add(widget.selectedId!);
  }

  @override
  void dispose() {
    request++;
    input.dispose();
    scroll.dispose();
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
      lessonExpanded = false;
    });
    followAnswer();
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
          if (valid()) {
            setState(() => message.body += delta);
            followAnswer();
          }
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
      followAnswer();
    } catch (e) {
      if (valid()) setState(() => error = _coachError(e));
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  void followAnswer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = c.workout
        .where((e) => selected.contains(e.id))
        .firstOrNull;
    final name = exercise == null
        ? '训练问答'
        : c.displayExerciseName(c.exerciseFor(exercise.exerciseId));
    final prompts = exercise == null
        ? ['组间休息多久？', '今天训练后怎么吃？']
        : ['上一组很吃力，下一组怎么选重量？', '有没有这个动作的教学视频？'];
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
            child: Row(
              children: [
                if (exercise != null)
                  IgnorePointer(
                    child: _ExerciseThumb(
                      exerciseId: exercise.exerciseId,
                      size: 34,
                    ),
                  )
                else
                  const Icon(Icons.auto_awesome_outlined, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        exercise == null ? 'AI 教练 · 其他问题' : 'AI 教练 · 围绕此动作提问',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              children: [
                if (exercise != null) ...[
                  _WorkoutCoachLesson(
                    controller: c,
                    exerciseId: exercise.exerciseId,
                    expanded: lessonExpanded,
                    onToggle: () =>
                        setState(() => lessonExpanded = !lessonExpanded),
                  ),
                  const SizedBox(height: 10),
                ],
                if (c.workoutCoachMessages.isEmpty) ...[
                  Text(
                    exercise == null ? '训练、恢复或饮食，有什么想问的？' : '已选中$name，可以直接提问。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final prompt in prompts)
                        ActionChip(
                          label: Text(
                            prompt,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() => input.text = prompt);
                            input.selection = TextSelection.collapsed(
                              offset: input.text.length,
                            );
                          },
                        ),
                    ],
                  ),
                ],
                for (final m in c.workoutCoachMessages)
                  if (m.body.isNotEmpty)
                    Align(
                      alignment: m.role == 'user'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: m.role == 'user'
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: MarkdownBody(
                          data: m.body,
                          selectable: true,
                          onTapLink: (_, href, _) =>
                              _openCoachLink(context, href),
                        ),
                      ),
                    ),
                if (busy)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('正在回答…', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          request++;
                          setState(() => busy = false);
                        },
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (proposal != null)
                  TextButton.icon(
                    onPressed: () => _openCoachPlanEditor(
                      context,
                      c,
                      plan: proposal,
                      activeSnapshot: snapshot,
                      comparisonPlan: previous,
                    ),
                    icon: const Icon(Icons.compare_arrows, size: 18),
                    label: const Text('查看调整方案'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('workout-coach-input'),
                    controller: input,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: exercise == null ? '输入你的问题…' : '询问这个动作…',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                  ),
                ),
                IconButton.filled(
                  key: const Key('workout-coach-send'),
                  tooltip: '发送',
                  onPressed: busy || input.text.trim().isEmpty ? null : send,
                  icon: const Icon(Icons.arrow_upward, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
