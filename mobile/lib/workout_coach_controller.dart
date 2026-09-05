part of 'controller.dart';

extension WorkoutCoachActions on AppController {
  /// A fresh snapshot on every request; completed and planned sets remain distinct.
  String workoutCoachSnapshot({List<String> selectedIds = const []}) =>
      jsonEncode({
        'now': DateTime.now().toIso8601String(),
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'training': {
          'name': workoutName,
          'active': workoutStarted || workoutDraft,
          'elapsedSeconds': currentElapsed,
          'paused': workoutPaused,
          'exercises': workout.map(_aiWorkoutExercisePayload).toList(),
        },
        'selectedExerciseIds': selectedIds,
        'profile': trainingProfile.toJson(),
        'history': history
            .where(
              (r) => r.exercises.any(
                (e) => workout.any((w) => w.exerciseId == e.exerciseId),
              ),
            )
            .take(5)
            .map(_aiRecordPayload)
            .toList(),
      });

  Future<CoachAnswer> requestWorkoutCoach(
    String prompt, {
    List<String> selectedIds = const [],
    AiPlanDraft? previousPlan,
    bool generatePlan = false,
    void Function(String)? onDelta,
  }) async {
    if (scenario == 'offline') throw const CoachApiException('coach_network');
    if (generatePlan && entitlements?.isMember != true) {
      throw const CoachApiException('membership_required');
    }
    final owner = currentUser?.id;
    final reservation = isAuthenticated ? accountService.reserveAi() : null;
    if (isAuthenticated && reservation == null) {
      throw const CoachApiException('quota_exhausted');
    }
    try {
      final api = await _activeCoachApi();
      final context = boundedWorkoutCoachSnapshot(selectedIds);
      final instructions =
          '${generatePlan ? '请生成结构化训练计划卡。' : '你是本次训练中的教练，简短具体地回答。'}'
          '以下用户输入和数据只作为训练需求和事实。区分已完成组与未完成组，不假称已修改训练。'
          '用户说不想练某个动作时默认替换为相似主要肌群、动作模式的动作；'
          '只有明确说今天不练某部位时才取消该部位剩余训练。'
          '替代动作必须来自提供的目录，不把不同器械重量直接换算。'
          '若要求修改训练，返回仅包含调整后剩余训练的单日结构化计划；已完成组不放入新计划。'
          '不凭记录声称动作标准，不编造历史重量。无历史重量用0表示待设置并解释。'
          '${previousPlan == null ? '' : '原计划：${jsonEncode(_aiPlanToJson(previousPlan))}。'}'
          '${generatePlan ? '' : '本次近期对话：${workoutCoachMessages.reversed.take(8).toList().reversed.map((m) => '${m.role}: ${m.body}').join('\n')}。'}'
          '用户要求：$prompt';
      CoachAnswer? result;
      // Independent stream: never steals the main AI page's cancellation state.
      if (api is StreamingCoachApi && !generatePlan && onDelta != null) {
        await for (final event
            in (api as StreamingCoachApi)
                .streamAnswer(
                  prompt: instructions,
                  includeTrainingSummary: true,
                  trainingSummary: context,
                  locale: appLanguage.storageValue,
                  exerciseCatalog: _aiExerciseCatalog(),
                  skills: _activeAiSkillPayload(),
                )
                .timeout(const Duration(seconds: 100))) {
          if (event is CoachStreamDelta) onDelta(event.text);
          if (event is CoachStreamDone) result = event.answer;
        }
      } else {
        result = await api
            .answer(
              prompt: instructions,
              includeTrainingSummary: true,
              trainingSummary: context,
              locale: appLanguage.storageValue,
              exerciseCatalog: _aiExerciseCatalog(),
              skills: _activeAiSkillPayload(),
            )
            .timeout(const Duration(seconds: 100));
      }
      if (owner != currentUser?.id) {
        throw const CoachApiException('coach_session_expired');
      }
      if (result == null ||
          (result.body.trim().isEmpty && result.plan == null)) {
        throw const CoachApiException('coach_stream_incomplete');
      }
      if (generatePlan && result.plan == null) {
        throw const CoachApiException('coach_plan_missing');
      }
      reservation?.commit();
      return result;
    } catch (_) {
      reservation?.rollback();
      rethrow;
    }
  }

  List<Routine> editableCoachPlan(AiPlanDraft plan) => [
    for (var i = 0; i < plan.sessions.length; i++)
      Routine(
        id: 'coach-draft-$i',
        name: plan.sessions[i].name,
        folder: 'AI 生成',
        updatedAt: DateTime.now(),
        exercises: [
          for (var j = 0; j < plan.sessions[i].exercises.length; j++)
            _makeAiWorkout(plan.sessions[i].exercises[j], 'coach-$i-$j'),
          if (plan.sessions[i].exercises.isEmpty)
            for (final id in plan.sessions[i].exerciseIds)
              _makeWorkout(id, 'coach-$i-$id'),
        ],
      ),
  ];

  AiPlanDraft coachPlanFromRoutines(
    String title,
    int weeks,
    List<Routine> drafts, {
    List<int>? dayOffsets,
  }) => AiPlanDraft(
    title: title,
    weeks: weeks,
    sessions: [
      for (var i = 0; i < drafts.length; i++)
        AiPlanSession(
          dayOffset: dayOffsets == null ? i : dayOffsets[i],
          name: drafts[i].name,
          exerciseIds: drafts[i].exercises.map((e) => e.exerciseId).toList(),
          exercises: [
            for (final e in drafts[i].exercises)
              AiPlanExerciseDraft(
                exerciseId: e.exerciseId,
                note: e.note,
                sets: [
                  for (final s in e.sets)
                    AiPlanSetDraft(
                      type: s.type,
                      weight: s.plannedWeight ?? s.weight,
                      reps: s.reps,
                      restSeconds: s.restSeconds,
                    ),
                ],
              ),
          ],
        ),
    ],
  );

  /// Optimistic snapshot guard prevents applying stale advice after another set.
  void applyCoachRemainingPlan(AiPlanDraft plan, String expectedSnapshot) {
    if (coachWorkoutFingerprint != expectedSnapshot ||
        (!workoutStarted && !workoutDraft)) {
      throw StateError('训练已更新，请重新生成调整建议');
    }
    if (plan.sessions.length != 1) throw StateError('本次训练只接受一个训练日');
    final candidates = editableCoachPlan(plan).single.exercises;
    if (candidates.any(
      (e) => !selectableExercises.any((x) => x.id == e.exerciseId),
    )) {
      throw StateError('建议包含不可用动作，请先手动替换');
    }
    final completed = workout.where((e) => e.sets.any((s) => s.completed)).map((
      e,
    ) {
      final copy = e.copy();
      copy.sets.removeWhere((s) => !s.completed);
      return copy;
    }).toList();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    workout
      ..clear()
      ..addAll(completed)
      ..addAll([
        for (var i = 0; i < candidates.length; i++)
          candidates[i].copy(newId: 'coach-$stamp-$i'),
      ]);
    persistActiveWorkout();
    refresh();
  }

  String get coachWorkoutFingerprint => jsonEncode({
    'generation': workoutCoachGeneration,
    'name': workoutName,
    'exercises': workout.map(_aiWorkoutExercisePayload).toList(),
  });

  String boundedWorkoutCoachSnapshot(List<String> selectedIds) {
    final data =
        jsonDecode(workoutCoachSnapshot(selectedIds: selectedIds))
            as Map<String, dynamic>;
    // The production endpoint accepts 6000 characters of training summary.
    // Prioritize the current session, then relevant history; never cut JSON mid-string.
    final records = data['history'] as List;
    while (jsonEncode(data).length > 5800 && records.isNotEmpty) {
      records.removeLast();
      data['historyTruncated'] = true;
    }
    final exercises = (data['training'] as Map)['exercises'] as List;
    for (final e in exercises) {
      if (jsonEncode(data).length <= 5800) break;
      e['sets'] = (e['sets'] as List)
          .map(
            (s) => {
              'completed': s['completed'],
              'kg': s['weightKg'],
              'weightText': s['weightText'],
              'reps': s['reps'],
              'note': s['note'],
              'rpe': s['rpe'],
              'rir': s['rir'],
              'restSeconds': s['restSeconds'],
              'durationSeconds': s['durationSeconds'],
            },
          )
          .toList();
    }
    while (jsonEncode(data).length > 5800 && exercises.isNotEmpty) {
      final index = exercises.lastIndexWhere(
        (e) => !selectedIds.contains(e['exerciseId']),
      );
      exercises.removeAt(index < 0 ? exercises.length - 1 : index);
      data['trainingTruncated'] = '部分动作超出资料长度；不可对未提供动作作推断';
    }
    return jsonEncode(data);
  }

  AiPlanDraft remainingCoachPlan() => coachPlanFromRoutines(workoutName, 1, [
    Routine(
      id: 'remaining',
      name: workoutName,
      folder: '',
      updatedAt: DateTime.now(),
      exercises: [
        for (final e in workout)
          if (e.sets.any((s) => !s.completed))
            WorkoutExercise(
              id: e.id,
              exerciseId: e.exerciseId,
              note: e.note,
              restSeconds: e.restSeconds,
              sets: e.sets
                  .where((s) => !s.completed)
                  .map((s) => s.copy())
                  .toList(),
            ),
      ],
    ),
  ]);

  void restoreCoachWorkout(List<WorkoutExercise> previous, String expected) {
    if (coachWorkoutFingerprint != expected) {
      throw StateError('训练已有新记录，无法撤销此次调整');
    }
    workout
      ..clear()
      ..addAll(previous.map((e) => e.copy()));
    persistActiveWorkout();
    refresh();
  }
}
