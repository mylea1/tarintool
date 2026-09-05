// Run explicitly with flutter test test/refinement_visual_capture.dart
// --update-goldens to render the actual Flutter pages for design review.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/membership_ui.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = Key('refinement-capture');

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _snapshot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(_capture),
    matchesGoldenFile(
      '../../design-previews/training-refinement-v1/flutter-$name.png',
    ),
  );
}

WorkoutRecord _record(int days, double weight, int reps) => WorkoutRecord(
  id: 'preview-$days',
  name: '上肢训练',
  date: DateTime.now().subtract(Duration(days: days)),
  startTime: '18:00',
  durationSeconds: 2400,
  volume: weight * reps * 3,
  effectiveSets: 3,
  exerciseIds: const ['bench_press'],
  exercises: [
    WorkoutExercise(
      id: 'bench-$days',
      exerciseId: 'bench_press',
      sets: [
        for (var i = 0; i < 3; i++)
          WorkoutSet(
            id: 'set-$days-$i',
            weight: weight,
            reps: reps,
            completed: true,
          ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    // Optional local QA font, not bundled or redistributed with the app.
    final path = Platform.environment['KILO_QA_FONT'];
    if (path != null) {
      final bytes = ByteData.sublistView(await File(path).readAsBytes());
      for (final family in ['Roboto', 'Ahem']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('render full-page plan editor', (tester) async {
    _viewport(tester, 375);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.selectTrainView(TrainView.plans);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: KiloApp(initialController: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建计划').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('draft-add-exercise')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('exercise-picker-add-${selectableCatalog.first.id}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('exercise-picker-add-selected')));
    await tester.pumpAndSettle();
    await _snapshot(tester, 'plan-375');
  });

  testWidgets('render real statistics weight and reps', (tester) async {
    _viewport(tester, 375);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.history.addAll([
      _record(6, 75, 10),
      _record(3, 80, 8),
      _record(0, 80, 10),
    ]);
    controller.trackedExerciseIds.add('bench_press');
    controller.openTrainingStatistics();
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: KiloApp(initialController: controller),
      ),
    );
    await tester.pumpAndSettle();
    final chart = find.byKey(
      const Key('statistics-strength-chart-bench_press'),
    );
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    await _snapshot(tester, 'growth-weight-375');
    final metric = find.byKey(const Key('tracked-metric-bench_press-reps'));
    await tester.ensureVisible(metric);
    await tester.pumpAndSettle();
    await tester.tap(metric);
    await tester.pumpAndSettle();
    await tester.ensureVisible(chart);
    await _snapshot(tester, 'growth-reps-375');
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('render membership $width', (tester) async {
      _viewport(tester, width);
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _capture,
          child: MaterialApp(
            home: MembershipCenterPage(controller: controller),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await _snapshot(tester, 'membership-${width.toInt()}');
    });
  }

  testWidgets('render restored AI recognition entry at 320dp', (tester) async {
    _viewport(tester, 320);
    final controller = AppController()..page = PageId.ai;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _capture,
        child: KiloApp(initialController: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _snapshot(tester, 'ai-320');
    await tester.tap(find.byKey(const Key('ai-recognition-entry')));
    await tester.pumpAndSettle();
    await _snapshot(tester, 'ai-recognition-320');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-page')), findsOneWidget);
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('render home muscle palette $width', (tester) async {
      _viewport(tester, width);
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.history.addAll([_record(3, 75, 10), _record(0, 80, 10)]);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _capture,
          child: KiloApp(initialController: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home-muscle-card')));
      await _snapshot(tester, 'home-${width.toInt()}');
      await tester.tap(find.byKey(const Key('home-muscle-recovery-tab')));
      await tester.pumpAndSettle();
      await _snapshot(tester, 'home-recovery-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
