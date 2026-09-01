import 'package:flutter/material.dart';

import 'controller.dart';
import 'membership_ui.dart';
import 'training_intelligence.dart';

class AiTrainingHomeCard extends StatelessWidget {
  const AiTrainingHomeCard({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.trainingIntelligence;
    final today = snapshot.today;
    final member = controller.entitlements?.isMember == true;
    return Container(
      key: const Key('ai-training-home-card'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B2B40),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (!member) {
            showMembershipPaywall(
              context,
              controller: controller,
              reason: MembershipPaywallReason.premiumFeature,
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AiTrainingSystemPage(controller: controller),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '今日 AI 建议',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (!member)
                    const _ProPill()
                  else
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                member ? today.title : '让训练数据替你决定下一步',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                member ? today.reason : '综合力量、动作质量、训练量和恢复状态，给出可解释的今日训练与推荐重量。',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (member) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricPill(
                      icon: Icons.fitness_center_rounded,
                      label: '${today.exerciseCount} 个动作',
                    ),
                    _MetricPill(
                      icon: Icons.schedule_rounded,
                      label: '约 ${today.estimatedMinutes} 分钟',
                    ),
                    for (final muscle in today.muscles.take(2))
                      _MetricPill(
                        icon: Icons.bolt_rounded,
                        label:
                            '$muscle ${snapshot.recovery.where((item) => item.muscle == muscle).first.percent}%',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AiTrainingSystemPage extends StatefulWidget {
  const AiTrainingSystemPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<AiTrainingSystemPage> createState() => _AiTrainingSystemPageState();
}

class _AiTrainingSystemPageState extends State<AiTrainingSystemPage> {
  int section = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.trainingIntelligence;
    const labels = ['今日', '恢复', '训练量', '周报'];
    return Scaffold(
      key: const Key('ai-training-system-page'),
      appBar: AppBar(
        title: const Text('AI 私人教练'),
        actions: [
          IconButton(
            key: const Key('ai-training-gyms'),
            tooltip: '训练地点',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GymLocationsPage(controller: controller),
              ),
            ),
            icon: const Icon(Icons.location_on_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i < labels.length; i++)
                    ButtonSegment(value: i, label: Text(labels[i])),
                ],
                selected: {section},
                onSelectionChanged: (value) =>
                    setState(() => section = value.first),
              ),
            ),
            const SizedBox(height: 16),
            switch (section) {
              0 => _TodayDecision(controller: controller, snapshot: snapshot),
              1 => _RecoverySection(snapshot.recovery),
              2 => _VolumeSection(controller),
              _ => _WeeklyReportSection(snapshot.weeklyReport),
            },
          ],
        ),
      ),
    );
  }
}

class _TodayDecision extends StatelessWidget {
  const _TodayDecision({required this.controller, required this.snapshot});
  final AppController controller;
  final TrainingIntelligenceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = snapshot.today;
    final report = snapshot.weeklyReport;
    final routine = controller.routines
        .where((item) => item.id == today.routineId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: '今天应该做什么',
          icon: Icons.near_me_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                today.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(today.reason, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 12),
              Text(
                '${today.exerciseCount} 个动作 · 预计 ${today.estimatedMinutes} 分钟',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('ai-start-today-workout'),
                onPressed: routine == null
                    ? null
                    : () {
                        controller.startRoutine(routine);
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(routine == null ? '先创建一份训练计划' : '开始今日训练'),
              ),
              const SizedBox(height: 8),
              const Text(
                '建议不会强制修改训练，你始终可以按实际状态选择。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'AI 发现',
          icon: Icons.insights_rounded,
          child: Text(
            '近4周 ${report.undertrainedMuscle} 训练量相对不足。${report.nextWeekAdvice}',
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '本周训练',
          icon: Icons.calendar_today_rounded,
          child: Text(
            '${report.sessions} / ${controller.trainingProfile.weeklyTrainingDays ?? 3} 次 · ${report.durationMinutes} 分钟',
          ),
        ),
      ],
    );
  }
}

class _RecoverySection extends StatelessWidget {
  const _RecoverySection(this.items);
  final List<MuscleRecovery> items;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '肌肉恢复',
    icon: Icons.battery_charging_full_rounded,
    child: Column(
      children: [
        for (final item in items) ...[
          Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  item.muscle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: item.percent / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: item.percent >= 80
                      ? Colors.green
                      : item.percent >= 60
                      ? Colors.blue
                      : item.percent >= 40
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text('${item.percent}%', textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              item.status,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class _VolumeSection extends StatefulWidget {
  const _VolumeSection(this.controller);
  final AppController controller;

  @override
  State<_VolumeSection> createState() => _VolumeSectionState();
}

class _VolumeSectionState extends State<_VolumeSection> {
  int days = 28;
  DateTime? customStart;
  DateTime? customEnd;

  List<MuscleVolume> get items {
    final now = DateTime.now();
    final start = days == 0
        ? customStart ?? now.subtract(const Duration(days: 28))
        : now.subtract(Duration(days: days));
    final end = days == 0 ? customEnd ?? now : now;
    return widget.controller.intelligenceEngine.calculateVolume(
      widget.controller.history,
      widget.controller.allExercises,
      start: start,
      end: end,
      normalizationDays: days == 0
          ? (end.difference(start).inDays + 1).clamp(1, 3650)
          : days,
    );
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: customStart ?? now.subtract(const Duration(days: 28)),
        end: customEnd ?? now,
      ),
      helpText: '选择训练量分析周期',
    );
    if (range != null) {
      setState(() {
        days = 0;
        customStart = range.start;
        customEnd = range.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '肌群训练量',
    icon: Icons.stacked_bar_chart_rounded,
    child: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7天')),
              ButtonSegment(value: 28, label: Text('4周')),
              ButtonSegment(value: 90, label: Text('3个月')),
              ButtonSegment(value: 0, label: Text('自定义')),
            ],
            selected: {days},
            onSelectionChanged: (value) {
              if (value.first == 0) {
                _pickCustom();
              } else {
                setState(() => days = value.first);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              item.muscle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${item.effectiveSets.toStringAsFixed(1)} 个有效组'),
            trailing: _StatusPill(item.status),
          ),
        const Divider(),
        const Text(
          '复合动作的次要肌群按 0.45 组计入；结论用于决定接下来增加或减少哪里，而不只是展示总组数。',
          style: TextStyle(fontSize: 12, height: 1.45),
        ),
      ],
    ),
  );
}

class _WeeklyReportSection extends StatelessWidget {
  const _WeeklyReportSection(this.report);
  final WeeklyTrainingReport report;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '本周 AI 训练报告',
    icon: Icons.summarize_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetricPill(
              icon: Icons.event_available_rounded,
              label: '${report.sessions} 次',
            ),
            _MetricPill(
              icon: Icons.schedule_rounded,
              label: '${report.durationMinutes} 分钟',
            ),
            _MetricPill(
              icon: Icons.trending_up_rounded,
              label: '容量 ${_signed(report.volumeChangePercent)}%',
            ),
            _MetricPill(
              icon: Icons.fitness_center_rounded,
              label: '力量 ${_signed(report.strengthChangePercent)}%',
            ),
            _MetricPill(
              icon: Icons.accessibility_new_rounded,
              label:
                  '技术 ${report.techniqueChange >= 0 ? '+' : ''}${report.techniqueChange}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(report.summary, style: const TextStyle(height: 1.5)),
        if (report.personalRecords.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '本周 PR · ${report.personalRecords.join('、')}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '下周 AI 建议',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(report.nextWeekAdvice, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}

class GymLocationsPage extends StatelessWidget {
  const GymLocationsPage({super.key, required this.controller});
  final AppController controller;

  Future<void> _edit(BuildContext context) async {
    final name = TextEditingController();
    final equipment = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('添加训练地点', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '地点名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: equipment,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '可用器械',
                hintText: '杠铃、深蹲架、Cable、哑铃2-30kg',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await controller.saveGymLocation(
                  GymLocationProfile(
                    id: 'gym-${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    equipment: equipment.text
                        .split(RegExp(r'[,，、\n]'))
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(),
                  ),
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: const Text('保存并设为当前地点'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    equipment.dispose();
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
                    gym.equipment.isEmpty
                        ? '尚未添加器械'
                        : gym.equipment.join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
          Text('添加器械后，AI 才会过滤当前地点无法完成的动作。', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _ProPill extends StatelessWidget {
  const _ProPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'PRO',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

String _signed(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
