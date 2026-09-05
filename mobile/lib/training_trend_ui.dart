part of 'main.dart';

void _showProgress(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: _ProgressAnalysisSheet(controller: controller),
    ),
  );
}

class _ProgressAnalysisSheet extends StatefulWidget {
  const _ProgressAnalysisSheet({required this.controller});
  final AppController controller;
  @override
  State<_ProgressAnalysisSheet> createState() => _ProgressAnalysisSheetState();
}

class _ProgressAnalysisSheetState extends State<_ProgressAnalysisSheet> {
  int days = 30;
  DateTimeRange? custom;

  Future<void> _chooseRange() async {
    final now = DateTime.now();
    final dates = widget.controller.history.map((r) => r.date).toList()..sort();
    final first = dates.isEmpty || dates.first.isAfter(now)
        ? DateTime(now.year, 1, 1)
        : dates.first;
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateUtils.dateOnly(first),
      lastDate: DateUtils.dateOnly(now),
    );
    if (mounted && value != null) setState(() => custom = value);
  }

  void _openWeek(WeeklyTrainingVolume week) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final records =
                widget.controller.history
                    .where(
                      (r) =>
                          !trendDay(r.date).isBefore(week.start) &&
                          !trendDay(r.date).isAfter(week.end),
                    )
                    .toList()
                  ..sort(
                    (a, b) =>
                        growthRecordDate(b).compareTo(growthRecordDate(a)),
                  );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${trendDate(week.start)}—${trendDate(week.end)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty) const Text('这段时间没有训练记录'),
                for (final record in records)
                  ListTile(
                    key: Key('weekly-record-${record.id}'),
                    leading: record.exerciseIds.isEmpty
                        ? const Icon(Icons.fitness_center)
                        : _ExerciseThumb(
                            exerciseId: record.exerciseIds.first,
                            size: 42,
                          ),
                    title: Text(record.name),
                    subtitle: Text(
                      '${trendDate(record.date)} · ${record.startTime}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _showRecordDetail(context, widget.controller, record),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final now = DateTime.now();
      final end = custom?.end ?? trendDay(now);
      final start =
          custom?.start ?? DateTime(end.year, end.month, end.day - days + 1);
      final weeks = weeklyTrainingVolumes(
        widget.controller.history,
        start,
        end,
        now: now,
      );
      final records = weeks.expand((w) => w.records).toList();
      final missing = weeks.fold(0, (sum, w) => sum + w.missingDetails);
      final total = weeks.fold(0.0, (sum, w) => sum + w.volume);
      final planned = records
          .expand((r) => r.exercises)
          .expand((e) => e.sets)
          .where(
            (s) =>
                s.completed &&
                s.plannedWeight != null &&
                s.plannedWeight!.isFinite &&
                s.weight.isFinite,
          )
          .toList();
      final achieved = planned
          .where((s) => s.weight >= s.plannedWeight!)
          .length;
      final averageDelta = planned.isEmpty
          ? null
          : planned.fold(0.0, (sum, s) => sum + s.weight - s.plannedWeight!) /
                planned.length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Text('训练进步', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('按周回看训练投入，点选查看对应记录。', style: TextStyle(color: quiet)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in [30, 90, 365])
                ChoiceChip(
                  label: Text(value == 365 ? '近一年' : '近 $value 天'),
                  selected: custom == null && days == value,
                  onSelected: (_) => setState(() {
                    days = value;
                    custom = null;
                  }),
                ),
              ActionChip(
                label: Text(custom == null ? '自定义' : '自定义 ✓'),
                onPressed: _chooseRange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '每周训练量',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${records.length} 次训练 · ${trendNumber(total)} kg·次${missing > 0 ? '（已知组明细）' : ''}',
            style: TextStyle(color: quiet),
          ),
          if (missing > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$missing 条旧记录没有组明细，未将其汇总值混入本图。可在对应周查看原记录。',
                style: TextStyle(color: quiet, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('所选时间段暂无训练记录'),
            )
          else
            TrendChart(
              key: const Key('progress-trend-chart'),
              bars: true,
              unit: '工作组训练量 · kg·次',
              start: start,
              end: end,
              minimumSpan: 100,
              data: [
                for (final w in weeks)
                  TrendDatum(
                    id: w.weekStart.toIso8601String(),
                    date: w.weekStart,
                    value:
                        w.records.isNotEmpty &&
                            w.missingDetails == w.records.length
                        ? null
                        : w.volume,
                    description:
                        '${trendDate(w.start)}—${trendDate(w.end)} · ${w.records.length} 次训练 · '
                        '${w.missingDetails > 0 ? '部分明细缺失 · ' : ''}${trendNumber(w.volume)} kg·次',
                  ),
              ],
              detailBuilder: (context, datum) {
                final week = weeks.firstWhere(
                  (w) => w.weekStart.toIso8601String() == datum.id,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trendDate(week.start)}—${trendDate(week.end)}',
                      style: TextStyle(color: quiet),
                    ),
                    Text(
                      datum.value == null
                          ? '缺少组明细'
                          : '${trendNumber(week.volume)} kg·次',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${week.records.length} 次训练'
                      '${week.current ? ' · 截至 ${trendDate(week.end)}' : ''}'
                      '${week.partial ? ' · 非完整周' : ''}'
                      '${week.missingDetails > 0 ? ' · ${week.missingDetails} 条缺少组明细' : ''}',
                      key: const Key('weekly-selection-summary'),
                      style: TextStyle(color: quiet),
                    ),
                    TextButton(
                      key: const Key('weekly-open-records'),
                      onPressed: () => _openWeek(week),
                      child: const Text('查看本周训练'),
                    ),
                  ],
                );
              },
            ),
          if (planned.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('计划重量完成情况', style: TextStyle(fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '已完成组中，${(achieved / planned.length * 100).toStringAsFixed(0)}% 达到计划重量',
                      ),
                      Text(
                        '平均重量差 ${averageDelta! >= 0 ? '+' : ''}${trendNumber(averageDelta)} kg',
                      ),
                      Text(
                        '仅统计所选期间有计划重量的 ${planned.length} 个已完成组。',
                        style: TextStyle(color: quiet, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('训练量如何计算？', style: TextStyle(fontSize: 13)),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '按周一至周日累计所选范围内已完成负重工作组的重量 × 次数。热身、技术组和未完成组不纳入。空白周表示没有训练记录；缺少明细不按零处理。训练量反映训练投入，不直接表示力量进步或退步。',
                  style: TextStyle(color: quiet, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _TrackedStrengthSection extends StatefulWidget {
  const _TrackedStrengthSection({
    required this.controller,
    required this.range,
  });
  final AppController controller;
  final DateTimeRange range;
  @override
  State<_TrackedStrengthSection> createState() =>
      _TrackedStrengthSectionState();
}

class _TrackedStrengthSectionState extends State<_TrackedStrengthSection> {
  String? selectedExerciseId;
  AppController get controller => widget.controller;
  Future<void> _manage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _StrengthTrackingPage(controller: controller),
    ),
  );

  Future<void> _pick() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择关注动作',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final id in controller.trackedExerciseIds)
                    ListTile(
                      key: Key('tracked-picker-option-$id'),
                      leading: _ExerciseThumb(
                        exerciseId: id,
                        size: 48,
                        openDetails: false,
                      ),
                      title: Text(
                        controller.displayExerciseName(
                          controller.exerciseFor(id),
                        ),
                      ),
                      selected: id == selectedExerciseId,
                      trailing: id == selectedExerciseId
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && id != null) setState(() => selectedExerciseId = id);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final tracked = controller.trackedExerciseIds;
      if (!tracked.contains(selectedExerciseId)) {
        selectedExerciseId = tracked.firstOrNull;
      }
      final id = selectedExerciseId;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '动作成长',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton.icon(
                key: const Key('manage-tracked-exercises'),
                onPressed: _manage,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('管理'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (id == null)
            Card(
              key: const Key('tracked-exercise-empty'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '选择你想长期关注的动作',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text('完成训练后，可以按日期查看同一动作的重量和次数变化。'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('tracked-exercise-empty-manage'),
                      onPressed: _manage,
                      icon: const Icon(Icons.add),
                      label: const Text('添加关注动作'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: ListTile(
                key: const Key('tracked-exercise-picker'),
                leading: _ExerciseThumb(
                  exerciseId: id,
                  size: 48,
                  openDetails: false,
                ),
                title: Text(
                  controller.displayExerciseName(controller.exerciseFor(id)),
                ),
                subtitle: Text('关注动作 · 共 ${tracked.length} 个'),
                trailing: const Icon(Icons.expand_more_rounded),
                onTap: _pick,
              ),
            ),
            _TrackedExerciseGrowthCard(
              key: Key('tracked-exercise-card-$id'),
              controller: controller,
              exerciseId: id,
              range: widget.range,
              points: buildExerciseGrowthSeries(
                controller.history
                    .where(
                      (record) =>
                          !trendDay(
                            record.date,
                          ).isBefore(trendDay(widget.range.start)) &&
                          !trendDay(
                            record.date,
                          ).isAfter(trendDay(widget.range.end)),
                    )
                    .toList(),
                id,
                definition: controller.exerciseFor(id),
                engine: controller.intelligenceEngine,
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _TrackedExerciseGrowthCard extends StatefulWidget {
  const _TrackedExerciseGrowthCard({
    super.key,
    required this.controller,
    required this.exerciseId,
    required this.points,
    required this.range,
  });
  final AppController controller;
  final String exerciseId;
  final List<ExerciseGrowthPoint> points;
  final DateTimeRange range;
  @override
  State<_TrackedExerciseGrowthCard> createState() =>
      _TrackedExerciseGrowthCardState();
}

class _TrackedExerciseGrowthCardState
    extends State<_TrackedExerciseGrowthCard> {
  String metric = 'weight';
  String? historyKey;
  String _pair(ExerciseGrowthPoint point) =>
      point.isBodyweight ? '自重 × ${point.reps} 次' : point.pairLabel;

  String _venue(ExerciseGrowthPoint point) {
    final gym = widget.controller.gymLocations
        .where((g) => g.id == point.gymId)
        .firstOrNull;
    return gym?.name ?? (point.gymId == null ? '未记录地点' : '历史训练地点');
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.points.map((p) => p.historyKey).toSet();
    final activeKey = keys.contains(historyKey)
        ? historyKey
        : widget.points.lastOrNull?.historyKey;
    final points = widget.points
        .where((p) => p.historyKey == activeKey)
        .toList();
    final latest = points.lastOrNull;
    final previous = points.length > 1 ? points[points.length - 2] : null;
    final bodyweightOnly =
        points.isNotEmpty && points.every((p) => p.isBodyweight);
    final activeMetric = bodyweightOnly ? 'reps' : metric;
    final change = previous == null
        ? '所选期间不足两次记录，暂不计算变化'
        : latest!.isBodyweight != previous.isBodyweight
        ? '与上次负重方式不同，不直接比较重量变化'
        : '较上次（${trendDate(previous.date)}）：'
              '${latest.isBodyweight && previous.isBodyweight ? '' : '重量 ${_signed(latest.weight - previous.weight)} kg · '}'
              '次数 ${_signed(latest.reps - previous.reps)} 次';
    final from = DateUtils.dateOnly(widget.range.start);
    final to = DateTime(
      widget.range.end.year,
      widget.range.end.month,
      widget.range.end.day,
      23,
      59,
      59,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '最近代表组${latest == null ? '' : ' · ${trendDate(latest.date)}'}',
              style: TextStyle(color: quiet, fontSize: 13),
            ),
            const SizedBox(height: 5),
            Text(
              latest == null ? '暂无记录' : _pair(latest),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(change, style: TextStyle(color: quiet, fontSize: 13)),
            if (keys.length > 1) ...[
              const SizedBox(height: 12),
              Text('器械按训练地点分开比较', style: TextStyle(color: quiet)),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final key in keys)
                    ChoiceChip(
                      label: Text(
                        _venue(
                          widget.points.firstWhere((p) => p.historyKey == key),
                        ),
                      ),
                      selected: key == activeKey,
                      onSelected: (_) => setState(() => historyKey = key),
                    ),
                ],
              ),
            ],
            if (!bodyweightOnly && points.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final item in const [('weight', '重量'), ('reps', '次数')])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          key: Key(
                            'tracked-metric-${widget.exerciseId}-${item.$1}',
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: activeMetric == item.$1
                                ? primaryContainer
                                : null,
                          ),
                          onPressed: () => setState(() => metric = item.$1),
                          child: Text(item.$2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TrendChart(
              key: Key('statistics-strength-chart-${widget.exerciseId}'),
              unit: activeMetric == 'weight' ? '代表组重量 · kg' : '代表组次数 · 次',
              start: from,
              end: to,
              integerTicks: activeMetric == 'reps',
              minimumSpan: activeMetric == 'reps' ? 3 : 5,
              data: [
                for (final p in points)
                  TrendDatum(
                    id: p.recordId,
                    date: p.date,
                    value: activeMetric == 'weight'
                        ? (p.isBodyweight ? null : p.weight)
                        : p.reps.toDouble(),
                    description: '${trendDate(p.date)} · ${_pair(p)}',
                  ),
              ],
              detailBuilder: (context, datum) {
                final point = points.firstWhere((p) => p.recordId == datum.id);
                final record = widget.controller.history
                    .where((r) => r.id == datum.id)
                    .firstOrNull;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trendDate(point.date)} · ${TimeOfDay.fromDateTime(point.date).format(context)}',
                      style: TextStyle(color: quiet),
                    ),
                    Text(
                      _pair(point),
                      key: Key(
                        'statistics-strength-point-${widget.exerciseId}',
                      ),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (activeMetric == 'weight' && point.isBodyweight)
                      const Text('本次为自重组，不计入负重折线'),
                    TextButton(
                      key: Key('growth-record-${widget.exerciseId}'),
                      onPressed: record == null
                          ? null
                          : () => _showRecordDetail(
                              context,
                              widget.controller,
                              record,
                            ),
                      child: const Text('查看本次训练'),
                    ),
                  ],
                );
              },
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('代表组如何选择？', style: TextStyle(fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '每次训练取一个已完成工作组，重量和次数来自同一组。负重按估算表现选择，自重按次数选择；热身与技术组不纳入。代表组不等于最重组或个人纪录。',
                    style: TextStyle(color: quiet, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _signed(num value) => '${value > 0 ? '+' : ''}${trendNumber(value)}';
}
