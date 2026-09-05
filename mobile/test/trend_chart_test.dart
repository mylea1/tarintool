import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/trend_chart.dart';
import 'package:kilo_strength/trend_data.dart';
import 'package:kilo_strength/models.dart';

void main() {
  test(
    'daily readings retain the latest source and exclude outside-range readings',
    () {
      final readings = [
        WeightEntry(
          id: 'before',
          recordedAt: DateTime(2026, 8, 31),
          weightKg: 70,
        ),
        WeightEntry(
          id: 'morning',
          recordedAt: DateTime(2026, 9, 1, 8),
          weightKg: 65,
        ),
        WeightEntry(
          id: 'evening',
          recordedAt: DateTime(2026, 9, 1, 20),
          weightKg: 66,
          note: '晚间',
        ),
        WeightEntry(
          id: 'next',
          recordedAt: DateTime(2026, 9, 4, 9),
          weightKg: 64,
        ),
        WeightEntry(
          id: 'after',
          recordedAt: DateTime(2026, 9, 5),
          weightKg: 69,
        ),
      ];
      final data = dailyWeightRecords(
        readings.reversed.toList(),
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 4),
      );
      expect(data.map((e) => e.id), ['evening', 'next']);
      expect(data.first.recordedAt.hour, 20);
      expect(data.first.note, '晚间');
      expect(data.last.weightKg - data.first.weightKg, -2);
    },
  );

  test(
    'weekly volume clips the range, excludes non-work and flags legacy records',
    () {
      WorkoutRecord record(String id, DateTime date, {bool legacy = false}) =>
          WorkoutRecord(
            id: id,
            name: id,
            date: date,
            startTime: '08:00',
            durationSeconds: 300,
            volume: 999999,
            effectiveSets: 1,
            exerciseIds: const ['bench_press'],
            exercises: legacy
                ? []
                : [
                    WorkoutExercise(
                      id: id,
                      exerciseId: 'bench_press',
                      sets: [
                        WorkoutSet(
                          id: '$id-work',
                          weight: 80,
                          reps: 8,
                          completed: true,
                        ),
                        WorkoutSet(
                          id: '$id-warmup',
                          type: 'warmup',
                          weight: 60,
                          reps: 10,
                          completed: true,
                        ),
                        WorkoutSet(
                          id: '$id-tech',
                          type: 'technique',
                          weight: 50,
                          reps: 10,
                          completed: true,
                        ),
                        WorkoutSet(id: '$id-open', weight: 100, reps: 10),
                      ],
                    ),
                  ],
          );
      final weeks = weeklyTrainingVolumes(
        [
          record('outside', DateTime(2026, 8, 24)),
          record('inside', DateTime(2026, 8, 26)),
          record('legacy', DateTime(2026, 9, 2), legacy: true),
          record('future', DateTime(2026, 9, 6)),
        ],
        DateTime(2026, 8, 26),
        DateTime(2026, 9, 10),
        now: DateTime(2026, 9, 5),
      );
      expect(weeks, hasLength(2));
      expect(weeks.first.weekStart, DateTime(2026, 8, 24));
      expect(weeks.first.volume, 640);
      expect(weeks.first.partial, isTrue);
      expect(weeks.last.records.map((r) => r.id), ['legacy']);
      expect(weeks.last.missingDetails, 1);
      expect(weeks.last.current, isTrue);
      expect(weeks.last.end, DateTime(2026, 9, 5));
      final empty = weeklyTrainingVolumes(
        [],
        DateTime(2026, 8, 24),
        DateTime(2026, 9, 5),
        now: DateTime(2026, 9, 5),
      );
      expect(empty.every((w) => w.volume == 0 && w.records.isEmpty), isTrue);
    },
  );

  testWidgets(
    'selection survives metric changes and resolves deleted IDs safely',
    (tester) async {
      final start = DateTime(2026, 9, 1), end = DateTime(2026, 9, 30);
      var metric = '重量';
      var ids = ['a', 'b', 'c'];
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return TrendChart(
                  start: start,
                  end: end,
                  unit: metric,
                  data: [
                    for (var i = 0; i < ids.length; i++)
                      TrendDatum(
                        id: ids[i],
                        date: start.add(Duration(days: i * 7)),
                        value: metric == '重量' ? 70.0 + i : 8.0 + i,
                        description: ids[i],
                      ),
                  ],
                  detailBuilder: (context, point) =>
                      Text('selected:${point.id}'),
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('selected:c'), findsOneWidget);
      await tester.tap(find.byTooltip('上一条记录'));
      await tester.pump();
      expect(find.text('selected:b'), findsOneWidget);
      update(() => metric = '次数');
      await tester.pump();
      expect(find.text('selected:b'), findsOneWidget);
      update(() => ids = ['a', 'c']);
      await tester.pump();
      expect(find.text('selected:c'), findsOneWidget);
      await tester.tap(find.byType(GestureDetector).first);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(find.text('selected:a'), findsOneWidget);
      update(() => ids = []);
      await tester.pump();
      expect(find.text('所选时间段暂无记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 375.0, 414.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('single series and bar chart fit $width at 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final bars in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1400),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TrendChart(
                      bars: bars,
                      unit: '训练量 · kg·次',
                      minimumSpan: 5,
                      start: DateTime(2026, 8, 1),
                      end: DateTime(2026, 9, 5),
                      data: [
                        for (var i = 0; i < 10; i++)
                          TrendDatum(
                            id: '$i',
                            date: DateTime(2026, 8, 1 + i * 3),
                            value: 123456.0 + i * 2000,
                            description: '长记录名称ABCDEFGHIJK0123456789$i',
                          ),
                      ],
                      detailBuilder: (context, p) => Text(p.description),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final box = tester.getRect(find.byType(TrendChart));
        expect(box.right, lessThanOrEqualTo(width));
      }
    });
  }
}
