import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'recognition_api.dart';

const paper = Color(0xFFF3F6F8);
const ink = Color(0xFF10212B);
const secondaryInk = Color(0xFF405565);
const quiet = Color(0xFF708494);
const cobalt = Color(0xFF0B66D4);
const lime = Color(0xFFB7E34A);
const orange = Color(0xFFE47B32);
const hairline = Color(0xFFD5E0E7);

void main() => runApp(const KiloApp());

class KiloApp extends StatefulWidget {
  const KiloApp({super.key});
  @override
  State<KiloApp> createState() => _KiloAppState();
}

// Kept as a compatibility alias for the generated Flutter smoke test.
typedef MyApp = KiloApp;

class _KiloAppState extends State<KiloApp> {
  late final AppController controller;
  @override
  void initState() {
    super.initState();
    controller = AppController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KILO Strength',
      theme: _theme,
      home: KiloShell(controller: controller),
    ),
  );
}

final _theme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: cobalt,
    brightness: Brightness.light,
  ).copyWith(primary: cobalt, surface: Colors.white, onSurface: ink),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: secondaryInk, height: 1.35),
    bodyMedium: TextStyle(fontSize: 14, color: secondaryInk, height: 1.35),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(borderSide: BorderSide(color: hairline)),
    filled: true,
    fillColor: Colors.white,
  ),
  cardTheme: const CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: hairline),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Color(0xFFE4EFFB),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
    ),
    height: 68,
  ),
);

class KiloShell extends StatelessWidget {
  const KiloShell({super.key, required this.controller});
  final AppController controller;

  static const pages = <PageId>[
    PageId.today,
    PageId.train,
    PageId.exercises,
    PageId.ai,
    PageId.profile,
  ];
  static const labels = ['主页', '训练', '动作', 'AI', '我的'];
  static const icons = [
    Icons.home_outlined,
    Icons.fitness_center_outlined,
    Icons.menu_book_outlined,
    Icons.forum_outlined,
    Icons.person_outline,
  ];

  int get navIndex => switch (controller.page) {
    PageId.today => 0,
    PageId.train || PageId.records => 1,
    PageId.exercises => 2,
    PageId.ai || PageId.recognition => 3,
    PageId.profile => 4,
  };
  String get pageTitle => switch (controller.page) {
    PageId.today => '主页',
    PageId.train => '训练',
    PageId.records => '记录',
    PageId.exercises => '动作库',
    PageId.recognition => '动作识别',
    PageId.ai => '知识库 AI',
    PageId.profile => '我的',
  };
  String get pageSubtitle => switch (controller.page) {
    PageId.today => '训练、记录和计划概览',
    PageId.train => controller.workoutStarted ? '保持专注，完成下一组' : '选择计划并开始训练',
    PageId.records => '训练日历、完成情况和历史记录',
    PageId.exercises => '动作、机位与识别能力',
    PageId.recognition => '上传视频并查看可解释报告',
    PageId.ai => '有来源的训练问答',
    PageId.profile => '训练偏好、设备连接和隐私设置',
  };

  @override
  Widget build(BuildContext context) {
    final body = switch (controller.page) {
      PageId.today => HomePage(controller: controller),
      PageId.train => TrainPage(controller: controller),
      PageId.records => TrainPage(controller: controller),
      PageId.exercises => ExerciseLibraryPage(controller: controller),
      PageId.recognition => RecognitionPage(controller: controller),
      PageId.ai => AiPage(controller: controller),
      PageId.profile => ProfilePage(controller: controller),
    };
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          78 * MediaQuery.textScalerOf(context).scale(1),
        ),
        child: SafeArea(
          child: _TopBar(
            controller: controller,
            title: pageTitle,
            subtitle: pageSubtitle,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ParticlePainter(
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                ),
              ),
            ),
            body,
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) => controller.selectPage(pages[index]),
        destinations: [
          for (var i = 0; i < pages.length; i++)
            NavigationDestination(
              icon: Icon(icons[i]),
              selectedIcon: Icon(icons[i], color: cobalt),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.title,
    required this.subtitle,
  });
  final AppController controller;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      decoration: const BoxDecoration(
        color: paper,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KILO',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: cobalt,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: quiet),
                ),
              ],
            ),
          ),
          if (controller.restRunning) _RestChip(controller: controller),
          if (controller.page == PageId.exercises)
            IconButton(
              tooltip: '新建自定义动作',
              onPressed: () => _showCustomExercise(context, controller),
              icon: const Icon(Icons.add),
            ),
          if (controller.page == PageId.ai &&
              controller.aiView == AiView.recognition)
            IconButton(
              tooltip: '选择视频',
              onPressed: controller.mediaPicking ? null : controller.pickVideo,
              icon: const Icon(Icons.video_camera_back_outlined),
            ),
          if (controller.page == PageId.profile)
            IconButton(
              tooltip: '重置演示数据',
              onPressed: () => _confirmReset(context, controller),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _RestChip extends StatelessWidget {
  const _RestChip({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final minutes = (controller.restRemainingSeconds ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (controller.restRemainingSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    return InkWell(
      onTap: () => _showRestSheet(context, controller),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: lime.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: ink),
            const SizedBox(width: 4),
            Text(
              '$minutes:$seconds',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 30),
  });
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: padding, children: children);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: quiet),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 19),
      label: Text(label, overflow: TextOverflow.ellipsis),
    ),
  );
}

void showKiloSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1800),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
    this.label, {
    this.color = cobalt,
    this.icon = Icons.circle,
  });
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({required this.exerciseId, this.size = 42});
  final String exerciseId;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: size,
      height: size,
      color: paper,
      child: Image.asset(
        exerciseAsset(exerciseId),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.fitness_center, color: cobalt),
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.scenario == 'empty') {
      return PageFrame(
        children: [
          const SizedBox(height: 90),
          const Icon(Icons.event_busy_outlined, size: 58, color: quiet),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '还没有安排训练',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '从训练页选择计划，或在计划页新建训练。',
              style: TextStyle(color: secondaryInk),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: '浏览训练计划',
                  icon: Icons.menu_book_outlined,
                  onPressed: () {
                    controller.selectPage(PageId.train);
                    controller.selectTrainView(TrainView.plans);
                    showKiloSnack(context, '请选择计划开始训练');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    controller.selectPage(PageId.train);
                    controller.selectTrainView(TrainView.plans);
                    showKiloSnack(context, '新建训练入口已移到计划页');
                  },
                  child: const Text('新建训练'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    final stats = controller.completion;
    return PageFrame(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '今天 18:30',
                        style: TextStyle(
                          fontSize: 12,
                          color: quiet,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const _StatusChip('本周 3 / 4', color: cobalt),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  controller.workoutStarted ? '继续上肢力量 A' : '上肢力量 A',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text('杠铃卧推、胸托划船、侧平举 · 预计 56 分钟'),
                const SizedBox(height: 15),
                Row(
                  children: [
                    for (final item in controller.workout.take(3))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _showExerciseDetail(
                              context,
                              controller,
                              findExercise(item.exerciseId),
                            ),
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: paper,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                findExercise(item.exerciseId).name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (controller.workoutStarted) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: stats,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(7),
                    color: cobalt,
                    backgroundColor: hairline,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${controller.completedSets} / ${controller.totalSets} 组已完成',
                    style: const TextStyle(fontSize: 12, color: quiet),
                  ),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  key: controller.workoutStarted
                      ? const Key('home-continue')
                      : const Key('home-browse-plans'),
                  label: controller.workoutStarted ? '继续训练' : '浏览训练计划',
                  icon: controller.workoutStarted
                      ? Icons.play_arrow
                      : Icons.menu_book_outlined,
                  onPressed: () {
                    if (controller.workoutStarted) {
                      controller.openLiveWorkout();
                      showKiloSnack(context, '已返回实时训练');
                    } else {
                      controller.selectPage(PageId.train);
                      controller.selectTrainView(TrainView.plans);
                      showKiloSnack(context, '请选择计划开始训练');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          '训练周',
          subtitle: '点击日期查看或调整安排',
          action: '完整月历',
          onAction: () => controller.selectPage(PageId.records),
        ),
        _WeekStrip(controller: controller),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ProgressCard(controller: controller)),
            const SizedBox(width: 12),
            Expanded(child: _ReadinessCard(controller: controller)),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(
          '最近进步',
          subtitle: '只展示值得注意的变化',
          action: '全部趋势',
          onAction: () => _showProgress(context, controller),
        ),
        Card(
          child: Column(
            children: [
              _ProgressRow(
                icon: Icons.fitness_center,
                title: '杠铃卧推',
                detail: '80 kg × 8，重复次数纪录',
                value: '+1',
                onTap: () => _showProgress(context, controller),
              ),
              _ProgressRow(
                icon: Icons.trending_up,
                title: '胸托划船',
                detail: '近四周训练量持续上升',
                value: '+8.4%',
                onTap: () => _showProgress(context, controller),
              ),
              _ProgressRow(
                icon: Icons.document_scanner_outlined,
                title: '深蹲轨迹',
                detail: '最低点稳定性改善',
                value: '稳定',
                onTap: () => controller.selectAiView(AiView.recognition),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final dates = ['27', '28', '29', '30', '31', '01', '02'];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 78 * scale,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: i == 5 ? cobalt : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == 5 ? cobalt : hairline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: i == 5 ? Colors.white : quiet,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dates[i],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: i == 5 ? Colors.white : ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        i == 5
                            ? Icons.fitness_center
                            : i.isEven
                            ? Icons.check_circle
                            : Icons.remove,
                        size: 12,
                        color: i == 5
                            ? lime
                            : i.isEven
                            ? cobalt
                            : hairline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('长期目标仍在推进', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          const Text('引体向上重复次数', style: TextStyle(fontSize: 12, color: quiet)),
          const SizedBox(height: 16),
          SizedBox(
            height: 55,
            child: CustomPaint(painter: _SparklinePainter()),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Text(
                '+3 次',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
                ),
              ),
              SizedBox(width: 7),
              Text('过去 6 周', style: TextStyle(fontSize: 11, color: quiet)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cobalt
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, size.height * .82)
      ..cubicTo(
        size.width * .25,
        size.height * .56,
        size.width * .4,
        size.height * .73,
        size.width * .62,
        size.height * .38,
      )
      ..cubicTo(
        size.width * .75,
        size.height * .18,
        size.width * .88,
        size.height * .28,
        size.width,
        size.height * .08,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width, size.height * .08),
      4,
      Paint()..color = cobalt,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.reducedMotion});
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = cobalt.withValues(alpha: .045);
    final line = Paint()
      ..color = cobalt.withValues(alpha: .025)
      ..strokeWidth = 1;
    final points = <Offset>[
      Offset(size.width * .08, size.height * .16),
      Offset(size.width * .27, size.height * .10),
      Offset(size.width * .43, size.height * .22),
      Offset(size.width * .68, size.height * .13),
      Offset(size.width * .90, size.height * .27),
      Offset(size.width * .18, size.height * .47),
      Offset(size.width * .50, size.height * .42),
      Offset(size.width * .78, size.height * .54),
      Offset(size.width * .92, size.height * .72),
    ];
    for (final point in points) {
      canvas.drawCircle(point, reducedMotion ? 2.2 : 2.8, dot);
    }
    if (reducedMotion) return;
    for (var index = 0; index < points.length - 1; index++) {
      canvas.drawLine(points[index], points[index + 1], line);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.reducedMotion != reducedMotion;
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今天的训练条件', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          const Row(
            children: [
              Text(
                '良好',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.check_circle, size: 16, color: cobalt),
            ],
          ),
          const Text('无需降低计划重量', style: TextStyle(fontSize: 11, color: quiet)),
          const SizedBox(height: 11),
          const Text('计划完成率 91%', style: TextStyle(fontSize: 12)),
          const Text('最近训练 2 天前', style: TextStyle(fontSize: 12)),
          const Text('连续训练 7 周', style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: cobalt),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: quiet),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, color: cobalt),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: quiet),
        ],
      ),
    ),
  );
}

class TrainPage extends StatelessWidget {
  const TrainPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.liveWorkoutVisible) {
      return PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) controller.closeLiveWorkout();
        },
        child: PageFrame(
          children: [
            _LiveWorkoutHeader(controller: controller),
            const SizedBox(height: 12),
            _WorkoutView(controller: controller),
          ],
        ),
      );
    }
    final showingHistory = controller.trainView == TrainView.history;
    return Column(
      children: [
        _TrainTopTabs(controller: controller),
        Expanded(
          child: showingHistory
              ? RecordsPage(controller: controller, embedded: true)
              : PageFrame(
                  children: [
                    SectionTitle('我的训练计划', subtitle: '选择一节训练后进入独立实时记录界面'),
                    _PlansView(controller: controller),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TrainTopTabs extends StatelessWidget {
  const _TrainTopTabs({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.trainView == TrainView.history
        ? TrainView.history
        : TrainView.plans;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<TrainView>(
        key: const Key('train-top-tabs'),
        segments: const [
          ButtonSegment(value: TrainView.plans, label: Text('计划')),
          ButtonSegment(value: TrainView.history, label: Text('记录')),
        ],
        selected: {selected},
        onSelectionChanged: (value) => controller.selectTrainView(value.first),
      ),
    );
  }
}

class _LiveWorkoutHeader extends StatelessWidget {
  const _LiveWorkoutHeader({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final elapsed = controller.currentElapsed;
    final clock =
        '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
    return Card(
      key: const Key('live-workout'),
      color: const Color(0xFFEAF3FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回计划',
              onPressed: controller.closeLiveWorkout,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.workoutName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    controller.workoutPaused
                        ? '已暂停'
                        : '实时训练 · ${controller.completedSets}/${controller.totalSets} 组',
                    style: const TextStyle(fontSize: 12, color: secondaryInk),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  clock,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  controller.workoutPaused ? '暂停' : '进行中',
                  style: TextStyle(
                    fontSize: 11,
                    color: controller.workoutPaused ? orange : cobalt,
                    fontWeight: FontWeight.w700,
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

class _WorkoutView extends StatelessWidget {
  const _WorkoutView({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.workoutCompleted && !controller.workoutStarted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: cobalt, size: 48),
              const SizedBox(height: 10),
              Text('训练已保存', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '${controller.history.first.name} · ${controller.history.first.effectiveSets} 个有效组',
                style: const TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: '开始下一次训练',
                onPressed: () => controller.startWorkout(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.workoutName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            controller.workoutStarted
                                ? '已完成 ${controller.completedSets}/${controller.totalSets} 组'
                                : '先检查动作，再开始计时',
                            style: const TextStyle(color: quiet),
                          ),
                        ],
                      ),
                    ),
                    if (controller.workoutStarted)
                      _StatusChip(
                        controller.workoutPaused ? '已暂停' : '进行中',
                        color: controller.workoutPaused ? orange : cobalt,
                        icon: controller.workoutPaused
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                if (controller.workoutStarted)
                  LinearProgressIndicator(
                    value: controller.completion,
                    color: cobalt,
                    backgroundColor: hairline,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.toggleBatchMode,
                      icon: Icon(
                        controller.batchMode
                            ? Icons.check_circle
                            : Icons.checklist,
                      ),
                      label: Text(controller.batchMode ? '退出批量' : '批量修改'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPlateCalculator(context),
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('杠片计算器'),
                    ),
                  ],
                ),
                if (controller.batchMode &&
                    controller.selectedSetIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () => _showBatchEditor(context, controller),
                      icon: const Icon(Icons.tune),
                      label: Text('编辑已选 ${controller.selectedSetIds.length} 组'),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: controller.workoutStarted
                            ? (controller.workoutPaused ? '恢复计时' : '暂停计时')
                            : '开始训练',
                        icon: controller.workoutStarted
                            ? (controller.workoutPaused
                                  ? Icons.play_arrow
                                  : Icons.pause)
                            : Icons.play_arrow,
                        onPressed: controller.workoutStarted
                            ? controller.pauseWorkout
                            : () => controller.startWorkout(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '训练设置',
                      onPressed: () =>
                          _showWorkoutSettings(context, controller),
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (controller.restRunning) _RestBanner(controller: controller),
        if (controller.restRunning) const SizedBox(height: 12),
        if (controller.workout.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.playlist_add, size: 44, color: quiet),
                  const SizedBox(height: 8),
                  const Text(
                    '新建训练还没有动作',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('添加动作后才会启动组计时器。', style: TextStyle(color: quiet)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showExercisePicker(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('添加动作'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final exercise in controller.workout)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkoutExerciseCard(
                controller: controller,
                exercise: exercise,
              ),
            ),
        ],
        if (controller.workoutStarted) ...[
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showFinishWorkout(context, controller),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text('结束并保存 · ${controller.currentElapsed ~/ 60} 分钟'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.restRemainingSeconds;
    final clock =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final exerciseName = controller.restExerciseName ?? '当前动作';
    return Card(
      color: const Color(0xFFEAF3FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: cobalt),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '组间休息',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    exerciseName,
                    style: const TextStyle(fontSize: 12, color: secondaryInk),
                  ),
                ],
              ),
            ),
            Text(
              clock,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '增加 15 秒',
              onPressed: () {
                controller.addRestSeconds();
                showKiloSnack(context, '休息已增加 15 秒');
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
            IconButton(
              tooltip: '跳过休息',
              onPressed: () {
                controller.skipRest();
                showKiloSnack(context, '已跳过休息');
              },
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.controller,
    required this.exercise,
  });
  final AppController controller;
  final WorkoutExercise exercise;
  @override
  Widget build(BuildContext context) {
    final definition = findExercise(exercise.exerciseId);
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              exercise.collapsed = !exercise.collapsed;
              controller.refresh();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
              child: Row(
                children: [
                  _ExerciseThumb(exerciseId: exercise.exerciseId, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                definition.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (exercise.supersetId != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: _StatusChip(
                                  '超级组',
                                  color: orange,
                                  icon: Icons.link,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${definition.muscle} · 休息 ${exercise.restSeconds} 秒',
                          style: const TextStyle(fontSize: 11, color: quiet),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '动作菜单',
                    onPressed: () =>
                        _showExerciseActions(context, controller, exercise),
                    icon: const Icon(Icons.more_horiz),
                  ),
                  Icon(
                    exercise.collapsed ? Icons.expand_more : Icons.expand_less,
                    color: quiet,
                  ),
                ],
              ),
            ),
          ),
          if (!exercise.collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: controller.batchMode ? 42 : 22),
                      const Expanded(
                        child: Text(
                          '组别类型',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                      ),
                      const SizedBox(
                        width: 55,
                        child: Text(
                          '重量',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                      ),
                      const SizedBox(
                        width: 45,
                        child: Text(
                          '次数',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                      ),
                      if (controller.rpeTrackingEnabled)
                        const SizedBox(
                          width: 42,
                          child: Text(
                            'RPE',
                            style: TextStyle(fontSize: 11, color: quiet),
                          ),
                        ),
                      const SizedBox(
                        width: 42,
                        child: Text(
                          '完成',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                      ),
                    ],
                  ),
                  for (var i = 0; i < exercise.sets.length; i++)
                    _SetRow(
                      controller: controller,
                      exercise: exercise,
                      set: exercise.sets[i],
                      index: i,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => controller.addSet(exercise),
                      icon: const Icon(Icons.add, size: 17),
                      label: const Text('添加一组'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

IconData _setTypeIcon(String type) => switch (type) {
  'warmup' => Icons.whatshot_outlined,
  'work' => Icons.fitness_center,
  'backoff' => Icons.trending_down,
  'drop' => Icons.south,
  'technique' => Icons.tune,
  'failure' => Icons.warning_amber_outlined,
  _ => Icons.fitness_center_outlined,
};

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.controller,
    required this.exercise,
    required this.set,
    required this.index,
  });
  final AppController controller;
  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int index;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: Key('set-row-${set.id}'),
    duration: const Duration(milliseconds: 220),
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
    decoration: BoxDecoration(
      color: set.completed ? const Color(0xFFEFF8DE) : Colors.white,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(
        color: set.completed ? const Color(0xFFB7D873) : hairline,
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 42,
          child: controller.batchMode
              ? Checkbox(
                  value: controller.selectedSetIds.contains(set.id),
                  onChanged: set.completed
                      ? null
                      : (_) => controller.toggleSetSelection(set),
                  visualDensity: VisualDensity.compact,
                )
              : Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12, color: quiet),
                  ),
                ),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: set.type,
            isExpanded: true,
            isDense: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 7,
              ),
              prefixIcon: Icon(
                _setTypeIcon(set.type),
                color: Color(setTypeColors[set.type] ?? 0xFF708494),
                size: 18,
              ),
            ),
            items: [
              for (final entry in setTypeLabels.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(
                        _setTypeIcon(entry.key),
                        size: 16,
                        color: Color(setTypeColors[entry.key] ?? 0xFF708494),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: set.completed
                ? null
                : (value) {
                    if (value != null) {
                      set.type = value;
                      controller.refresh();
                    }
                  },
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 52,
          child: TextFormField(
            initialValue: set.weight == 0 ? '' : '${set.weight}',
            enabled: !set.completed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            ),
            onChanged: (value) {
              set.weight = double.tryParse(value) ?? set.weight;
            },
          ),
        ),
        const SizedBox(width: 5),
        SizedBox(
          width: 44,
          child: TextFormField(
            initialValue: '${set.reps}',
            enabled: !set.completed,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            ),
            onChanged: (value) {
              set.reps = int.tryParse(value) ?? set.reps;
            },
          ),
        ),
        if (controller.rpeTrackingEnabled)
          SizedBox(
            width: 42,
            child: TextFormField(
              initialValue: set.rpe?.toStringAsFixed(0) ?? '',
              enabled: !set.completed,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '—',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 7,
                ),
              ),
              onChanged: (value) {
                set.rpe = double.tryParse(value);
              },
            ),
          ),
        const SizedBox(width: 4),
        SizedBox(
          width: 42,
          child: Semantics(
            label: set.completed ? '第 ${index + 1} 组已完成' : '完成第 ${index + 1} 组',
            button: true,
            child: Checkbox(
              key: Key('set-complete-${set.id}'),
              value: set.completed,
              onChanged: controller.workoutStarted
                  ? (_) {
                      final wasCompleted = set.completed;
                      controller.completeSet(set, exercise);
                      showKiloSnack(
                        context,
                        wasCompleted
                            ? '已取消第 ${index + 1} 组'
                            : '已完成第 ${index + 1} 组',
                      );
                    }
                  : null,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PlansView extends StatelessWidget {
  const _PlansView({required this.controller});
  final AppController controller;
  static const plans = <Plan>[
    Plan(
      id: 'upper-lower-4',
      title: '上下肢力量',
      subtitle: '力量与增肌并重，围绕主项双重渐进',
      days: 4,
      weeks: 12,
      level: '中级',
      focus: '力量 + 增肌',
      sessions: [
        PlanSession(
          day: '周一',
          name: '上肢力量',
          exercises: 6,
          duration: '65 分钟',
          exerciseIds: ['bench_press', 'chest_supported_row', 'shoulder_press'],
        ),
        PlanSession(
          day: '周二',
          name: '下肢力量',
          exercises: 5,
          duration: '70 分钟',
          exerciseIds: ['barbell_squat', 'romanian_deadlift', 'leg_curl'],
        ),
        PlanSession(
          day: '周四',
          name: '上肢容量',
          exercises: 7,
          duration: '60 分钟',
          exerciseIds: ['dumbbell_press', 'lat_pulldown', 'lateral_raise'],
        ),
      ],
    ),
    Plan(
      id: 'ppl-6',
      title: '推拉腿进阶',
      subtitle: '高频分化，适合恢复能力较好的训练者',
      days: 6,
      weeks: 8,
      level: '中高级',
      focus: '肌肥大',
      sessions: [
        PlanSession(
          day: '周一',
          name: '推 A',
          exercises: 6,
          duration: '58 分钟',
          exerciseIds: ['bench_press', 'shoulder_press', 'triceps_extension'],
        ),
        PlanSession(
          day: '周二',
          name: '拉 A',
          exercises: 6,
          duration: '60 分钟',
          exerciseIds: ['pull_up', 'row', 'biceps_curl'],
        ),
      ],
    ),
    Plan(
      id: 'full-body-3',
      title: '全身三日',
      subtitle: '低频率限制下保持每周肌群刺激',
      days: 3,
      weeks: 10,
      level: '中级',
      focus: '均衡增肌',
      sessions: [
        PlanSession(
          day: '周一',
          name: '全身 A',
          exercises: 6,
          duration: '62 分钟',
          exerciseIds: ['barbell_squat', 'bench_press', 'row'],
        ),
        PlanSession(
          day: '周三',
          name: '全身 B',
          exercises: 6,
          duration: '60 分钟',
          exerciseIds: ['deadlift', 'shoulder_press', 'lat_pulldown'],
        ),
      ],
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '我的计划',
          subtitle: '${controller.routines.length} 个已保存训练',
          action: '新建计划',
          onAction: () => _showPlanBuilder(context, controller),
        ),
        if (controller.routines.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有保存的计划，先新建一个训练。'),
            ),
          ),
        for (final routine in controller.routines)
          _RoutineCard(controller: controller, routine: routine),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('official-plans-entry'),
          onPressed: () => _showOfficialPlans(context, controller),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('使用官方计划'),
        ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.controller, required this.routine});
  final AppController controller;
  final Routine routine;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 9),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.fitness_center, color: cobalt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  routine.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${routine.exercises.length} 个动作',
                style: const TextStyle(fontSize: 12, color: quiet),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  controller.startRoutine(routine);
                  showKiloSnack(context, '已开始 ${routine.name}');
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('开始'),
              ),
              OutlinedButton.icon(
                key: Key('routine-edit-${routine.id}'),
                onPressed: () =>
                    _showRoutineEditor(context, controller, routine),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
              TextButton(
                onPressed: () => _showRoutineMeta(context, controller, routine),
                child: const Text('重命名'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.controller, required this.plan});
  final AppController controller;
  final Plan plan;
  @override
  Widget build(BuildContext context) {
    final session = plan.sessions.first;
    return Card(
      key: Key('official-plan-${plan.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPlanDetail(context, controller, plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_outlined, color: cobalt),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.name} · ${session.exercises} 个动作 · ${session.duration}',
                      style: const TextStyle(fontSize: 12, color: quiet),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: quiet),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});
  final WorkoutRecord record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    key: Key('record-tile-${record.id}'),
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_available, color: cobalt),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${record.date.month} 月 ${record.date.day} 日 · ${record.effectiveSets} 有效组 · ${(record.durationSeconds / 60).round()} 分钟',
                    style: const TextStyle(fontSize: 12, color: quiet),
                  ),
                ],
              ),
            ),
            Text(
              '${record.volume.toStringAsFixed(0)} kg',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: cobalt,
              ),
            ),
            const Icon(Icons.chevron_right, color: quiet),
          ],
        ),
      ),
    ),
  );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.controller,
    this.embedded = false,
  });
  final AppController controller;
  final bool embedded;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime selected = DateTime(2026, 8, 3);
  AppController get controller => widget.controller;
  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(selected.year, selected.month, 1);
    final firstMonday = monthStart.subtract(
      Duration(days: monthStart.weekday - 1),
    );
    final cells = List.generate(
      42,
      (index) => firstMonday.add(Duration(days: index)),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final today = DateTime.now();
    final content = <Widget>[
      SectionTitle(
        '记录',
        subtitle: '训练日历、完成情况和历史记录',
        action: '补录训练',
        onAction: () => _showFinishWorkout(context, controller, past: true),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => selected = DateTime(
                        selected.year,
                        selected.month - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${selected.year} 年 ${selected.month} 月',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => selected = DateTime(
                        selected.year,
                        selected.month + 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('一', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('二', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('三', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('四', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('五', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('六', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('日', style: TextStyle(fontSize: 11, color: quiet)),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 50 * textScale,
                ),
                itemBuilder: (context, index) {
                  final day = cells[index];
                  final key =
                      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final completed = controller.history.any(
                    (record) =>
                        record.date.year == day.year &&
                        record.date.month == day.month &&
                        record.date.day == day.day,
                  );
                  final planned = controller.scheduled.contains(key);
                  final current =
                      day.year == selected.year &&
                      day.month == selected.month &&
                      day.day == selected.day;
                  final isToday =
                      day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;
                  final missed =
                      planned &&
                      !completed &&
                      DateTime(
                        day.year,
                        day.month,
                        day.day,
                      ).isBefore(DateTime(today.year, today.month, today.day));
                  final background = completed
                      ? const Color(0xFFDCEBFF)
                      : missed
                      ? const Color(0xFFFFE7D4)
                      : planned
                      ? const Color(0xFFEFF8DE)
                      : isToday
                      ? const Color(0xFFEAF3FF)
                      : Colors.transparent;
                  final border = current
                      ? cobalt
                      : completed
                      ? cobalt
                      : missed
                      ? orange
                      : planned
                      ? lime
                      : isToday
                      ? cobalt
                      : hairline;
                  final icon = completed
                      ? Icons.check_circle
                      : missed
                      ? Icons.event_busy
                      : planned
                      ? Icons.fitness_center
                      : isToday
                      ? Icons.today
                      : Icons.remove;
                  return InkWell(
                    key: Key('calendar-day-$key'),
                    onTap: () {
                      setState(() => selected = day);
                      _showCalendarDayActions(context, controller, day);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: border,
                          width: current || isToday ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              color: day.month == selected.month ? ink : quiet,
                              fontWeight: current || isToday
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Icon(icon, size: 14, color: border),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CalendarLegend(color: cobalt, label: '已完成'),
                  SizedBox(width: 12),
                  _CalendarLegend(color: orange, label: '已安排'),
                  SizedBox(width: 12),
                  _CalendarLegend(color: hairline, label: '未安排'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      SectionTitle(
        '最近训练',
        subtitle: '${controller.history.length} 次训练',
        action: controller.history.length > 3 ? '查看全部' : null,
        onAction: controller.history.length > 3
            ? () => _showAllHistory(context, controller)
            : null,
      ),
      if (controller.history.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('还没有训练记录，完成一次训练后会显示在这里。')),
          ),
        )
      else
        ...controller.history
            .take(3)
            .map(
              (record) => _RecordTile(
                record: record,
                onTap: () => _showRecordDetail(context, controller, record),
              ),
            ),
    ];
    return widget.embedded
        ? ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: content,
          )
        : PageFrame(children: content);
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: quiet)),
    ],
  );
}

class ExerciseLibraryPage extends StatelessWidget {
  const ExerciseLibraryPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    const groups = ['全部', '胸', '背', '肩', '腿', '手臂', '核心'];
    final resultWidgets = <Widget>[];
    if (controller.visibleExercises.isEmpty) {
      resultWidgets.add(
        const Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: Text('没有匹配动作，试试清空搜索或筛选。')),
          ),
        ),
      );
    } else {
      for (final exercise in controller.visibleExercises) {
        resultWidgets.add(
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              minVerticalPadding: 8,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
              leading: _ExerciseThumb(exerciseId: exercise.id, size: 42),
              title: Text(
                exercise.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${exercise.englishName} · ${exercise.muscle} · ${exercise.equipment}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showExerciseDetail(context, controller, exercise),
            ),
          ),
        );
      }
    }
    return PageFrame(
      children: [
        SectionTitle(
          '动作库',
          subtitle: '${controller.allExercises.length} 个动作 · 动作、机位与识别能力',
          action: '新建自定义动作',
          onAction: () => _showCustomExercise(context, controller),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: _MuscleRail(controller: controller, groups: groups),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('exercise-search'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索动作',
                    ),
                    onChanged: (value) {
                      controller.search = value;
                      controller.refresh();
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLibraryFilters(context, controller),
                      icon: const Icon(Icons.tune),
                      label: Text(
                        controller.equipmentFilter == '全部'
                            ? '器械筛选'
                            : controller.equipmentFilter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...resultWidgets,
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MuscleRail extends StatelessWidget {
  const _MuscleRail({required this.controller, required this.groups});
  final AppController controller;
  final List<String> groups;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('muscle-rail'),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: hairline),
    ),
    child: Column(
      children: [
        for (final group in groups)
          Material(
            color: controller.muscleFilter == group
                ? const Color(0xFFE4EFFB)
                : Colors.white,
            child: InkWell(
              onTap: () {
                controller.muscleFilter = group;
                controller.refresh();
                showKiloSnack(
                  context,
                  group == '全部' ? '显示全部动作' : '已筛选 $group 部位',
                );
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  group,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: controller.muscleFilter == group
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: controller.muscleFilter == group
                        ? cobalt
                        : secondaryInk,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class RecognitionPage extends StatelessWidget {
  const RecognitionPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PageFrame(
    children: [
      const SectionTitle('动作识别', subtitle: '上传视频并查看可解释报告'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.document_scanner_outlined,
                      color: cobalt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recognitionLabel(controller.recognitionStatus),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _recognitionDetail(controller),
                          style: const TextStyle(fontSize: 12, color: quiet),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: controller.recognitionExerciseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '动作'),
                items: [
                  for (final item in controller.allExercises)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.recognitionExerciseId = value;
                    controller.refresh();
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: controller.recognitionCamera,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '机位'),
                items: const [
                  DropdownMenuItem(
                    value: '侧前方 30-45°',
                    child: Text('侧前方 30-45°', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(value: '正侧面', child: Text('正侧面')),
                  DropdownMenuItem(value: '正面', child: Text('正面')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.recognitionCamera = value;
                    controller.refresh();
                  }
                },
              ),
              const SizedBox(height: 12),
              if (controller.recognitionStatus == RecognitionStatus.processing)
                LinearProgressIndicator(
                  value: controller.recognitionProgress,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(7),
                ),
              if (controller.recognitionResult != null &&
                  controller.recognitionStatus != RecognitionStatus.processing)
                _RecognitionReport(
                  result: controller.recognitionResult!,
                  controller: controller,
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: controller.mediaPicking
                          ? null
                          : controller.pickVideo,
                      icon: controller.mediaPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(controller.mediaPicking ? '正在选择…' : '选择视频'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label:
                          controller.recognitionStatus ==
                              RecognitionStatus.ready
                          ? '开始分析'
                          : '查看状态',
                      icon: Icons.analytics_outlined,
                      onPressed:
                          controller.recognitionStatus ==
                              RecognitionStatus.ready
                          ? controller.startRecognition
                          : null,
                    ),
                  ),
                ],
              ),
              if (controller.selectedMediaName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_file_outlined,
                        size: 17,
                        color: cobalt,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${controller.selectedMediaName} · ${_formatBytes(controller.selectedMediaBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: secondaryInk,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.resetRecognition,
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                ),
              if (controller.mediaError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          controller.mediaError!,
                          style: const TextStyle(fontSize: 12, color: orange),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.pickVideo,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: controller.mediaPicking
                      ? null
                      : controller.chooseDemoVideo,
                  icon: const Icon(Icons.play_circle_outline, size: 17),
                  label: const Text('使用演示视频'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.wifi_outlined, color: quiet),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '视频默认只保存在本地。识别服务由 BetterCoach API 边界提供，未授权时不会上传训练摘要。',
                  style: TextStyle(fontSize: 12, color: secondaryInk),
                ),
              ),
              Switch(
                value: controller.scenario != 'offline',
                onChanged: (value) {
                  controller.scenario = value ? 'normal' : 'offline';
                  controller.refresh();
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _RecognitionReport extends StatelessWidget {
  const _RecognitionReport({required this.result, required this.controller});
  final RecognitionResult result;
  final AppController controller;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 13),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: result.status == RecognitionStatus.complete
          ? const Color(0xFFEFF8DE)
          : paper,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              result.status == RecognitionStatus.complete
                  ? '分析完成'
                  : result.status == RecognitionStatus.lowConfidence
                  ? '低置信度'
                  : result.status == RecognitionStatus.offline
                  ? '离线'
                  : '识别错误',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (result.confidence > 0)
              Text(
                '${(result.confidence * 100).round()}%',
                style: const TextStyle(
                  color: cobalt,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(result.summary, style: const TextStyle(fontSize: 13)),
        if (result.repetitions > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '检测到 ${result.repetitions} 次重复 · ${findExercise(controller.recognitionExerciseId).name}',
              style: const TextStyle(fontSize: 12, color: secondaryInk),
            ),
          ),
        if (result.status == RecognitionStatus.complete ||
            result.status == RecognitionStatus.lowConfidence)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.saveRecognitionCue,
              icon: Icon(
                controller.savedCue ? Icons.bookmark : Icons.bookmark_border,
              ),
              label: Text(controller.savedCue ? '已保存提示' : '保存到下一组'),
            ),
          ),
      ],
    ),
  );
}

String _recognitionLabel(RecognitionStatus status) => switch (status) {
  RecognitionStatus.idle => '选择一个视频开始',
  RecognitionStatus.ready => '视频已就绪',
  RecognitionStatus.processing => '正在分析动作轨迹',
  RecognitionStatus.complete => '分析完成 · 置信度良好',
  RecognitionStatus.lowConfidence => '分析完成 · 置信度较低',
  RecognitionStatus.offline => '离线 · 已保留本地任务',
  RecognitionStatus.error => '识别失败 · 可以重试',
};
String _recognitionDetail(AppController controller) =>
    controller.recognitionStatus == RecognitionStatus.idle
    ? '选择动作和机位后载入演示视频。'
    : controller.recognitionStatus == RecognitionStatus.processing
    ? '逐帧提取姿态关键点，请保持应用打开。'
    : 'Mock API 已接入状态边界，可替换为 BetterCoach 服务。';
String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '大小未知';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AiPage extends StatefulWidget {
  const AiPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final input = TextEditingController();
  AppController get controller => widget.controller;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recognition = controller.aiView == AiView.recognition;
    return Scaffold(
      key: const Key('ai-page'),
      drawer: recognition ? null : _AiDrawer(controller: controller),
      body: SafeArea(
        child: Column(
          children: [
            _AiTopTabs(controller: controller),
            if (recognition)
              Expanded(child: RecognitionPage(controller: controller))
            else ...[
              Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 14, 6),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('ai-drawer'),
                        tooltip: '对话列表',
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        icon: const Icon(Icons.menu),
                      ),
                      const Expanded(
                        child: Text(
                          'AI 问答',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (controller.scenario == 'offline')
                        const _StatusChip(
                          '离线',
                          color: orange,
                          icon: Icons.cloud_off,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  children: [
                    if (controller.scenario == 'empty')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          '当前没有足够训练数据，回答会标记为无证据。',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      )
                    else if (controller.scenario == 'offline')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          '离线模式仅可读取已缓存对话，发送内容会在本地排队。',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      ),
                    for (final message in controller.chat)
                      _ChatBubble(
                        message: message,
                        onCitation: message.citations.isEmpty
                            ? null
                            : () => _showCitation(context, message.citations),
                      ),
                    if (controller.aiTyping)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 7),
                          child: Text(
                            'AI 正在整理证据…',
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '问训练、恢复或计划安排',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: '发送',
                        onPressed: controller.aiTyping
                            ? null
                            : () {
                                final text = input.text;
                                input.clear();
                                controller.sendChat(text);
                              },
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiTopTabs extends StatelessWidget {
  const _AiTopTabs({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: SegmentedButton<AiView>(
        key: const Key('ai-top-tabs'),
        segments: const [
          ButtonSegment(value: AiView.chat, label: Text('问答')),
          ButtonSegment(value: AiView.recognition, label: Text('动作识别')),
        ],
        selected: {controller.aiView},
        onSelectionChanged: (value) => controller.selectAiView(value.first),
      ),
    );
  }
}

class _AiDrawer extends StatelessWidget {
  const _AiDrawer({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI 对话',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('ai-new-conversation'),
                onPressed: () {
                  controller.newConversation();
                  Navigator.pop(context);
                  showKiloSnack(context, '已新建对话');
                },
                icon: const Icon(Icons.add),
                label: const Text('新建对话'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final conversation in controller.conversations)
                  ListTile(
                    selected:
                        conversation.id == controller.activeConversationId,
                    leading: Icon(
                      conversation.id == controller.activeConversationId
                          ? Icons.chat
                          : Icons.chat_bubble_outline,
                      color: conversation.id == controller.activeConversationId
                          ? cobalt
                          : quiet,
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      controller.selectConversation(conversation.id);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      tooltip: '删除对话',
                      onPressed: () =>
                          controller.deleteConversation(conversation.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('ai-settings'),
            leading: const Icon(Icons.tune, color: cobalt),
            title: const Text('服务与训练授权'),
            subtitle: const Text('URL、授权、场景'),
            onTap: () {
              Navigator.pop(context);
              _showAiSettings(context, controller);
            },
          ),
        ],
      ),
    ),
  );
}

void _showAiSettings(BuildContext context, AppController controller) {
  final url = TextEditingController(text: controller.aiBaseUrl);
  var useTrainingData = controller.aiUseTrainingData;
  var scenario = controller.scenario;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('AI 服务设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '默认使用 Mock；填写地址后会请求 /v1/coach/answer。仅保存地址，不保存任何 API key。',
                style: TextStyle(fontSize: 12, color: secondaryInk),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'http://127.0.0.1:8790',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Mock'),
                    onPressed: () => url.clear(),
                  ),
                  ActionChip(
                    label: const Text('本机服务'),
                    onPressed: () {
                      url.text = 'http://127.0.0.1:8790';
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: useTrainingData,
                onChanged: (value) => setState(() => useTrainingData = value),
                title: const Text('允许使用训练摘要'),
                subtitle: const Text('仅在授权后将训练记录作为上下文。'),
              ),
              DropdownButtonFormField<String>(
                initialValue: scenario,
                decoration: const InputDecoration(labelText: '演示场景'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('正常')),
                  DropdownMenuItem(value: 'offline', child: Text('离线')),
                  DropdownMenuItem(value: 'empty', child: Text('无数据')),
                  DropdownMenuItem(value: 'error', child: Text('错误')),
                  DropdownMenuItem(
                    value: 'low-confidence',
                    child: Text('低置信度'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => scenario = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              controller.aiBaseUrl = url.text.trim();
              controller.aiUseTrainingData = useTrainingData;
              controller.scenario = scenario;
              controller.refresh();
              Navigator.pop(context);
              showKiloSnack(context, 'AI 设置已保存');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.onCitation});
  final ChatMessage message;
  final VoidCallback? onCitation;
  @override
  Widget build(BuildContext context) => Align(
    alignment: message.role == 'user'
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: message.role == 'user' ? cobalt : paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.body,
            style: TextStyle(
              color: message.role == 'user' ? Colors.white : ink,
              height: 1.35,
            ),
          ),
          if (onCitation != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: TextButton.icon(
                onPressed: onCitation,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                icon: Icon(
                  Icons.format_quote,
                  size: 16,
                  color: message.role == 'user' ? Colors.white : cobalt,
                ),
                label: Text(
                  '查看 ${message.citations.length} 条引用',
                  style: TextStyle(
                    color: message.role == 'user' ? Colors.white : cobalt,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PageFrame(
    children: [
      const SectionTitle('我的', subtitle: '训练偏好、设备连接和隐私设置'),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.insights_outlined, color: cobalt),
              title: const Text('训练进步'),
              subtitle: const Text('肌群分布、周训练量与动作趋势'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showProgress(context, controller),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('默认休息时间'),
              subtitle: Text('${controller.defaultRestSeconds} 秒 · 训练页可随时修改'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWorkoutSettings(context, controller),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionTitle('设备与系统', subtitle: '平台能力只负责系统交互，训练状态仍由 Flutter 共享'),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              value: controller.androidNotifications,
              onChanged: (value) {
                controller.androidNotifications = value;
                controller.refresh();
              },
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Android 通知'),
              subtitle: const Text('休息结束和训练状态提醒'),
            ),
            SwitchListTile(
              value: controller.liveActivity,
              onChanged: (value) {
                controller.liveActivity = value;
                controller.refresh();
              },
              secondary: const Icon(Icons.lock_clock_outlined),
              title: const Text('锁屏实时活动'),
              subtitle: const Text('iOS Live Activity / Android 计时桥'),
            ),
            SwitchListTile(
              value: controller.appleWatch,
              onChanged: (value) {
                controller.appleWatch = value;
                controller.refresh();
              },
              secondary: const Icon(Icons.watch_outlined),
              title: const Text('Apple Watch'),
              subtitle: const Text('预留 WatchConnectivity 状态同步'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('隐私与 AI 授权'),
              subtitle: Text(
                controller.aiUseTrainingData ? '训练摘要已授权，可随时撤销' : '训练摘要默认不上传',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => controller.selectPage(PageId.ai),
            ),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('模拟场景'),
              subtitle: Text(
                controller.scenario == 'normal' ? '正常' : controller.scenario,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showScenario(context, controller),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('重置演示数据'),
              subtitle: const Text('恢复示例训练、识别和对话'),
              onTap: () => _confirmReset(context, controller),
            ),
          ],
        ),
      ),
    ],
  );
}

void _showRestSheet(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('休息 ${controller.restRemainingSeconds} 秒'),
            trailing: TextButton(
              onPressed: controller.skipRest,
              child: const Text('跳过'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showPlateCalculator(BuildContext context) {
  final weight = TextEditingController(text: '80');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final total = double.tryParse(weight.text) ?? 0;
        final perSide = ((total - 20) / 2).clamp(0, double.infinity);
        final plates = <double>[20, 10, 5, 2.5, 1.25];
        var remaining = perSide;
        final counts = <double, int>{};
        for (final plate in plates) {
          counts[plate] = (remaining / plate).floor();
          remaining -= counts[plate]! * plate;
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '杠片计算器',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '按 20 kg 杠铃计算每侧配置，结果仅作装片提示。',
                  style: TextStyle(color: quiet),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '目标总重量（kg）'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text(
                  '每侧约 ${perSide.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final plate in plates)
                      if ((counts[plate] ?? 0) > 0)
                        Chip(
                          label: Text(
                            '${counts[plate]} × ${plate.toStringAsFixed(2)} kg',
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showBatchEditor(BuildContext context, AppController controller) {
  String type = 'work';
  final weight = TextEditingController();
  final reps = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '批量修改 ${controller.selectedSetIds.length} 组',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '组别类型'),
                items: [
                  for (final entry in setTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    type = value;
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '重量（可选）'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: reps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '次数（可选）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: '应用修改',
                icon: Icons.check,
                onPressed: () {
                  controller.batchUpdate(
                    type: type,
                    weight: double.tryParse(weight.text),
                    reps: int.tryParse(reps.text),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showExerciseDetail(
  BuildContext context,
  AppController controller,
  Exercise exercise,
) {
  var scope = 'library';
  final note = TextEditingController(
    text: controller.resourceFor(exercise.id, scope).note,
  );
  final link = TextEditingController(
    text: controller.resourceFor(exercise.id, scope).link,
  );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(exercise.englishName, style: const TextStyle(color: quiet)),
              const SizedBox(height: 14),
              Text(
                '${exercise.muscle} · ${exercise.secondary} · ${exercise.equipment}',
              ),
              const SizedBox(height: 10),
              Text(exercise.cue),
              const SizedBox(height: 18),
              const Text(
                '备注与教学链接',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'library', label: Text('动作库')),
                  ButtonSegment(value: 'workout', label: Text('本次训练')),
                  ButtonSegment(value: 'plan', label: Text('计划')),
                ],
                selected: {scope},
                onSelectionChanged: (value) {
                  scope = value.first;
                  final resource = controller.resourceFor(exercise.id, scope);
                  note.text = resource.note;
                  link.text = resource.link;
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '动作备注',
                  hintText: '例如：保持胸口支撑，回程控制 2 秒',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: link,
                decoration: const InputDecoration(
                  labelText: '教学链接（可选）',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: '加入本次训练',
                      icon: Icons.add,
                      onPressed: () {
                        controller.addExercise(exercise.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        controller.saveResource(
                          exerciseId: exercise.id,
                          scope: scope,
                          note: note.text.trim(),
                          link: link.text.trim(),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('保存备注'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProgressTrendPainter extends CustomPainter {
  const _ProgressTrendPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = cobalt
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = cobalt.withValues(alpha: .10)
      ..style = PaintingStyle.fill;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < .01 ? 1 : maxValue - minValue;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          size.height -
          ((values[index] - minValue) / span).clamp(.08, .92) * size.height;
      points.add(Offset(x, y));
    }
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(line, linePaint);
    final dotPaint = Paint()..color = cobalt;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

void _showProgress(BuildContext context, AppController controller) {
  final records = controller.history.reversed.toList();
  final volumes = records.map((record) => record.volume).toList();
  final latest = controller.history.isEmpty ? null : controller.history.first;
  final firstVolume = volumes.isEmpty ? 0 : volumes.first;
  final latestVolume = volumes.isEmpty ? 0 : volumes.last;
  final changeRate = firstVolume == 0
      ? 0.0
      : (latestVolume - firstVolume) / firstVolume * 100;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('进步分析', style: Theme.of(context).textTheme.headlineMedium),
              const Text(
                '把最近训练的变化放在同一条线上，看懂下一步该加什么。',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 14),
              if (volumes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('还没有足够的训练数据。完成一次训练后，这里会显示趋势和动作表现。'),
                  ),
                )
              else ...[
                const Text(
                  '训练量趋势',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  key: const Key('progress-trend-chart'),
                  height: 170,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFFB8D4F2)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: CustomPaint(
                        painter: _ProgressTrendPainter(volumes),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${records.first.date.month}/${records.first.date.day} · ${records.first.volume.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 11, color: quiet),
                    ),
                    Text(
                      '${records.last.date.month}/${records.last.date.day} · ${records.last.volume.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 11, color: quiet),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    _ProgressMetric(
                      label: '最近训练量',
                      value: '${latestVolume.toStringAsFixed(0)} kg',
                    ),
                    _ProgressMetric(
                      label: '有效组',
                      value: '${latest?.effectiveSets ?? 0}',
                    ),
                    _ProgressMetric(
                      label: '记录变化',
                      value:
                          '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(1)}%',
                    ),
                    _ProgressMetric(label: '训练次数', value: '${records.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '关键动作表现',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final exerciseId
                    in (latest?.exerciseIds ?? const <String>[]).take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ExerciseThumb(exerciseId: exerciseId, size: 38),
                    title: Text(findExercise(exerciseId).name),
                    subtitle: const Text('最近一次完成 · 结合组别类型和重量复盘'),
                    trailing: const Icon(Icons.trending_up, color: cobalt),
                  ),
                const SizedBox(height: 8),
                Text(
                  changeRate >= 0
                      ? '你的训练量正在上升。下一次优先保持动作质量，再让正式组增加 1–2 次或小幅加重。'
                      : '训练量暂时回落，不必急着追重量。先检查恢复、有效组和最近动作完成质量。',
                  style: const TextStyle(color: secondaryInk),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: quiet)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

void _showExercisePicker(
  BuildContext context,
  AppController controller, {
  WorkoutExercise? replacing,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '添加动作',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final exercise in controller.visibleExercises)
                    ListTile(
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.muscle} · ${exercise.equipment}',
                      ),
                      trailing: Icon(
                        replacing == null ? Icons.add : Icons.swap_horiz,
                      ),
                      onTap: () {
                        if (replacing == null) {
                          controller.addExercise(exercise.id);
                        } else {
                          controller.replaceExercise(replacing.id, exercise.id);
                        }
                        Navigator.pop(context);
                      },
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

void _showExerciseActions(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('替换动作'),
          onTap: () {
            Navigator.pop(context);
            _showExercisePicker(context, controller, replacing: exercise);
          },
        ),
        ListTile(
          leading: const Icon(Icons.arrow_upward),
          title: const Text('上移动作'),
          onTap: () {
            controller.moveExercise(exercise, -1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.arrow_downward),
          title: const Text('下移动作'),
          onTap: () {
            controller.moveExercise(exercise, 1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(exercise.supersetId == null ? '加入超级组' : '取消超级组'),
          onTap: () {
            controller.toggleSuperset(exercise);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('杠片计算器'),
          onTap: () {
            Navigator.pop(context);
            _showPlateCalculator(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('移除动作'),
          onTap: () {
            controller.removeExercise(exercise);
            Navigator.pop(context);
          },
        ),
      ],
    ),
  ),
);

void _showWorkoutSettings(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '训练设置',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text('默认组间休息：${controller.defaultRestSeconds} 秒'),
              Slider(
                value: controller.defaultRestSeconds.toDouble(),
                min: 30,
                max: 300,
                divisions: 9,
                onChanged: (value) {
                  controller.defaultRestSeconds = value.round();
                  setSheetState(() {});
                },
              ),
              SwitchListTile(
                value: controller.rpeTrackingEnabled,
                onChanged: (value) {
                  controller.rpeTrackingEnabled = value;
                  setSheetState(() {});
                },
                title: const Text('记录 RPE'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showFinishWorkout(
  BuildContext context,
  AppController controller, {
  bool past = false,
}) {
  final note = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(past ? '补录训练' : '结束并保存'),
      content: TextField(
        controller: note,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '训练备注', hintText: '可选'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            controller.finishWorkout(note: note.text);
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

void _startPlanSession(
  BuildContext context,
  AppController controller,
  Plan plan,
) {
  final session = plan.sessions.first;
  controller.startWorkout(
    source: session.exerciseIds
        .map((id) => controller.createWorkoutExercise(id, 'plan-$id'))
        .toList(),
    name: session.name,
  );
  controller.openLiveWorkout();
  showKiloSnack(context, '已开始 ${session.name}');
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void _showCalendarDayActions(
  BuildContext context,
  AppController controller,
  DateTime date,
) {
  final key = _dateKey(date);
  final planned = controller.scheduled.contains(key);
  WorkoutRecord? record;
  for (final item in controller.history) {
    if (item.date.year == date.year &&
        item.date.month == date.month &&
        item.date.day == date.day) {
      record = item;
      break;
    }
  }
  final selectedRecord = record;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('日期详情'), dense: true),
          ListTile(
            title: Text('${date.year} 年 ${date.month} 月 ${date.day} 日'),
            subtitle: Text(
              planned
                  ? controller.scheduledLabels[key] ?? '已安排训练'
                  : record == null
                  ? '未安排训练'
                  : '已完成 ${record.name}',
            ),
          ),
          if (selectedRecord != null)
            ListTile(
              leading: const Icon(Icons.check_circle, color: cobalt),
              title: const Text('查看训练记录'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRecordDetail(context, controller, selectedRecord);
              },
            ),
          if (planned)
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('改期'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showScheduleEditor(
                  context,
                  controller,
                  oldDate: key,
                  initialDate: date,
                );
              },
            ),
          if (planned)
            ListTile(
              leading: const Icon(Icons.event_busy_outlined, color: orange),
              title: const Text('移除排程'),
              onTap: () {
                controller.unschedule(key);
                Navigator.pop(sheetContext);
                showKiloSnack(context, '排程已移除');
              },
            ),
          if (!planned)
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: cobalt),
              title: const Text('安排训练'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showScheduleEditor(context, controller, initialDate: date);
              },
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

void _showScheduleEditor(
  BuildContext context,
  AppController controller, {
  String? oldDate,
  DateTime? initialDate,
}) {
  DateTime selected =
      initialDate ?? DateTime.tryParse(oldDate ?? '') ?? DateTime.now();
  final label = TextEditingController(
    text: oldDate == null
        ? '训练安排'
        : controller.scheduledLabels[oldDate] ?? '训练安排',
  );
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(oldDate == null ? '新增排程' : '改期排程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: '训练名称'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => selected = picked);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (oldDate != null) controller.unschedule(oldDate);
              controller.schedule(
                selected,
                label.text.trim().isEmpty ? '训练安排' : label.text.trim(),
              );
              Navigator.pop(context);
              showKiloSnack(context, oldDate == null ? '排程已添加' : '排程已改期');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

void _showOfficialPlans(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('官方单日计划', style: Theme.of(context).textTheme.headlineMedium),
              const Text(
                '每个入口都是一节可直接执行的训练。先看详情，再决定使用。',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final plan in _PlansView.plans)
                      _PlanCard(controller: controller, plan: plan),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showPlanDetail(
  BuildContext context,
  AppController controller,
  Plan plan,
) {
  final session = plan.sessions.first;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${plan.title} · ${session.exercises} 个动作 · ${session.duration}',
                style: const TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 4),
              const Text(
                '单日训练详情',
                style: TextStyle(fontSize: 12, color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final id in session.exerciseIds)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ExerciseThumb(exerciseId: id, size: 42),
                        title: Text(findExercise(id).name),
                        subtitle: const Text('3 组 · 8 次 · 组间休息 120 秒'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: Key('plan-use-${plan.id}'),
                    onPressed: () {
                      controller.saveRoutineFromExerciseIds(
                        session.name,
                        session.exerciseIds,
                      );
                      Navigator.pop(context);
                      showKiloSnack(context, '已保存 ${session.name}');
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('使用此计划'),
                  ),
                  FilledButton.icon(
                    key: Key('plan-start-${plan.id}'),
                    onPressed: () {
                      Navigator.pop(context);
                      _startPlanSession(context, controller, plan);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始训练'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showRoutineMeta(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  final name = TextEditingController(text: routine.name);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('模板信息'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '训练名称'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            controller.renameRoutine(routine, name.text);
            Navigator.pop(context);
            showKiloSnack(context, '训练名称已保存');
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

void _showRoutinePicker(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '添加动作到模板',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final exercise in controller.allExercises)
                    ListTile(
                      leading: _ExerciseThumb(
                        exerciseId: exercise.id,
                        size: 38,
                      ),
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.muscle} · ${exercise.equipment}',
                      ),
                      onTap: () {
                        routine.exercises.add(
                          controller.createWorkoutExercise(
                            exercise.id,
                            'routine-${DateTime.now().microsecondsSinceEpoch}',
                          ),
                        );
                        routine.updatedAt = DateTime.now();
                        controller.refresh();
                        Navigator.pop(context);
                      },
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

void _showRoutineEditor(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .86,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        routine.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '模板信息',
                      onPressed: () =>
                          _showRoutineMeta(context, controller, routine),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                Text(
                  '${routine.exercises.length} 个动作 · 组别类型可逐组调整',
                  style: const TextStyle(color: quiet),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      for (
                        var index = 0;
                        index < routine.exercises.length;
                        index++
                      )
                        _RoutineExerciseEditor(
                          controller: controller,
                          routine: routine,
                          exercise: routine.exercises[index],
                          index: index,
                          onChanged: () => setSheetState(() {}),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showRoutinePicker(context, controller, routine),
                        icon: const Icon(Icons.add),
                        label: const Text('添加动作'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('template-editor-save-button'),
                    onPressed: () {
                      routine.updatedAt = DateTime.now();
                      controller.refresh();
                      Navigator.pop(context);
                      showKiloSnack(context, '训练模板已保存');
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存训练模板'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _RoutineExerciseEditor extends StatelessWidget {
  const _RoutineExerciseEditor({
    required this.controller,
    required this.routine,
    required this.exercise,
    required this.index,
    required this.onChanged,
  });
  final AppController controller;
  final Routine routine;
  final WorkoutExercise exercise;
  final int index;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final title = findExercise(exercise.exerciseId).name;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        leading: _ExerciseThumb(exerciseId: exercise.exerciseId, size: 38),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${exercise.sets.length} 组 · 休息 ${exercise.restSeconds}s${exercise.supersetId == null ? '' : ' · 超级组'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '上移',
                onPressed: index == 0
                    ? null
                    : () {
                        final item = routine.exercises.removeAt(index);
                        routine.exercises.insert(index - 1, item);
                        routine.updatedAt = DateTime.now();
                        controller.refresh();
                        onChanged();
                      },
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: index == routine.exercises.length - 1
                    ? null
                    : () {
                        final item = routine.exercises.removeAt(index);
                        routine.exercises.insert(index + 1, item);
                        routine.updatedAt = DateTime.now();
                        controller.refresh();
                        onChanged();
                      },
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: '替换',
                onPressed: () => _showRoutineReplacePicker(
                  context,
                  controller,
                  routine,
                  exercise,
                ),
                icon: const Icon(Icons.swap_horiz),
              ),
              IconButton(
                tooltip: exercise.supersetId == null ? '加入超级组' : '取消超级组',
                onPressed: () {
                  exercise.supersetId = exercise.supersetId == null
                      ? 'routine-superset-${DateTime.now().microsecondsSinceEpoch}'
                      : null;
                  controller.refresh();
                  onChanged();
                },
                icon: Icon(
                  exercise.supersetId == null ? Icons.link : Icons.link_off,
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () {
                  routine.exercises.removeAt(index);
                  routine.updatedAt = DateTime.now();
                  controller.refresh();
                  onChanged();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB83A3A),
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: '${exercise.restSeconds}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '动作休息（秒）'),
            onChanged: (value) {
              exercise.restSeconds =
                  int.tryParse(value) ?? exercise.restSeconds;
            },
          ),
          const SizedBox(height: 6),
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            _RoutineSetEditor(
              set: exercise.sets[setIndex],
              index: setIndex,
              onRemove: () {
                exercise.sets.removeAt(setIndex);
                controller.refresh();
                onChanged();
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final last = exercise.sets.isEmpty ? null : exercise.sets.last;
                exercise.sets.add(
                  WorkoutSet(
                    id: 'routine-set-${DateTime.now().microsecondsSinceEpoch}',
                    type: last?.type ?? 'work',
                    weight: last?.weight ?? 0,
                    reps: last?.reps ?? 8,
                    restSeconds: exercise.restSeconds,
                  ),
                );
                controller.refresh();
                onChanged();
              },
              icon: const Icon(Icons.add, size: 17),
              label: const Text('添加一组'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineSetEditor extends StatelessWidget {
  const _RoutineSetEditor({
    required this.set,
    required this.index,
    required this.onRemove,
  });
  final WorkoutSet set;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final typeWidth = (constraints.maxWidth - 40).clamp(150.0, 190.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Text('${index + 1}', style: const TextStyle(color: quiet)),
            ),
            SizedBox(
              width: typeWidth,
              child: DropdownButtonFormField<String>(
                initialValue: set.type,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '组别类型',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                ),
                items: [
                  for (final entry in setTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) set.type = value;
                },
              ),
            ),
            SizedBox(
              width: 68,
              child: TextFormField(
                initialValue: '${set.weight}',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '重量',
                  suffixText: 'kg',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                onChanged: (value) {
                  set.weight = double.tryParse(value) ?? set.weight;
                },
              ),
            ),
            SizedBox(
              width: 62,
              child: TextFormField(
                initialValue: '${set.reps}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '次数',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                onChanged: (value) {
                  set.reps = int.tryParse(value) ?? set.reps;
                },
              ),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
          ],
        ),
      );
    },
  );
}

void _showRoutineReplacePicker(
  BuildContext context,
  AppController controller,
  Routine routine,
  WorkoutExercise target,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '替换模板动作',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final item in controller.allExercises)
              ListTile(
                title: Text(item.name),
                subtitle: Text('${item.muscle} · ${item.equipment}'),
                onTap: () {
                  target.exerciseId = item.id;
                  routine.updatedAt = DateTime.now();
                  controller.refresh();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _showPlanBuilder(BuildContext context, AppController controller) {
  final name = TextEditingController(text: '我的训练模板');
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建训练'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: '训练名称'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('template-save-button'),
          onPressed: () {
            controller.saveRoutine(name.text, '自定义');
            Navigator.pop(context);
            showKiloSnack(context, '训练已保存');
          },
          child: const Text('保存训练'),
        ),
      ],
    ),
  );
}

void _showRecordDetail(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) {
  final details = record.exercises.isNotEmpty
      ? record.exercises
      : [
          for (var index = 0; index < record.exerciseIds.length; index++)
            controller.createWorkoutExercise(
              record.exerciseIds[index],
              'legacy-record-$index',
            ),
        ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: SingleChildScrollView(
          key: Key('record-detail-${record.id}'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${record.date.year}-${record.date.month}-${record.date.day} · ${record.startTime}',
              ),
              const SizedBox(height: 14),
              Text(
                '训练量 ${record.volume.toStringAsFixed(0)} kg · ${record.effectiveSets} 有效组',
              ),
              const SizedBox(height: 14),
              const Text(
                '动作与每组数据',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (details.isEmpty)
                const Text('这条记录没有保存动作明细。', style: TextStyle(color: quiet))
              else
                for (final exercise in details)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: paper,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            findExercise(exercise.exerciseId).name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          for (
                            var index = 0;
                            index < exercise.sets.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '第 ${index + 1} 组 · ${setTypeLabels[exercise.sets[index].type] ?? '组别类型'} · ${exercise.sets[index].weight.toStringAsFixed(1)} kg × ${exercise.sets[index].reps} 次 · 休息 ${exercise.sets[index].restSeconds} 秒',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (record.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(record.note),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRecordEditor(context, controller, record);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑备注'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '删除记录',
                    onPressed: () {
                      controller.deleteRecord(record);
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB83A3A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAllHistory(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('全部训练历史', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                '${controller.history.length} 次训练 · 点击查看动作与每组数据',
                style: const TextStyle(color: quiet),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    for (final record in controller.history)
                      _RecordTile(
                        record: record,
                        onTap: () =>
                            _showRecordDetail(context, controller, record),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showCustomExercise(BuildContext context, AppController controller) {
  final name = TextEditingController();
  final english = TextEditingController();
  final equipment = TextEditingController(text: '自定义器械');
  final muscle = TextEditingController(text: '未分类');
  final cue = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建自定义动作'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '动作名称 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: english,
              decoration: const InputDecoration(labelText: '英文名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: equipment,
              decoration: const InputDecoration(labelText: '器械'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: muscle,
              decoration: const InputDecoration(labelText: '主要肌群'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cue,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '动作提示'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isNotEmpty) {
              controller.addCustomExercise(
                name: name.text.trim(),
                englishName: english.text.trim(),
                equipment: equipment.text.trim(),
                muscle: muscle.text.trim(),
                cue: cue.text.trim(),
              );
            }
            Navigator.pop(context);
          },
          child: const Text('保存动作'),
        ),
      ],
    ),
  );
}

void _showLibraryFilters(BuildContext context, AppController controller) {
  final equipment = [
    '全部',
    ...{for (final item in controller.allExercises) item.equipment},
  ];
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '器械筛选',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in equipment)
                  ChoiceChip(
                    label: Text(item),
                    selected: controller.equipmentFilter == item,
                    onSelected: (_) {
                      controller.equipmentFilter = item;
                      controller.refresh();
                      Navigator.pop(sheetContext);
                      showKiloSnack(
                        context,
                        item == '全部' ? '已清除器械筛选' : '已筛选 $item',
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

void _showRecordEditor(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) {
  final note = TextEditingController(text: record.note);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('编辑训练备注'),
      content: TextField(
        controller: note,
        maxLines: 4,
        decoration: const InputDecoration(hintText: '记录本次训练的感受、PR 或异常'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            controller.updateRecordNote(record, note.text.trim());
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

void _showCitation(BuildContext context, List<String> citations) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '回答依据',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final citation in citations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.format_quote, color: cobalt),
                title: Text(citation),
                subtitle: const Text('服务端校验后的引用摘要，可追溯到原始来源。'),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    ),
  );
}

void _showScenario(BuildContext context, AppController controller) {
  final options = <String, String>{
    'normal': '正常',
    'low-confidence': '低置信度',
    'offline': '离线',
    'empty': '空数据 / 无证据',
    'error': '识别服务错误',
  };
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '模拟场景',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: controller.scenario,
              decoration: const InputDecoration(labelText: '选择场景'),
              items: [
                for (final entry in options.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.scenario = value;
                  controller.refresh();
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

void _confirmReset(BuildContext context, AppController controller) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置演示数据？'),
        content: const Text('本地训练草稿、计时和识别状态会回到初始示例。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              controller.resetDemo();
              Navigator.pop(context);
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
