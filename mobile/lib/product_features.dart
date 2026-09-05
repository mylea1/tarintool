import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_api.dart';
import 'account_membership.dart';
import 'controller.dart';
import 'exercise_media.dart';
import 'membership_ui.dart';
import 'models.dart';
import 'trend_chart.dart';
import 'trend_data.dart';
import 'workout_share_card.dart';

part 'weight_trend_ui.dart';

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dateText(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';

IconData _mealIcon(String mealType) => switch (mealType) {
  '早餐' => Icons.free_breakfast_outlined,
  '午餐' => Icons.ramen_dining_outlined,
  '晚餐' => Icons.nightlight_outlined,
  '加餐' => Icons.bakery_dining_outlined,
  _ => Icons.restaurant_menu_outlined,
};

double _waterAmount(NutritionEntry entry) {
  if (entry.waterMl > 0) return entry.waterMl;
  if (entry.mealType != '饮水') return 0;
  final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(entry.amount);
  return double.tryParse(match?.group(1) ?? '') ?? 0;
}

Color _primary(BuildContext context) => Theme.of(context).colorScheme.primary;

Color _primaryContainer(BuildContext context) =>
    Theme.of(context).colorScheme.primaryContainer;

Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

Color _onSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);

String _shareStyleLabel(String style) => workoutShareStyleLabel(style);

class NutritionCenterPage extends StatefulWidget {
  const NutritionCenterPage({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final AppController controller;
  final bool embedded;

  @override
  State<NutritionCenterPage> createState() => _NutritionCenterPageState();
}

class _NutritionCenterPageState extends State<NutritionCenterPage> {
  late DateTime selectedDate;
  final Map<DateTime, String> _adviceCache = {};
  bool _generatingAdvice = false;

  @override
  void initState() {
    super.initState();
    selectedDate = _dayOnly(DateTime.now());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择日期',
    );
    if (picked != null) setState(() => selectedDate = _dayOnly(picked));
  }

  void _shiftDate(int amount) {
    setState(() => selectedDate = selectedDate.add(Duration(days: amount)));
  }

  Future<void> _showCapture() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NutritionCaptureSheet(
        controller: widget.controller,
        selectedDate: selectedDate,
        mealType: null,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showCaptureFor(String mealType) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NutritionCaptureSheet(
        controller: widget.controller,
        selectedDate: selectedDate,
        mealType: mealType,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showWaterEntry() async {
    final amount = TextEditingController(text: '500');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('记录饮水'),
        content: TextField(
          controller: amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '饮水量 ml'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(double.tryParse(amount.text.trim())),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value == null || value <= 0 || !mounted) return;
    final now = DateTime.now();
    await widget.controller.addNutritionEntry(
      NutritionEntry(
        id: 'water-${now.microsecondsSinceEpoch}',
        recordedAt: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
        ),
        mealType: '饮水',
        foodName: '饮水',
        calories: 0,
        amount: '${value.toStringAsFixed(0)} ml',
        waterMl: value,
      ),
    );
  }

  Future<void> _generateAdvice() async {
    final day = _dayOnly(selectedDate);
    if (_adviceCache.containsKey(day) || _generatingAdvice) return;
    setState(() => _generatingAdvice = true);
    // Keep this local and deterministic until the coach endpoint exposes a
    // date-scoped nutrition prompt. It uses the same durable data the AI
    // surface will receive, and never runs just by opening the page.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    if (widget.controller.isAuthenticated) {
      try {
        final remote = await widget.controller.requestNutritionAdvice(day);
        if (!mounted) return;
        setState(() {
          _adviceCache[day] = remote.trim();
          _generatingAdvice = false;
        });
        return;
      } catch (_) {
        // A local, deterministic summary keeps the page useful when the
        // Coach endpoint is temporarily unavailable.
      }
    }
    final entries = widget.controller.nutritionForDay(day);
    final calories = entries
        .where((item) => _waterAmount(item) <= 0 && item.mealType != '饮水')
        .fold<double>(0, (sum, item) => sum + item.calories);
    final protein = entries
        .where((item) => _waterAmount(item) <= 0 && item.mealType != '饮水')
        .fold<double>(0, (sum, item) => sum + item.proteinGrams);
    final calorieTarget = widget.controller.estimatedDailyCalories;
    final proteinTarget = widget.controller.trainingProfile.weightKg == null
        ? null
        : widget.controller.trainingProfile.weightKg! * 1.6;
    final lines = <String>[];
    if (calories == 0 && protein == 0) {
      final goal = switch (widget.controller.trainingProfile.goal) {
        'muscle_gain' => '增肌',
        'fat_loss' => '减脂',
        'body_recomp' => '塑形',
        'strength' => '力量',
        _ => '当前',
      };
      lines.add(
        '按你的$goal目标，今日可先执行'
        '${calorieTarget == null ? '稳定三餐' : '约 ${calorieTarget.toStringAsFixed(0)} kcal'}'
        '${proteinTarget == null ? '' : '、蛋白质约 ${proteinTarget.toStringAsFixed(0)} g'}。',
      );
      lines.add('把蛋白质分配到各餐，训练前后安排主食和优质蛋白。');
    } else if (proteinTarget != null && protein < proteinTarget * .8) {
      lines.add(
        '今天蛋白质摄入偏低，还差 ${(proteinTarget - protein).clamp(0, proteinTarget).toStringAsFixed(0)} g。',
      );
      lines.add('下一餐优先补充鸡蛋、鱼肉或奶制品等优质蛋白。');
    } else if (calorieTarget != null && calories < calorieTarget * .8) {
      lines.add('当前热量低于目标，训练日可适当补充碳水与能量。');
    } else if (calorieTarget != null && calories > calorieTarget * 1.1) {
      lines.add('当前热量略高于目标，后续餐次可以适当收窄份量。');
    } else {
      lines.add('当前摄入接近目标，继续保持记录节奏。');
    }
    final hasTraining = widget.controller.history.any(
      (record) => _sameDay(record.date, day),
    );
    if (hasTraining && lines.length < 2) {
      lines.add('今天有训练，训练前后可结合训练量安排适量碳水。');
    }
    setState(() {
      _adviceCache[day] = lines.take(2).join(' ');
      _generatingAdvice = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => ListView(
        key: const Key('nutrition-center-list'),
        padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 10, 16, 32),
        children: [
          _NutritionDateNavigator(
            selectedDate: selectedDate,
            onSelected: (date) => setState(() => selectedDate = date),
            onPrevious: () => _shiftDate(-7),
            onNext: () => _shiftDate(7),
            onPick: _pickDate,
          ),
          const SizedBox(height: 12),
          _NutritionAiAdviceModule(
            controller: widget.controller,
            date: selectedDate,
            advice: _adviceCache[_dayOnly(selectedDate)],
            generating: _generatingAdvice,
            onGenerate: _generateAdvice,
          ),
          if (widget.controller
              .nutritionForDay(selectedDate)
              .where((item) => _waterAmount(item) <= 0 && item.mealType != '饮水')
              .isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('nutrition-empty-add'),
                onPressed: _showCapture,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('记录第一餐'),
              ),
            ),
          const SizedBox(height: 12),
          _NutritionDaySummary(
            controller: widget.controller,
            date: selectedDate,
          ),
          const SizedBox(height: 12),
          _NutritionQuickActions(
            onMeal: _showCaptureFor,
            onWater: _showWaterEntry,
            onWeight: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _WeightEntryPage(
                  controller: widget.controller,
                  initialDate: selectedDate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _WeightOverviewCard(
            controller: widget.controller,
            date: selectedDate,
            onViewAll: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _WeightDetailsPage(
                  controller: widget.controller,
                  initialDate: selectedDate,
                ),
              ),
            ),
            onAdd: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _WeightEntryPage(
                  controller: widget.controller,
                  initialDate: selectedDate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '饮食时间轴',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.icon(
                key: const Key('nutrition-add-entry'),
                onPressed: _showCapture,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('记录'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _NutritionTimeline(
            controller: widget.controller,
            date: selectedDate,
            onAdd: _showCapture,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('nutrition-unified-calendar-button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UnifiedCalendarPage(
                  controller: widget.controller,
                  initialDate: selectedDate,
                ),
              ),
            ),
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('查看训练与饮食日历'),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return KeyedSubtree(
        key: const Key('nutrition-center-page'),
        child: content,
      );
    }
    // Standalone entry (for example from the home nutrition card) uses the
    // same full-page overview as Records → Diet. Keep actions in the page
    // itself so there is no second “饮食” title bar or floating-only entry
    // point competing with the timeline controls.
    return Scaffold(
      key: const Key('nutrition-center-page'),
      body: SafeArea(child: content),
    );
  }
}

class _NutritionAiAdviceModule extends StatefulWidget {
  const _NutritionAiAdviceModule({
    required this.controller,
    required this.date,
    required this.advice,
    required this.generating,
    required this.onGenerate,
  });

  final AppController controller;
  final DateTime date;
  final String? advice;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  State<_NutritionAiAdviceModule> createState() =>
      _NutritionAiAdviceModuleState();
}

class _NutritionAiAdviceModuleState extends State<_NutritionAiAdviceModule> {
  bool expanded = false;

  AppController get controller => widget.controller;
  DateTime get date => widget.date;
  String? get advice => widget.advice;
  bool get generating => widget.generating;
  VoidCallback get onGenerate => widget.onGenerate;

  double _totalCalories(List<NutritionEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.calories);

  @override
  Widget build(BuildContext context) {
    final entries = controller.nutritionForDay(date);
    final foodEntries = entries
        .where((item) => _waterAmount(item) <= 0 && item.mealType != '饮水')
        .toList(growable: false);
    final calories = _totalCalories(foodEntries);
    final hasAdvice = advice != null && advice!.trim().isNotEmpty;
    final isMember = controller.entitlements?.isMember == true;
    if (!isMember) {
      return Card(
        key: const Key('nutrition-ai-advice-locked'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 19,
                    color: _primary(context),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'AI 今日饮食建议',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _NutritionProPill(),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: _muted(context),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '根据基础档案、训练目标与今日记录生成专属建议。',
                style: TextStyle(color: _muted(context), fontSize: 12),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '已记录 ${calories.toStringAsFixed(0)} kcal',
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('nutrition-ai-advice-paywall'),
                    onPressed: () => showMembershipPaywall(
                      context,
                      controller: controller,
                      reason: MembershipPaywallReason.premiumFeature,
                    ),
                    icon: const Icon(Icons.lock_open_outlined, size: 16),
                    label: const Text('解锁建议'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      key: const Key('nutrition-ai-advice'),
      color: _primaryContainer(context).withValues(alpha: .3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _surface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                color: _primary(context),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '今日建议',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _NutritionProPill(),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '根据基础档案与今日记录\n生成专属饮食建议',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted(context), fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '已记录 ${calories.toStringAsFixed(0)} kcal',
                    style: TextStyle(color: _muted(context), fontSize: 12),
                  ),
                  if (controller.trainingProfile.weightKg != null)
                    Text(
                      '蛋白质目标：${(controller.trainingProfile.weightKg! * 1.6).toStringAsFixed(0)} g',
                      style: TextStyle(color: _muted(context), fontSize: 11),
                    ),
                  if (hasAdvice) ...[
                    const SizedBox(height: 7),
                    Text(
                      advice!,
                      key: const Key('nutrition-ai-advice-content'),
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('nutrition-ai-advice-expand'),
                        onPressed: () => setState(() => expanded = !expanded),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 32),
                        ),
                        child: Text(expanded ? '收起' : '展开'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 7),
                    Text(
                      '基础档案已可用于生成第一份建议',
                      key: const Key('nutrition-ai-advice-content'),
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('nutrition-ai-advice-generate'),
              onPressed: generating ? null : onGenerate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                minimumSize: const Size(0, 38),
              ),
              child: generating
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(hasAdvice ? '已生成' : '生成建议'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionProPill extends StatelessWidget {
  const _NutritionProPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _primaryContainer(context),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'PRO',
      style: TextStyle(
        color: _primary(context),
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _NutritionDateNavigator extends StatelessWidget {
  const _NutritionDateNavigator({
    required this.selectedDate,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final start = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final dates = List<DateTime>.generate(
      7,
      (index) => _dayOnly(start.add(Duration(days: index))),
    );
    return Card(
      key: const Key('nutrition-date-navigator'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  tooltip: '上一周',
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('nutrition-date-picker'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: onPick,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [
                          Text(
                            _dateText(selectedDate),
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _sameDay(selectedDate, DateTime.now())
                                ? '今天'
                                : '点击切换日期',
                            style: TextStyle(
                              color: _muted(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  tooltip: '下一周',
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final date in dates)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _NutritionDateCell(
                        date: date,
                        selected: _sameDay(date, selectedDate),
                        onTap: () => onSelected(date),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionDateCell extends StatelessWidget {
  const _NutritionDateCell({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('nutrition-date-${date.year}-${date.month}-${date.day}'),
    borderRadius: BorderRadius.circular(13),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? _primary(context)
            : _primaryContainer(context).withValues(alpha: .34),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1],
            style: TextStyle(
              color: selected ? Colors.white : _muted(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: TextStyle(
              color: selected ? Colors.white : _onSurface(context),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NutritionDaySummary extends StatelessWidget {
  const _NutritionDaySummary({required this.controller, required this.date});

  final AppController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final entries = controller.nutritionForDay(date);
    final foodEntries = entries
        .where((item) => _waterAmount(item) <= 0 && item.mealType != '饮水')
        .toList(growable: false);
    final calories = entries.fold<double>(
      0,
      (sum, item) => sum + (_waterAmount(item) > 0 ? 0 : item.calories),
    );
    final protein = foodEntries.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final carbs = foodEntries.fold<double>(
      0,
      (sum, item) => sum + item.carbsGrams,
    );
    final fat = foodEntries.fold<double>(0, (sum, item) => sum + item.fatGrams);
    final water = entries.fold<double>(
      0,
      (sum, item) => sum + _waterAmount(item),
    );
    final calorieTarget = controller.estimatedDailyCalories;
    final proteinTarget = controller.trainingProfile.weightKg == null
        ? null
        : controller.trainingProfile.weightKg! * 1.6;
    const carbsTarget = 320.0;
    const fatTarget = 80.0;
    const waterTarget = 2500.0;
    return Card(
      key: const Key('nutrition-day-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: calories.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(
                          text: calorieTarget == null
                              ? ' kcal'
                              : ' / ${calorieTarget.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  '${foodEntries.length} 次记录',
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 350;
                final metrics = [
                  _NutritionRingMetric(
                    label: '蛋白质',
                    unit: 'g',
                    value: protein,
                    target: proteinTarget,
                    color: const Color(0xFFE99A49),
                    keyName: 'nutrition-ring-protein',
                  ),
                  _NutritionRingMetric(
                    label: '碳水',
                    unit: 'g',
                    value: carbs,
                    target: carbsTarget,
                    color: const Color(0xFF6E9FE4),
                    keyName: 'nutrition-ring-carbs',
                  ),
                  _NutritionRingMetric(
                    label: '脂肪',
                    unit: 'g',
                    value: fat,
                    target: fatTarget,
                    color: const Color(0xFFE98282),
                    keyName: 'nutrition-ring-fat',
                  ),
                  _NutritionRingMetric(
                    label: '饮水',
                    unit: 'ml',
                    value: water,
                    target: waterTarget,
                    color: const Color(0xFF46B8B3),
                    keyName: 'nutrition-ring-water',
                  ),
                ];
                return Row(
                  children: [
                    for (final metric in metrics)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 0 : 2,
                          ),
                          child: metric,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionRingMetric extends StatelessWidget {
  const _NutritionRingMetric({
    required this.label,
    required this.unit,
    required this.value,
    required this.target,
    required this.color,
    required this.keyName,
  });

  final String label;
  final String unit;
  final double value;
  final double? target;
  final Color color;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final progress = target == null || target! <= 0
        ? 0.0
        : (value / target!).clamp(0.0, 1.0);
    final targetLabel = target == null ? '—' : target!.toStringAsFixed(0);
    return Column(
      key: Key(keyName),
      children: [
        SizedBox(
          width: 67,
          height: 67,
          child: CustomPaint(
            painter: _NutritionRingPainter(progress: progress, color: color),
            child: Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: value.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: '\n/$targetLabel',
                      style: TextStyle(fontSize: 10, color: _muted(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$label ($unit)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          target == null ? '完善目标' : '${(progress * 100).round()}%',
          style: TextStyle(color: _muted(context), fontSize: 10),
        ),
      ],
    );
  }
}

class _NutritionRingPainter extends CustomPainter {
  const _NutritionRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 5;
    final track = Paint()
      ..color = color.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final active = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        active,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NutritionRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _NutritionQuickActions extends StatelessWidget {
  const _NutritionQuickActions({
    required this.onMeal,
    required this.onWater,
    required this.onWeight,
  });

  final ValueChanged<String> onMeal;
  final VoidCallback onWater;
  final VoidCallback onWeight;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _NutritionQuickAction(
        keyName: 'nutrition-quick-breakfast',
        label: '早餐',
        icon: Icons.free_breakfast_outlined,
        onTap: () => onMeal('早餐'),
      ),
      _NutritionQuickAction(
        keyName: 'nutrition-quick-lunch',
        label: '午餐',
        icon: Icons.ramen_dining_outlined,
        onTap: () => onMeal('午餐'),
      ),
      _NutritionQuickAction(
        keyName: 'nutrition-quick-dinner',
        label: '晚餐',
        icon: Icons.nightlight_outlined,
        onTap: () => onMeal('晚餐'),
      ),
      _NutritionQuickAction(
        keyName: 'nutrition-quick-snack',
        label: '加餐',
        icon: Icons.bakery_dining_outlined,
        onTap: () => onMeal('加餐'),
      ),
      _NutritionQuickAction(
        keyName: 'nutrition-quick-water',
        label: '饮水',
        icon: Icons.water_drop_outlined,
        onTap: onWater,
      ),
      KeyedSubtree(
        key: const Key('nutrition-log-weight'),
        child: _NutritionQuickAction(
          keyName: 'nutrition-quick-weight',
          label: '记体重',
          icon: Icons.monitor_weight_outlined,
          onTap: onWeight,
        ),
      ),
    ];
    return GridView.count(
      key: const Key('nutrition-quick-actions'),
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 2.45,
      children: actions,
    );
  }
}

class _NutritionQuickAction extends StatelessWidget {
  const _NutritionQuickAction({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _primaryContainer(context).withValues(alpha: .26),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: Key(keyName),
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: _primary(context)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WeightPoint {
  const _WeightPoint(this.entry);
  final WeightEntry entry;
  DateTime get day => _dayOnly(entry.recordedAt);
  double get value => entry.weightKg;
}

List<_WeightPoint> _dailyWeightPoints(
  AppController controller, {
  required DateTime start,
  required DateTime end,
}) => dailyWeightRecords(
  controller.weightEntries,
  start,
  end,
).map(_WeightPoint.new).toList();

class _WeightOverviewCard extends StatefulWidget {
  const _WeightOverviewCard({
    required this.controller,
    required this.date,
    required this.onViewAll,
    required this.onAdd,
  });

  final AppController controller;
  final DateTime date;
  final VoidCallback onViewAll;
  final VoidCallback onAdd;

  @override
  State<_WeightOverviewCard> createState() => _WeightOverviewCardState();
}

class _WeightOverviewCardState extends State<_WeightOverviewCard> {
  String range = '7';

  List<_WeightPoint> get points {
    final end = _dayOnly(widget.date);
    final days = int.parse(range);
    return _dailyWeightPoints(
      widget.controller,
      start: end.subtract(Duration(days: days - 1)),
      end: end,
    );
  }

  WeightEntry? get latest {
    final sorted =
        widget.controller.weightEntries
            .where(
              (item) => !item.recordedAt.isAfter(
                DateTime(
                  widget.date.year,
                  widget.date.month,
                  widget.date.day,
                  23,
                  59,
                  59,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sorted.firstOrNull;
  }

  WeightEntry? get previous {
    final current = latest;
    if (current == null) return null;
    final sorted =
        widget.controller.weightEntries
            .where((item) => item.recordedAt.isBefore(current.recordedAt))
            .toList()
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return sorted.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final current = latest;
    final before = previous;
    final chartPoints = points;
    final first = chartPoints.firstOrNull;
    final sevenDayDelta = chartPoints.length < 2
        ? null
        : chartPoints.last.value - first!.value;
    return Card(
      key: const Key('nutrition-weight-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '体重变化',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(70, 36),
                  ),
                  child: const Text('查看全部  ›'),
                ),
              ],
            ),
            if (current == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
                child: Row(
                  children: [
                    Icon(Icons.monitor_weight_outlined, color: _muted(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '暂无体重记录，记录一次后可查看趋势。',
                        style: TextStyle(color: _muted(context)),
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('nutrition-weight-empty-add'),
                      onPressed: widget.onAdd,
                      child: const Text('记录'),
                    ),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _WeightSummaryMetric(
                    label: '最近记录 · ${trendDate(current.recordedAt)}',
                    value: '${current.weightKg.toStringAsFixed(1)} kg',
                  ),
                  _WeightSummaryMetric(
                    label: '较上次',
                    value: before == null
                        ? '—'
                        : _signedWeight(current.weightKg - before.weightKg),
                    color: _muted(context),
                  ),
                  _WeightSummaryMetric(
                    label: chartPoints.length < 2
                        ? '所选期间变化'
                        : '${trendDate(chartPoints.first.day)}—${trendDate(chartPoints.last.day)}',
                    value: sevenDayDelta == null
                        ? '—'
                        : _signedWeight(sevenDayDelta),
                    color: _muted(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                for (final value in const ['7', '30', '90'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        key: Key('nutrition-weight-range-$value'),
                        onPressed: () => setState(() => range = value),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.zero,
                          backgroundColor: range == value
                              ? _primaryContainer(
                                  context,
                                ).withValues(alpha: .45)
                              : null,
                          side: BorderSide(
                            color: range == value
                                ? _primary(context)
                                : _primaryContainer(context),
                          ),
                        ),
                        child: Text('$value天'),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null)
              _WeightChart(
                key: const Key('nutrition-weight-chart'),
                points: chartPoints,
                controller: widget.controller,
                start: _dayOnly(
                  widget.date,
                ).subtract(Duration(days: int.parse(range) - 1)),
                end: _dayOnly(widget.date),
              ),
          ],
        ),
      ),
    );
  }
}

String _signedWeight(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} kg';

Color _trendColor(BuildContext context, double value) => _muted(context);

class _WeightSummaryMetric extends StatelessWidget {
  const _WeightSummaryMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: _muted(context), fontSize: 11)),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _WeightDetailsPage extends StatefulWidget {
  const _WeightDetailsPage({
    required this.controller,
    required this.initialDate,
  });

  final AppController controller;
  final DateTime initialDate;

  @override
  State<_WeightDetailsPage> createState() => _WeightDetailsPageState();
}

class _WeightDetailsPageState extends State<_WeightDetailsPage> {
  String range = 'all';

  AppController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('weight-details-page'),
      appBar: AppBar(
        title: const Text('体重记录'),
        actions: [
          IconButton(
            tooltip: '新增体重',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _WeightEntryPage(
                  controller: controller,
                  initialDate: widget.initialDate,
                ),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final now = _dayOnly(DateTime.now());
            final allEntries = [...controller.weightEntries]
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
            final chartStart = _weightRangeStart(range, allEntries, now);
            final entries = allEntries
                .where(
                  (e) =>
                      !_dayOnly(e.recordedAt).isBefore(chartStart) &&
                      !_dayOnly(e.recordedAt).isAfter(now),
                )
                .toList();
            final current = entries.firstOrNull;
            final daily = _dailyWeightPoints(
              controller,
              start: chartStart,
              end: now,
            );
            final initial = daily.firstOrNull?.entry;
            final total = daily.length < 2
                ? null
                : daily.last.value - daily.first.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        _WeightSummaryMetric(
                          label: current == null
                              ? '最近记录'
                              : '最近记录 · ${trendDate(current.recordedAt)}',
                          value: current == null
                              ? '—'
                              : '${current.weightKg.toStringAsFixed(1)} kg',
                        ),
                        _WeightSummaryMetric(
                          label: '范围内首次',
                          value: initial == null
                              ? '—'
                              : '${initial.weightKg.toStringAsFixed(1)} kg',
                        ),
                        _WeightSummaryMetric(
                          label: '所选期间变化',
                          value: total == null ? '—' : _signedWeight(total),
                          color: _trendColor(context, total ?? 0),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  key: const Key('weight-details-range'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in const [
                      ('7', '7天'),
                      ('30', '30天'),
                      ('90', '90天'),
                      ('all', '全部'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: range == item.$1,
                        onSelected: (_) => setState(() => range = item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _WeightChart(
                  key: const Key('weight-details-chart'),
                  controller: controller,
                  start: chartStart,
                  end: now,
                  points: _dailyWeightPoints(
                    controller,
                    start: chartStart,
                    end: now,
                  ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Center(
                        child: Text(
                          '暂无体重记录',
                          style: TextStyle(color: _muted(context)),
                        ),
                      ),
                    ),
                  )
                else
                  for (var index = 0; index < entries.length; index++)
                    _WeightHistoryTile(
                      entry: entries[index],
                      previous: index + 1 < entries.length
                          ? entries[index + 1]
                          : null,
                      controller: controller,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

DateTime _weightRangeStart(
  String range,
  List<WeightEntry> entries,
  DateTime end,
) {
  if (range == 'all') {
    return entries.isEmpty ? end : _dayOnly(entries.last.recordedAt);
  }
  final days = int.tryParse(range) ?? 7;
  return end.subtract(Duration(days: days - 1));
}

class _WeightHistoryTile extends StatelessWidget {
  const _WeightHistoryTile({
    required this.entry,
    required this.previous,
    required this.controller,
  });

  final WeightEntry entry;
  final WeightEntry? previous;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final delta = previous == null ? null : entry.weightKg - previous!.weightKg;
    return Card(
      key: Key('weight-history-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${entry.weightKg.toStringAsFixed(1)} kg',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_dateText(entry.recordedAt)} ${entry.recordedAt.hour.toString().padLeft(2, '0')}:${entry.recordedAt.minute.toString().padLeft(2, '0')}${delta == null ? '' : ' · 较上一条 ${_signedWeight(delta)}'}${entry.note.trim().isEmpty ? '' : ' · ${entry.note.trim()}'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'delete') {
              await controller.deleteWeightEntry(entry.id);
            } else if (action == 'edit' && context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _WeightEntryPage(
                    controller: controller,
                    initialDate: entry.recordedAt,
                    initialEntry: entry,
                  ),
                ),
              );
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: _primary(context))),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightEntryPage extends StatefulWidget {
  const _WeightEntryPage({
    required this.controller,
    required this.initialDate,
    this.initialEntry,
  });

  final AppController controller;
  final DateTime initialDate;
  final WeightEntry? initialEntry;

  @override
  State<_WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<_WeightEntryPage> {
  late final TextEditingController weight;
  late final TextEditingController note;
  late DateTime date;
  late TimeOfDay time;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.initialEntry;
    weight = TextEditingController(
      text: existing == null ? '' : existing.weightKg.toStringAsFixed(1),
    );
    note = TextEditingController(text: existing?.note ?? '');
    date = _dayOnly(existing?.recordedAt ?? widget.initialDate);
    final initialTime = existing?.recordedAt ?? DateTime.now();
    time = TimeOfDay.fromDateTime(initialTime);
  }

  @override
  void dispose() {
    weight.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(weight.text.trim());
    if (value == null || value <= 0) {
      setState(() => error = '请输入有效体重');
      return;
    }
    setState(() {
      error = null;
      saving = true;
    });
    final recordedAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final old = widget.initialEntry;
    final entry = WeightEntry(
      id: old?.id ?? 'weight-${DateTime.now().microsecondsSinceEpoch}',
      recordedAt: recordedAt,
      weightKg: value,
      note: note.text.trim(),
    );
    if (old == null) {
      await widget.controller.addWeightEntry(entry);
    } else {
      await widget.controller.updateWeightEntry(entry);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('weight-entry-page'),
    appBar: AppBar(title: Text(widget.initialEntry == null ? '记录体重' : '编辑体重')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          TextField(
            key: const Key('weight-entry-value'),
            controller: weight,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '体重 kg *',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('日期'),
            subtitle: Text(_dateText(date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => date = _dayOnly(picked));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('时间'),
            subtitle: Text(time.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) setState(() => time = picked);
            },
          ),
          TextField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: _primary(context))),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            key: const Key('nutrition-weight-save'),
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('保存体重'),
          ),
        ],
      ),
    ),
  );
}

class _NutritionTimeline extends StatelessWidget {
  const _NutritionTimeline({
    required this.controller,
    required this.date,
    required this.onAdd,
  });

  final AppController controller;
  final DateTime date;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final entries = [...controller.nutritionForDay(date)]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (entries.isEmpty) {
      return Card(
        key: const Key('nutrition-empty-state'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
          child: Column(
            children: [
              Icon(Icons.no_food_outlined, size: 38, color: _muted(context)),
              const SizedBox(height: 9),
              const Text(
                '还没有记录',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('nutrition-empty-add-timeline'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('记录第一餐'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _NutritionEntryTile(
            controller: controller,
            entry: entries[index],
            index: index,
          ),
      ],
    );
  }
}

class _NutritionEntryTile extends StatelessWidget {
  const _NutritionEntryTile({
    required this.controller,
    required this.entry,
    required this.index,
  });

  final AppController controller;
  final NutritionEntry entry;
  final int index;

  void _showDetails(BuildContext context, String title, bool isWater) {
    final lines = <String>[
      '时间：${entry.recordedAt.hour.toString().padLeft(2, '0')}:${entry.recordedAt.minute.toString().padLeft(2, '0')}',
      if (isWater)
        '饮水：${_waterAmount(entry).toStringAsFixed(0)} ml'
      else ...[
        '热量：${entry.calories.toStringAsFixed(0)} kcal',
        '蛋白质：${entry.proteinGrams.toStringAsFixed(1)} g',
        '碳水：${entry.carbsGrams.toStringAsFixed(1)} g',
        '脂肪：${entry.fatGrams.toStringAsFixed(1)} g',
        if (entry.amount.trim().isNotEmpty) '份量：${entry.amount.trim()}',
      ],
      if (entry.photoPaths.isNotEmpty) '照片：${entry.photoPaths.length} 张',
      if (entry.recognitionWarnings.isNotEmpty)
        '识别提示：${entry.recognitionWarnings.join('；')}',
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(lines.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWater = _waterAmount(entry) > 0 || entry.mealType == '饮水';
    final title = isWater
        ? '饮水'
        : entry.foodName.trim().isEmpty
        ? entry.mealType.trim().isEmpty
              ? '未命名餐次'
              : entry.mealType
        : entry.foodName.trim();
    final details = <String>[
      if (isWater)
        '${_waterAmount(entry).toStringAsFixed(0)} ml'
      else ...[
        '${entry.calories.toStringAsFixed(0)} kcal',
        if (entry.proteinGrams > 0)
          '蛋白质 ${entry.proteinGrams.toStringAsFixed(0)} g',
      ],
      if (!isWater && entry.amount.trim().isNotEmpty) entry.amount.trim(),
    ];
    return Card(
      key: Key('nutrition-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(context, title, isWater),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 7, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryContainer(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWater
                      ? Icons.water_drop_outlined
                      : _mealIcon(entry.mealType),
                  color: _primary(context),
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${entry.recordedAt.hour.toString().padLeft(2, '0')}:${entry.recordedAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: _muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                    if (entry.photoPaths.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: entry.photoPaths.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, photoIndex) => _LocalPhoto(
                            path: entry.photoPaths[photoIndex],
                            size: 48,
                          ),
                        ),
                      ),
                    ],
                    if (entry.recognitionWarnings.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: _primary(context),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              entry.recognitionWarnings.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _muted(context),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除记录',
                onPressed: () => controller.deleteNutritionEntry(entry.id),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalPhoto extends StatelessWidget {
  const _LocalPhoto({required this.path, this.size = 64});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: size,
      height: size,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: _primaryContainer(context),
          child: Icon(
            Icons.image_not_supported_outlined,
            color: _primary(context),
          ),
        ),
      ),
    ),
  );
}

class _NutritionCaptureSheet extends StatefulWidget {
  const _NutritionCaptureSheet({
    required this.controller,
    required this.selectedDate,
    this.mealType,
  });

  final AppController controller;
  final DateTime selectedDate;
  final String? mealType;

  @override
  State<_NutritionCaptureSheet> createState() => _NutritionCaptureSheetState();
}

class _NutritionCaptureSheetState extends State<_NutritionCaptureSheet> {
  late final TextEditingController food;
  late final TextEditingController amount;
  late final TextEditingController calories;
  late final TextEditingController protein;
  late final TextEditingController carbs;
  late final TextEditingController fat;
  final imagePaths = <String>[];
  FoodPhotoRecognitionResult? recognition;
  String? error;
  bool recognizing = false;
  bool saving = false;

  bool get isMember => widget.controller.entitlements?.isMember == true;

  @override
  void initState() {
    super.initState();
    food = TextEditingController();
    amount = TextEditingController();
    calories = TextEditingController();
    protein = TextEditingController();
    carbs = TextEditingController();
    fat = TextEditingController();
  }

  @override
  void dispose() {
    food.dispose();
    amount.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (!isMember) {
      await showMembershipPaywall(
        context,
        controller: widget.controller,
        reason: MembershipPaywallReason.nutritionPhoto,
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty);
    setState(() {
      imagePaths
        ..clear()
        ..addAll(paths.take(8));
      error = null;
      recognition = null;
    });
    if (imagePaths.isNotEmpty) await _recognize();
  }

  Future<void> _recognize() async {
    if (!isMember) {
      await showMembershipPaywall(
        context,
        controller: widget.controller,
        reason: MembershipPaywallReason.nutritionPhoto,
      );
      return;
    }
    if (recognizing || imagePaths.isEmpty) return;
    setState(() {
      recognizing = true;
      error = null;
    });
    try {
      final value = await widget.controller.recognizeFoodPhotosRemote(
        imagePaths,
      );
      if (!mounted) return;
      setState(() {
        recognition = value;
        recognizing = false;
      });
      _applyCandidate(value);
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        recognizing = false;
        error = _recognitionError(caught);
      });
    }
  }

  String _recognitionError(Object caught) {
    if (caught is CoachApiException) {
      return switch (caught.code) {
        'food_images_required' || 'food_images_unreadable' => '图片不可用，请重新选择。',
        'coach_unauthenticated' || 'coach_session_expired' => '登录后才能使用拍照识别。',
        'membership_required' => '拍照识别是形域 PRO 会员功能。',
        'food_recognition_unavailable' ||
        'food_recognition_http_404' => '识别服务尚未配置，可直接手动记录。',
        _ => '识别失败，可重试或直接手动记录。',
      };
    }
    return '识别失败，可重试或直接手动记录。';
  }

  void _applyCandidate(FoodPhotoRecognitionResult value) {
    if (value.items.isEmpty) return;
    final labels = value.items
        .map((item) => item.label.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .join('、');
    final grams = value.items.fold<double>(
      0,
      (sum, item) => sum + (item.estimatedGrams ?? 0),
    );
    final kcal = value.items
        .map((item) => item.calories)
        .whereType<double>()
        .fold<double>(0, (sum, item) => sum + item);
    final proteinValue = value.items
        .map((item) => item.proteinGrams)
        .whereType<double>()
        .fold<double>(0, (sum, item) => sum + item);
    final carbsValue = value.items
        .map((item) => item.carbsGrams)
        .whereType<double>()
        .fold<double>(0, (sum, item) => sum + item);
    final fatValue = value.items
        .map((item) => item.fatGrams)
        .whereType<double>()
        .fold<double>(0, (sum, item) => sum + item);
    if (food.text.trim().isEmpty && labels.isNotEmpty) {
      food.text = labels;
    }
    if (amount.text.trim().isEmpty && grams > 0) {
      amount.text = '${grams.toStringAsFixed(0)} g';
    }
    if (calories.text.trim().isEmpty && kcal > 0) {
      calories.text = kcal.toStringAsFixed(0);
    }
    if (protein.text.trim().isEmpty && proteinValue > 0) {
      protein.text = proteinValue.toStringAsFixed(1);
    }
    if (carbs.text.trim().isEmpty && carbsValue > 0) {
      carbs.text = carbsValue.toStringAsFixed(1);
    }
    if (fat.text.trim().isEmpty && fatValue > 0) {
      fat.text = fatValue.toStringAsFixed(1);
    }
  }

  Future<void> _save() async {
    final kcal = double.tryParse(calories.text.trim());
    if (kcal == null || kcal < 0) {
      setState(() => error = '请输入有效热量，或先完成照片识别。');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final now = DateTime.now();
    try {
      await widget.controller.addNutritionEntry(
        NutritionEntry(
          id: 'nutrition-${now.microsecondsSinceEpoch}',
          recordedAt: DateTime(
            widget.selectedDate.year,
            widget.selectedDate.month,
            widget.selectedDate.day,
            now.hour,
            now.minute,
          ),
          mealType:
              widget.mealType ??
              widget.controller.nextMealLabelFor(widget.selectedDate),
          foodName: food.text.trim(),
          amount: amount.text.trim(),
          calories: kcal,
          proteinGrams: double.tryParse(protein.text.trim()) ?? 0,
          carbsGrams: double.tryParse(carbs.text.trim()) ?? 0,
          fatGrams: double.tryParse(fat.text.trim()) ?? 0,
          photoPaths: List<String>.unmodifiable(imagePaths),
          recognitionWarnings: recognition?.warnings ?? const [],
          recognitionReviewed:
              recognition != null && recognition!.requiresReview,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => error = '保存失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: SingleChildScrollView(
        key: const Key('nutrition-capture-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '记录饮食',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  _dateText(widget.selectedDate),
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              isMember ? '照片识别后请复核候选值，食物名称可留空。' : '手动记录免费；多图拍照识别为 PRO 会员功能。',
              style: TextStyle(color: _muted(context), fontSize: 12),
            ),
            const SizedBox(height: 13),
            KeyedSubtree(
              key: const Key('nutrition-multi-photo-picker'),
              child: OutlinedButton.icon(
                key: const Key('nutrition-photo-picker'),
                onPressed: recognizing ? null : _pickImages,
                icon: Icon(
                  isMember
                      ? Icons.photo_library_outlined
                      : Icons.lock_outline_rounded,
                ),
                label: Text(
                  imagePaths.isEmpty
                      ? (isMember ? '选择食物照片' : 'PRO 拍照识别')
                      : '重新选择照片（${imagePaths.length}/8）',
                ),
              ),
            ),
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 9),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _LocalPhoto(path: imagePaths[index], size: 76),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: _surface(context),
                          ),
                          onPressed: recognizing
                              ? null
                              : () =>
                                    setState(() => imagePaths.removeAt(index)),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _onSurface(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (recognizing)
                const Row(
                  children: [
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Expanded(child: Text('正在识别营养候选…')),
                  ],
                )
              else
                OutlinedButton.icon(
                  key: const Key('nutrition-recognize'),
                  onPressed: _recognize,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(recognition == null ? '识别营养' : '重新识别'),
                ),
            ],
            if (recognition != null && recognition!.warnings.isNotEmpty) ...[
              const SizedBox(height: 7),
              _RecognitionWarning(warnings: recognition!.warnings),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: food,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                // Keep the established label for test/backward compatibility;
                // the helper clarifies that the field is optional and the
                // save path never requires a food name.
                labelText: '食物名称 *',
                helperText: '可选',
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amount,
                    decoration: const InputDecoration(labelText: '份量'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: calories,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '热量 kcal *',
                      helperText: '识别后可复核',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: protein,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '蛋白质 g'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: carbs,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '碳水 g'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: fat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '脂肪 g'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 9),
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 15),
            KeyedSubtree(
              key: const Key('nutrition-save-entry'),
              child: FilledButton.icon(
                key: const Key('nutrition-save'),
                onPressed: saving || recognizing ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('保存记录'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecognitionWarning extends StatelessWidget {
  const _RecognitionWarning({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: _primaryContainer(context).withValues(alpha: .45),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 17, color: _primary(context)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            warnings.join('；'),
            style: TextStyle(color: _muted(context), fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class UnifiedCalendarPage extends StatefulWidget {
  const UnifiedCalendarPage({
    super.key,
    required this.controller,
    this.initialDate,
  });

  final AppController controller;
  final DateTime? initialDate;

  @override
  State<UnifiedCalendarPage> createState() => _UnifiedCalendarPageState();
}

class _UnifiedCalendarPageState extends State<UnifiedCalendarPage> {
  late DateTime month;
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    final seed = _dayOnly(widget.initialDate ?? DateTime.now());
    month = DateTime(seed.year, seed.month);
    selected = seed;
  }

  void _changeMonth(int amount) {
    setState(() {
      month = DateTime(month.year, month.month + amount);
      final days = DateTime(month.year, month.month + 1, 0).day;
      selected = DateTime(month.year, month.month, selected.day.clamp(1, days));
    });
  }

  List<DateTime?> _monthCells() {
    final first = DateTime(month.year, month.month, 1);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    return [
      ...List<DateTime?>.filled(leading, null),
      for (var day = 1; day <= count; day++)
        DateTime(month.year, month.month, day),
    ];
  }

  bool _hasWorkout(DateTime date) =>
      widget.controller.history.any((record) => _sameDay(record.date, date));

  bool _hasNutrition(DateTime date) =>
      widget.controller.nutritionForDay(date).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cells = _monthCells();
    return Scaffold(
      key: const Key('unified-calendar-page'),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined),
            SizedBox(width: 8),
            Text('训练与饮食'),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            tooltip: '上个月',
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '${month.year}年${month.month}月',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            tooltip: '下个月',
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          for (final label in const [
                            '一',
                            '二',
                            '三',
                            '四',
                            '五',
                            '六',
                            '日',
                          ])
                            Expanded(
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      GridView.builder(
                        key: const Key('unified-calendar-grid'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cells.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: 54,
                            ),
                        itemBuilder: (context, index) {
                          final date = cells[index];
                          if (date == null) return const SizedBox.shrink();
                          final workout = _hasWorkout(date);
                          final nutrition = _hasNutrition(date);
                          final isSelected = _sameDay(date, selected);
                          return InkWell(
                            key: Key(
                              'unified-calendar-day-${date.year}-${date.month}-${date.day}',
                            ),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => selected = date),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryContainer(context)
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: _primary(context))
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (workout)
                                        _CalendarDot(color: _primary(context)),
                                      if (workout && nutrition)
                                        const SizedBox(width: 3),
                                      if (nutrition)
                                        _CalendarDot(
                                          color: _primary(
                                            context,
                                          ).withValues(alpha: .5),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: _primary(context), label: '训练'),
                          const SizedBox(width: 16),
                          _LegendDot(
                            color: _primary(context).withValues(alpha: .5),
                            label: '饮食',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _UnifiedDayTimeline(
                controller: widget.controller,
                date: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDot extends StatelessWidget {
  const _CalendarDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _CalendarDot(color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: _muted(context), fontSize: 11)),
    ],
  );
}

class _UnifiedDayTimeline extends StatelessWidget {
  const _UnifiedDayTimeline({required this.controller, required this.date});
  final AppController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final workoutItems = controller.history
        .where((record) => _sameDay(record.date, date))
        .map(
          (record) => _TimelineItem(
            time: record.date,
            icon: Icons.fitness_center_rounded,
            title: record.name,
            detail:
                '${record.effectiveSets} 组 · ${record.volume.toStringAsFixed(0)} kg',
            tint: _primary(context),
          ),
        )
        .toList();
    final mealItems = controller
        .nutritionForDay(date)
        .map(
          (entry) => _TimelineItem(
            time: entry.recordedAt,
            icon: Icons.restaurant_rounded,
            title: entry.foodName.trim().isEmpty
                ? entry.mealType
                : entry.foodName,
            detail:
                '${entry.calories.toStringAsFixed(0)} kcal · 蛋白质 ${entry.proteinGrams.toStringAsFixed(0)} g',
            tint: _primary(context).withValues(alpha: .58),
          ),
        )
        .toList();
    final items = [...workoutItems, ...mealItems]
      ..sort((a, b) => a.time.compareTo(b.time));
    return Card(
      key: const Key('unified-day-timeline'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateText(date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text('当天没有训练或饮食记录', style: TextStyle(color: _muted(context)))
            else
              for (final item in items) _TimelineRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.time,
    required this.icon,
    required this.title,
    required this.detail,
    required this.tint,
  });
  final DateTime time;
  final IconData icon;
  final String title;
  final String detail;
  final Color tint;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});
  final _TimelineItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 45,
          child: Text(
            '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: _muted(context), fontSize: 11),
          ),
        ),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: item.tint.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, size: 16, color: item.tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                item.detail,
                style: TextStyle(color: _muted(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GuidePage extends StatefulWidget {
  const GuidePage({super.key, required this.controller});
  final AppController controller;

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final expanded = <int>{0};

  List<_GuideChapter> get chapters => [
    const _GuideChapter(
      title: '快速开始',
      icon: Icons.rocket_launch_outlined,
      image: 'assets/branding/xingyu-mark.png',
      steps: ['登录后完善训练目标', '从计划或自由训练开始', '完成一组后记录真实重量和次数'],
    ),
    _GuideChapter(
      title: '创建与执行计划',
      icon: Icons.view_list_outlined,
      image:
          mediaForExercise('barbell_squat')?.imagePath ??
          'assets/branding/xingyu-mark.png',
      steps: ['选择动作并调整组数', '训练中逐组完成并设置休息', '结束后查看总结并选择是否发布'],
    ),
    _GuideChapter(
      title: '训练记录与日历',
      icon: Icons.calendar_month_outlined,
      image:
          mediaForExercise('bench_press')?.imagePath ??
          'assets/branding/xingyu-mark.png',
      steps: ['在记录中按日期回看训练', '日历同时显示训练和饮食', '点击当天查看时间轴'],
    ),
    const _GuideChapter(
      title: '饮食拍照与复核',
      icon: Icons.camera_alt_outlined,
      image: 'assets/branding/xingyu-app-icon.png',
      steps: ['一次选择多张食物照片', '等待服务生成营养候选', '保存前确认估算值和不确定提示'],
    ),
    const _GuideChapter(
      title: '好友动态与隐私',
      icon: Icons.people_outline,
      image: 'assets/branding/xingyu-mark.png',
      steps: ['训练完成后主动发布快照', '好友可点赞或发送表情', '未发布的训练和备注保持私密'],
    ),
    const _GuideChapter(
      title: 'AI 与账号设置',
      icon: Icons.auto_awesome_outlined,
      image: 'assets/branding/xingyu-mark.png',
      steps: ['在 AI 页开启训练摘要授权', '需要时随时撤销授权', '账号、会员和深色模式在我的页面管理'],
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('guide-page'),
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined),
          SizedBox(width: 8),
          Text('使用指南'),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Card(
            color: _primaryContainer(context).withValues(alpha: .42),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Image.asset('assets/branding/xingyu-mark.png'),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '认识形域',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text('打开章节，边看边用。', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < chapters.length; index++)
            _GuideChapterTile(
              index: index,
              chapter: chapters[index],
              expanded: expanded.contains(index),
              onTap: () => setState(
                () => expanded.contains(index)
                    ? expanded.remove(index)
                    : expanded.add(index),
              ),
            ),
        ],
      ),
    ),
  );
}

class _GuideChapter {
  const _GuideChapter({
    required this.title,
    required this.icon,
    required this.image,
    required this.steps,
  });
  final String title;
  final IconData icon;
  final String image;
  final List<String> steps;
}

class _GuideChapterTile extends StatelessWidget {
  const _GuideChapterTile({
    required this.index,
    required this.chapter,
    required this.expanded,
    required this.onTap,
  });
  final int index;
  final _GuideChapter chapter;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('guide-chapter-$index'),
    margin: const EdgeInsets.only(bottom: 10),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      chapter.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: _primaryContainer(context),
                        child: Icon(chapter.icon, color: _primary(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    chapter.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 18, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var stepIndex = 0;
                  stepIndex < chapter.steps.length;
                  stepIndex++
                )
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _primaryContainer(context),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              color: _primary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            chapter.steps[stepIndex],
                            style: const TextStyle(height: 1.4),
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
  );
}

class PublishWorkoutSheet extends StatefulWidget {
  const PublishWorkoutSheet({
    super.key,
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  @override
  State<PublishWorkoutSheet> createState() => _PublishWorkoutSheetState();
}

class _PublishWorkoutSheetState extends State<PublishWorkoutSheet> {
  late final TextEditingController caption;
  bool publishing = false;
  String? error;
  String cardStyle = 'coral';
  String cardImageKey = 'brand';
  String? localPhotoPath;
  String? localPhotoName;

  @override
  void initState() {
    super.initState();
    caption = TextEditingController();
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null || file.path!.isEmpty) return;
    setState(() {
      localPhotoPath = file.path;
      localPhotoName = file.name;
    });
  }

  Future<void> _publish() async {
    if (publishing) return;
    setState(() {
      publishing = true;
      error = null;
    });
    try {
      await widget.controller.publishWorkoutActivityRemote(
        widget.record,
        caption: caption.text,
        cardStyle: cardStyle,
        // A local photo cannot be addressed by another user's device. The
        // allow-listed image key keeps the dynamic cross-device safe; the
        // selected local file remains available for the system share card.
        cardImageKey: localPhotoPath == null ? cardImageKey : 'brand',
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(const SnackBar(content: Text('训练动态已发布或更新')));
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        publishing = false;
        error = caught is CoachApiException
            ? switch (caught.code) {
                'coach_unauthenticated' ||
                'coach_session_expired' => '登录状态已过期，请重新登录。',
                'workout_not_completed' => '训练尚未完成，暂时不能发布。',
                'invalid_workout_card_style' => '卡片主题无效，请重新选择。',
                _ => '发布失败：${caught.code}',
              }
            : '发布失败，请检查网络后重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: _primary(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '发布训练动态',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: _primaryContainer(context).withValues(alpha: .35),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.record.effectiveSets} 组 · ${widget.record.volume.toStringAsFixed(0)} kg · ${widget.record.durationSeconds ~/ 60} 分钟',
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '只会分享训练摘要，训练备注、身体资料和未发布记录不会公开。',
                      style: TextStyle(color: _muted(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _WorkoutActivityRecordPreview(
              controller: widget.controller,
              record: widget.record,
              style: cardStyle,
              localPhotoPath: localPhotoPath,
            ),
            const SizedBox(height: 10),
            const Text('卡片样式', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final style in workoutCardStyles)
                  ChoiceChip(
                    key: Key('publish-card-style-$style'),
                    label: Text(_shareStyleLabel(style)),
                    selected: cardStyle == style,
                    onSelected: (_) => setState(() => cardStyle = style),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                ChoiceChip(
                  key: const Key('publish-card-image-brand'),
                  label: const Text('品牌默认图'),
                  selected: localPhotoPath == null && cardImageKey == 'brand',
                  onSelected: (_) => setState(() {
                    localPhotoPath = null;
                    localPhotoName = null;
                    cardImageKey = 'brand';
                  }),
                ),
                ActionChip(
                  key: const Key('publish-card-image-picker'),
                  avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(localPhotoName ?? '选择照片'),
                  onPressed: _pickPhoto,
                ),
              ],
            ),
            if (localPhotoPath != null) ...[
              const SizedBox(height: 5),
              Text(
                '自选照片只用于本机分享；好友动态将使用默认图，保证跨设备可见。',
                style: TextStyle(color: _muted(context), fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const Key('publish-workout-caption'),
              controller: caption,
              maxLength: 80,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '说点什么（可选）'),
            ),
            if (error != null) ...[
              const SizedBox(height: 5),
              Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('publish-workout-confirm'),
              onPressed: publishing ? null : _publish,
              icon: publishing
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('发布给好友'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkoutActivityRecordPreview extends StatelessWidget {
  const _WorkoutActivityRecordPreview({
    required this.controller,
    required this.record,
    required this.style,
    this.localPhotoPath,
  });

  final AppController controller;
  final WorkoutRecord record;
  final String style;
  final String? localPhotoPath;

  @override
  Widget build(BuildContext context) {
    final total = record.exercises.fold<int>(
      0,
      (sum, item) => sum + item.sets.length,
    );
    final completed = record.exercises.fold<int>(
      0,
      (sum, item) => sum + item.sets.where((set) => set.completed).length,
    );
    return WorkoutResultCard(
      workoutName: record.name,
      date: record.date,
      durationSeconds: record.durationSeconds,
      volume: record.volume,
      effectiveSets: record.effectiveSets,
      completionPercent: total == 0 ? 0 : (completed / total * 100).round(),
      exerciseNames: [
        for (final item in record.exercises)
          controller.displayExerciseName(
            controller.exerciseFor(item.exerciseId),
          ),
      ],
      cardStyle: style,
      localPhotoPath: localPhotoPath,
    );
  }
}

class _WorkoutActivityPostPreview extends StatelessWidget {
  const _WorkoutActivityPostPreview({required this.post, this.socialFooter});

  final WorkoutActivityPost post;
  final Widget? socialFooter;

  @override
  Widget build(BuildContext context) => WorkoutResultCard(
    workoutName: post.workoutName,
    date: post.completedAt,
    durationSeconds: post.durationSeconds,
    volume: post.volume,
    effectiveSets: post.effectiveSets,
    completionPercent: post.completionPercent,
    exerciseNames: [
      for (final exercise in post.exerciseSummary)
        '${exercise.name.isEmpty ? exercise.exerciseId : exercise.name} · ${exercise.sets} 组',
    ],
    cardStyle: post.cardStyle,
    socialFooter: socialFooter,
  );
}

class WorkoutActivityCard extends StatefulWidget {
  const WorkoutActivityCard({
    super.key,
    required this.controller,
    required this.post,
    required this.onChanged,
  });

  final AppController controller;
  final WorkoutActivityPost post;
  final Future<void> Function() onChanged;

  @override
  State<WorkoutActivityCard> createState() => _WorkoutActivityCardState();
}

class _WorkoutActivityCardState extends State<WorkoutActivityCard> {
  bool busy = false;
  String? error;

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    if (_sameDay(value, now)) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return _dateText(value);
  }

  Future<void> _like() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.toggleFriendWorkoutLikeRemote(widget.post.id);
      await widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => error = '点赞失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _emoji(String emoji) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.controller.commentOnFriendWorkoutRemote(
        widget.post.id,
        emoji,
      );
      await widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => error = '表情发送失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除动态？'),
        content: const Text('删除后好友将无法继续看到这条训练动态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || busy) return;
    setState(() => busy = true);
    try {
      await widget.controller.deleteFriendWorkoutRemote(widget.post.id);
      await widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => error = '删除失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _socialFooter(
    BuildContext context,
    WorkoutActivityPost post,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (post.caption.trim().isNotEmpty) ...[
        Text(
          post.caption.trim(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (post.emojiCounts.isNotEmpty) ...[
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final entry in post.emojiCounts.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${entry.key} ${entry.value}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
      ],
      Row(
        children: [
          OutlinedButton.icon(
            key: Key('workout-activity-like-${post.id}'),
            onPressed: busy ? null : _like,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: const BorderSide(color: Color(0xFF55585E)),
            ),
            icon: Icon(
              post.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 18,
            ),
            label: Text('${post.likeCount}'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            key: Key('workout-activity-emoji-${post.id}'),
            enabled: !busy,
            onSelected: _emoji,
            tooltip: '快捷互动',
            itemBuilder: (_) => [
              for (final emoji in const ['👍', '🔥', '👏', '💪', '❤️', '🎉'])
                PopupMenuItem<String>(
                  value: emoji,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
            ],
            child: OutlinedButton.icon(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface,
                side: const BorderSide(color: Color(0xFF55585E)),
              ),
              icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
              label: const Text('快捷互动'),
            ),
          ),
          if (error != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Card(
      key: Key('workout-activity-${post.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _primaryContainer(context),
                  foregroundColor: _primary(context),
                  child: Text(
                    post.ownerName.trim().isEmpty
                        ? '友'
                        : post.ownerName.trim().characters.first,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeAccountName(post.ownerName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _timeLabel(post.completedAt),
                        style: TextStyle(color: _muted(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (post.ownerId == widget.controller.currentUser?.id)
                  IconButton(
                    tooltip: '删除动态',
                    onPressed: busy ? null : _delete,
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            _WorkoutActivityPostPreview(
              post: post,
              socialFooter: _socialFooter(context, post),
            ),
          ],
        ),
      ),
    );
  }
}
