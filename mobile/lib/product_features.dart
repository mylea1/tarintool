import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ai_api.dart';
import 'controller.dart';
import 'exercise_media.dart';
import 'membership_ui.dart';
import 'models.dart';

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _dateText(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';

Color _primary(BuildContext context) => Theme.of(context).colorScheme.primary;

Color _primaryContainer(BuildContext context) =>
    Theme.of(context).colorScheme.primaryContainer;

Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

Color _onSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color _muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);

class NutritionCenterPage extends StatefulWidget {
  const NutritionCenterPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<NutritionCenterPage> createState() => _NutritionCenterPageState();
}

class _NutritionCenterPageState extends State<NutritionCenterPage> {
  late DateTime selectedDate;

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
      showDragHandle: true,
      builder: (_) => _NutritionCaptureSheet(
        controller: widget.controller,
        selectedDate: selectedDate,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('nutrition-center-page'),
    appBar: AppBar(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu_rounded),
          SizedBox(width: 8),
          Text('饮食'),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('nutrition-open-calendar'),
          tooltip: '训练与饮食日历',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  UnifiedCalendarPage(controller: widget.controller),
            ),
          ),
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => ListView(
          key: const Key('nutrition-center-list'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            _NutritionDateNavigator(
              selectedDate: selectedDate,
              onSelected: (date) => setState(() => selectedDate = date),
              onPrevious: () => _shiftDate(-7),
              onNext: () => _shiftDate(7),
              onPick: _pickDate,
            ),
            const SizedBox(height: 12),
            _NutritionDaySummary(
              controller: widget.controller,
              date: selectedDate,
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
            const SizedBox(height: 16),
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
      ),
    ),
    floatingActionButton: FloatingActionButton(
      key: const Key('nutrition-floating-add'),
      onPressed: _showCapture,
      tooltip: '记录饮食',
      child: const Icon(Icons.camera_alt_outlined),
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
    final calories = entries.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final protein = entries.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final carbs = entries.fold<double>(0, (sum, item) => sum + item.carbsGrams);
    final fat = entries.fold<double>(0, (sum, item) => sum + item.fatGrams);
    final target = _sameDay(date, DateTime.now())
        ? controller.estimatedDailyCalories
        : null;
    return Card(
      key: const Key('nutrition-day-summary'),
      color: _primaryContainer(context).withValues(alpha: .38),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${calories.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Text(
                  '${entries.length} 次记录',
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
            if (target != null) ...[
              const SizedBox(height: 3),
              Text(
                '目标约 ${target.toStringAsFixed(0)} kcal',
                style: TextStyle(color: _muted(context), fontSize: 12),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: _MacroMetric(
                    label: '蛋白质',
                    value: protein,
                    color: _primary(context),
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    label: '碳水',
                    value: carbs,
                    color: _primary(context).withValues(alpha: .72),
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    label: '脂肪',
                    value: fat,
                    color: _primary(context).withValues(alpha: .52),
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

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: _muted(context), fontSize: 11)),
            Text(
              '${value.toStringAsFixed(0)} g',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ],
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
                key: const Key('nutrition-empty-add'),
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

  @override
  Widget build(BuildContext context) {
    final title = entry.foodName.trim().isEmpty
        ? '未命名餐次'
        : entry.foodName.trim();
    final details = <String>[
      '${entry.calories.toStringAsFixed(0)} kcal',
      if (entry.proteinGrams > 0)
        '蛋白质 ${entry.proteinGrams.toStringAsFixed(0)} g',
      if (entry.amount.trim().isNotEmpty) entry.amount.trim(),
    ];
    return Card(
      key: Key('nutrition-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 9),
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
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: _primary(context),
                  fontWeight: FontWeight.w900,
                ),
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
                        style: TextStyle(color: _muted(context), fontSize: 12),
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
  });

  final AppController controller;
  final DateTime selectedDate;

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
          mealType: widget.controller.nextMealLabelFor(widget.selectedDate),
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
      steps: ['在 AI 页开启训练摘要授权', '需要时随时撤销授权', '账号、会员和主题在我的页面管理'],
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

class ThemeChoicePage extends StatelessWidget {
  const ThemeChoicePage({super.key, required this.controller});
  final AppController controller;

  String _label(KiloThemeChoice choice) => switch (choice) {
    KiloThemeChoice.warm => '暖橙',
    KiloThemeChoice.glacier => '冰川蓝',
    KiloThemeChoice.forest => '森氧绿',
    KiloThemeChoice.titanium => '钛银红',
  };

  String _caption(KiloThemeChoice choice) => switch (choice) {
    KiloThemeChoice.warm => '现有配色兼容模式',
    KiloThemeChoice.glacier => '清透、冷静、适合高频记录',
    KiloThemeChoice.forest => '柔和、自然、低刺激',
    KiloThemeChoice.titanium => '中性银灰配竞速红',
  };

  Color _swatch(KiloThemeChoice choice) => switch (choice) {
    KiloThemeChoice.warm => const Color(0xFFD95718),
    KiloThemeChoice.glacier => const Color(0xFF2468C9),
    KiloThemeChoice.forest => const Color(0xFF21845A),
    KiloThemeChoice.titanium => const Color(0xFFC8463C),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('theme-choice-page'),
    appBar: AppBar(title: const Text('主题颜色')),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text('选择主题', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            '浅色背景保持一致，按钮、状态和图标会同步变化。',
            style: TextStyle(color: _muted(context), fontSize: 12),
          ),
          const SizedBox(height: 14),
          RadioGroup<KiloThemeChoice>(
            groupValue: controller.themeChoice,
            onChanged: (value) {
              if (value != null) {
                unawaited(controller.setThemeChoice(value));
              }
            },
            child: Column(
              children: [
                for (final choice in const [
                  KiloThemeChoice.glacier,
                  KiloThemeChoice.forest,
                  KiloThemeChoice.titanium,
                  KiloThemeChoice.warm,
                ])
                  Card(
                    key: Key('theme-choice-${choice.name}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => unawaited(controller.setThemeChoice(choice)),
                      leading: Radio<KiloThemeChoice>(value: choice),
                      title: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _swatch(choice),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _label(choice),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      subtitle: Text(_caption(choice)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(const SnackBar(content: Text('训练动态已发布')));
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        publishing = false;
        error =
            caught is CoachApiException &&
                (caught.code == 'coach_unauthenticated' ||
                    caught.code == 'coach_session_expired')
            ? '登录状态已过期，请重新登录。'
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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final minutes = post.durationSeconds ~/ 60;
    final seconds = post.durationSeconds % 60;
    final duration = minutes == 0 ? '$seconds 秒' : '$minutes 分钟';
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
                        post.ownerName,
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
            Text(
              post.workoutName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _ActivityMetric(icon: Icons.timer_outlined, value: duration),
                _ActivityMetric(
                  icon: Icons.fitness_center_outlined,
                  value: '${post.volume.toStringAsFixed(0)} kg',
                ),
                _ActivityMetric(
                  icon: Icons.task_alt_outlined,
                  value: '${post.effectiveSets} 组',
                ),
                _ActivityMetric(
                  icon: Icons.percent_outlined,
                  value: '${post.completionPercent}%',
                ),
              ],
            ),
            if (post.exerciseSummary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final exercise in post.exerciseSummary.take(5))
                    Chip(
                      avatar: Icon(
                        Icons.circle,
                        size: 7,
                        color: _primary(context),
                      ),
                      label: Text(
                        exercise.name.isEmpty
                            ? exercise.exerciseId
                            : exercise.name,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (post.caption.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(post.caption.trim(), style: const TextStyle(height: 1.35)),
            ],
            if (post.emojiCounts.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 5,
                children: [
                  for (final entry in post.emojiCounts.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryContainer(
                          context,
                        ).withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.key} ${entry.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  key: Key('workout-activity-like-${post.id}'),
                  onPressed: busy ? null : _like,
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
                  tooltip: '表情评论',
                  itemBuilder: (_) => [
                    for (final emoji in const [
                      '👍',
                      '🔥',
                      '👏',
                      '💪',
                      '❤️',
                      '🎉',
                    ])
                      PopupMenuItem<String>(
                        value: emoji,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                  ],
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                    label: const Text('表情'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: _primaryContainer(context).withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _primary(context)),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
