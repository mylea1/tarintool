// Manual browser QA of real Flutter screens. Not a production entry point.
// Copy lib, assets and this file to a temporary Flutter Web host first;
// the mobile project intentionally has no production Web configuration.
// flutter build web --no-pub --target=test/support/trend_review.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/product_features.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional locally served QA font; never bundled with the production app.
  const qaFont = String.fromEnvironment('QA_FONT');
  if (qaFont.isNotEmpty) {
    await (FontLoader('ChartReview')..addFont(rootBundle.load(qaFont))).load();
  }
  final controller = AppController();
  final now = DateTime.now();
  for (var i = 0; i < 8; i++) {
    controller.history.add(
      WorkoutRecord(
        id: 'chart-review-$i',
        name: '上肢训练',
        date: DateTime(now.year, now.month, now.day - i * 3),
        startTime: '18:30',
        durationSeconds: 2400,
        volume: ((80 - i) * 8 * 3).toDouble(),
        effectiveSets: 3,
        exerciseIds: const ['bench_press', 'pull_up'],
        exercises: [
          for (final id in ['bench_press', 'pull_up'])
            WorkoutExercise(
              id: '$id-$i',
              exerciseId: id,
              sets: [
                WorkoutSet(
                  id: 'set-$id-$i',
                  weight: id == 'pull_up' ? 0 : 80 - i.toDouble(),
                  reps: 8 + i % 3,
                  completed: true,
                ),
              ],
            ),
        ],
      ),
    );
    controller.weightEntries.add(
      WeightEntry(
        id: 'weight-$i',
        recordedAt: DateTime(now.year, now.month, now.day - i * 3, 7, 30),
        weightKg: 64 + i * .15,
      ),
    );
  }
  controller.trackedExerciseIds.addAll(['bench_press', 'pull_up']);
  controller.openTrainingStatistics();
  runApp(
    MaterialApp(
      theme: ThemeData(
        fontFamily: qaFont.isEmpty ? null : 'ChartReview',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC45112)),
        scaffoldBackgroundColor: const Color(0xFFF5F1EB),
        useMaterial3: true,
      ),
      home: _Review(controller: controller),
    ),
  );
}

class _Review extends StatefulWidget {
  const _Review({required this.controller});
  final AppController controller;
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  int page = 0;
  bool large = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Flutter 图表验收'),
      actions: [
        IconButton(
          tooltip: '切换大字',
          onPressed: () => setState(() => large = !large),
          icon: const Icon(Icons.text_fields),
        ),
      ],
    ),
    body: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
      child: switch (page) {
        0 => RecordsPage(controller: widget.controller),
        1 => NutritionCenterPage(controller: widget.controller),
        _ => ProfilePage(controller: widget.controller),
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (p) => setState(() => page = p),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.show_chart), label: '动作'),
        NavigationDestination(icon: Icon(Icons.monitor_weight), label: '体重'),
        NavigationDestination(icon: Icon(Icons.insights), label: '进步'),
      ],
    ),
  );
}
