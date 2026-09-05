import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/product_features.dart';
import 'package:kilo_strength/trend_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutRecord sample(String id, int days, double weight, int reps) =>
    WorkoutRecord(
      id: id,
      name: '上肢训练 $id',
      date: DateTime.now().subtract(Duration(days: days)),
      startTime: '18:00',
      durationSeconds: 1800,
      volume: weight * reps,
      effectiveSets: 1,
      exerciseIds: const ['bench_press'],
      exercises: [
        WorkoutExercise(
          id: id,
          exerciseId: 'bench_press',
          sets: [
            WorkoutSet(
              id: 'set-$id',
              weight: weight,
              reps: reps,
              completed: true,
            ),
          ],
        ),
      ],
    );

Future<void> show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'strength retains paired source and updates after source deletion',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      final older = sample('older', 3, 75, 10),
          latest = sample('latest', 0, 80, 8);
      controller.history.addAll([latest, older]);
      controller.trackedExerciseIds.add('bench_press');
      controller.openTrainingStatistics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecordsPage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await show(tester, find.byTooltip('上一条记录'));
      await tester.tap(find.byTooltip('上一条记录'));
      await tester.pumpAndSettle();
      await show(
        tester,
        find.byKey(const Key('tracked-metric-bench_press-reps')),
      );
      await tester.tap(
        find.byKey(const Key('tracked-metric-bench_press-reps')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('statistics-strength-point-bench_press')),
            )
            .data,
        '75 kg × 10 次',
      );
      final link = find.byKey(const Key('growth-record-bench_press'));
      await show(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('record-detail-older')), findsOneWidget);
      Navigator.of(
        tester.element(find.byKey(const Key('record-detail-older'))),
      ).pop();
      await tester.pumpAndSettle();
      controller.deleteRecord(older);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('statistics-strength-point-bench_press')),
            )
            .data,
        '80 kg × 8 次',
      );
      controller.deleteRecord(latest);
      await tester.pumpAndSettle();
      expect(find.text('所选时间段暂无记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weight chart opens the exact daily reading and reacts to editing and deletion',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController();
      addTearDown(controller.dispose);
      final now = DateTime.now();
      final last = WeightEntry(
        id: 'last',
        recordedAt: DateTime(now.year, now.month, now.day, 20),
        weightKg: 64.1,
        note: '晚间测量',
      );
      controller.weightEntries.addAll([
        WeightEntry(
          id: 'first',
          recordedAt: DateTime(now.year, now.month, now.day - 3, 8),
          weightKg: 65,
        ),
        WeightEntry(
          id: 'morning',
          recordedAt: DateTime(now.year, now.month, now.day, 7),
          weightKg: 64.5,
        ),
        last,
      ]);
      await tester.pumpWidget(
        MaterialApp(home: NutritionCenterPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      final link = find.byKey(const Key('weight-chart-open-record'));
      await tester.scrollUntilVisible(
        link,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weight-history-last')), findsOneWidget);
      expect(find.textContaining('晚间测量'), findsOneWidget);
      await controller.updateWeightEntry(last.copyWith(weightKg: 64.3));
      await tester.pumpAndSettle();
      expect(find.text('64.3 kg'), findsWidgets);
      await controller.deleteWeightEntry('last');
      await tester.pumpAndSettle();
      expect(find.text('这条记录已删除'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('weight-selected-value')))
            .data,
        '64.5 kg',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'weekly chart drills into real records with a partial current week',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.history.add(sample('today', 0, 80, 8));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfilePage(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.text('训练进步');
      await show(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final chart = tester.widget<TrendChart>(
        find.byKey(const Key('progress-trend-chart')),
      );
      expect(chart.bars, isTrue);
      expect(chart.data.last.value, 640);
      expect(find.textContaining('截至'), findsOneWidget);
      final link = find.byKey(const Key('weekly-open-records'));
      await show(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekly-record-today')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('record-detail-today')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
