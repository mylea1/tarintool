import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/exercise_media.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';

Future<void> _openRoute(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('all reference exercise media assets load', () async {
    expect(catalog, hasLength(1324));
    expect(catalog.map((item) => item.id).toSet(), hasLength(1324));
    expect(allExerciseMedia, hasLength(1324));
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetKeys = manifest.listAssets().toSet();
    for (final entry in allExerciseMedia.entries) {
      final image = mediaForExercise(entry.key)!.imagePath;
      final gif = mediaForExercise(entry.key)!.gifPath;
      expect(image, endsWith('.jpg'));
      expect(gif, endsWith('.gif'));
      expect(assetKeys, contains(image));
      expect(assetKeys, contains(gif));
    }
    for (final media in <ExerciseMedia>[
      allExerciseMedia.values.first,
      allExerciseMedia.values.last,
    ]) {
      expect(
        (await rootBundle.load(media.imagePath)).lengthInBytes,
        greaterThan(0),
      );
      expect(
        (await rootBundle.load(media.gifPath)).lengthInBytes,
        greaterThan(0),
      );
    }
  });

  testWidgets('full dataset exercise is searchable and opens its media', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '动作');

    expect(find.text('1324 个动作'), findsOneWidget);
    expect(find.byKey(const Key('exercise-library-load-more')), findsOneWidget);
    expect(
      tester
          .widget<GridView>(find.byKey(const Key('exercise-library-grid')))
          .childrenDelegate
          .estimatedChildCount,
      60,
    );
    await tester.ensureVisible(
      find.byKey(const Key('exercise-library-load-more')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-library-load-more')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GridView>(find.byKey(const Key('exercise-library-grid')))
          .childrenDelegate
          .estimatedChildCount,
      120,
    );
    await tester.enterText(
      find.byKey(const Key('exercise-search')),
      '3/4 sit-up',
    );
    await tester.pumpAndSettle();

    final cover = find.byKey(const Key('exercise-cover-dataset_0001'));
    expect(cover, findsOneWidget);
    await tester.tap(cover);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('exercise-detail-gif-dataset_0001')),
      findsOneWidget,
    );
    expect(find.text('分步说明'), findsNothing);
    await tester.tap(find.text('教学').last);
    await tester.pumpAndSettle();
    expect(find.text('分步说明'), findsOneWidget);
  });

  testWidgets('shell starts without preloaded user data', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byKey(const Key('home-overview-section')), findsOneWidget);
    expect(find.text('训练概览'), findsOneWidget);
    expect(find.text('训练周'), findsOneWidget);
    expect(find.text('进步摘要'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('最近记录'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('最近记录'), findsOneWidget);
    expect(find.text('上肢力量 A'), findsNothing);
    expect(find.text('重置演示数据'), findsNothing);
    expect(controller.history, isEmpty);
    expect(controller.routines, isEmpty);
  });

  testWidgets('warm orange theme tokens reach shell navigation and inputs', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));

    final context = tester.element(find.byType(KiloShell));
    final theme = Theme.of(context);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFF7F0));
    expect(theme.colorScheme.primary, const Color(0xFFD95718));
    expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(
      NavigationBarTheme.of(context).indicatorColor,
      const Color(0xFFFFE3D2),
    );
    final focusedBorder = theme.inputDecorationTheme.focusedBorder!;
    expect(focusedBorder.borderSide.color, const Color(0xFFD95718));
  });

  testWidgets('free training starts empty timer and can add first action', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');
    await tester.tap(find.byKey(const Key('free-workout-button')));
    await tester.pumpAndSettle();

    expect(controller.workoutStarted, isTrue);
    expect(controller.workoutTimerStarted, isFalse);
    expect(controller.workout, isEmpty);
    expect(find.byKey(const Key('start-workout-timer-button')), findsOneWidget);
    expect(find.byKey(const Key('pause-workout-button')), findsNothing);
    await tester.tap(find.byKey(const Key('start-workout-timer-button')));
    await tester.pump();
    expect(controller.workoutTimerStarted, isTrue);
    expect(find.byKey(const Key('pause-workout-button')), findsOneWidget);
    expect(find.byKey(const Key('first-action-button')), findsOneWidget);
    expect(find.text('添加第一个动作'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('first-action-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-picker')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('exercise-picker-search')),
      '杠铃卧推',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('exercise-picker-item-bench_press')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('exercise-picker-add-selected')),
    );
    await tester.tap(find.byKey(const Key('exercise-picker-add-selected')));
    await tester.pumpAndSettle();
    expect(controller.workout, hasLength(1));
    expect(controller.workout.single.sets, isEmpty);
    await tester.tap(
      find.byKey(Key('first-set-${controller.workout.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(controller.workout.single.sets, hasLength(1));
    expect(controller.workout.single.sets.first.plannedWeight, isNull);
    expect(controller.workout.single.sets.first.weight, 0);
    expect(controller.workout.single.sets.first.reps, 0);
    expect(find.text('kg'), findsWidgets);
    expect(find.byKey(const Key('live-add-exercise')), findsOneWidget);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets('plan editor cancel keeps original draft and save commits', (
    tester,
  ) async {
    final controller = AppController();
    final fixture = controller.createWorkoutExercise('bench_press', 'fixture');
    controller.saveRoutineFromDraft('测试计划', [fixture]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');
    await tester.tap(
      find.byKey(Key('routine-more-${controller.routines.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('routine-edit-${controller.routines.first.id}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('template-editor-save-button')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('routine-editor-name')),
      '改名草稿',
    );
    await tester.tap(find.byTooltip('取消并返回'));
    await tester.pumpAndSettle();
    expect(controller.routines.first.name, '测试计划');

    await tester.tap(
      find.byKey(Key('routine-more-${controller.routines.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('routine-edit-${controller.routines.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('routine-editor-name')),
      '已保存计划',
    );
    await tester.tap(find.byKey(const Key('template-editor-save-button')));
    await tester.pumpAndSettle();
    expect(controller.routines.first.name, '已保存计划');
  });

  testWidgets('official plans remain available without user fixtures', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');
    await tester.tap(find.byKey(const Key('official-plans-entry')));
    await tester.pumpAndSettle();
    expect(find.text('官方单日计划'), findsOneWidget);
    expect(
      find.byKey(const Key('official-plan-upper-lower-4')),
      findsOneWidget,
    );
  });

  testWidgets('timer bridge tolerates missing plugins and forwards methods', (
    tester,
  ) async {
    const channel = MethodChannel('kilo.platform.timer');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    final controller = AppController();
    addTearDown(() async {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    controller.startWorkout(name: '自由训练');
    controller.startRest(exercise: '卧推', seconds: 30);
    controller.skipRest();
    controller.finishWorkout();
    await tester.pump();
    expect(
      calls,
      containsAll(<String>[
        'startWorkout',
        'startTimer',
        'clearRest',
        'finishTimer',
      ]),
    );
  });

  testWidgets('shell remains usable at compact width', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('free-workout-button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets(
    'recognition choices use backend capability cards at compact width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(KiloApp(initialController: controller));
      await _openRoute(tester, 'AI');
      await tester.tap(find.byKey(const Key('ai-recognition')));
      await tester.pump();

      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(
        find.byKey(const Key('recognition-exercise-picker')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('recognition-exercise-picker')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recognition-exercise-barbell_squat')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('recognition-search')), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('recognition-exercise-barbell_squat')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recognition-camera-side')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recognition result opens a full report with AI review', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.recognitionStatus = RecognitionStatus.complete;
    controller.recognitionResult = const RecognitionResult(
      status: RecognitionStatus.complete,
      confidence: .88,
      repetitions: 8,
      summary: '骨骼识别完成',
      metrics: {'durationSeconds': 12.6, 'detectionRate': .9},
      aiReview: RecognitionAiReview(
        headline: '整体轨迹稳定',
        strengths: ['动作节奏一致'],
        risks: ['末端控制可加强'],
        nextSet: '保持重量并减慢离心',
        basis: '骨骼捕获率和动作重复数据',
      ),
    );
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, 'AI');
    await tester.tap(find.byKey(const Key('ai-recognition')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('recognition-open-result')),
    );
    await tester.tap(find.byKey(const Key('recognition-open-result')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recognition-result-page')), findsOneWidget);
    expect(find.byKey(const Key('recognition-ai-review')), findsOneWidget);
    expect(find.text('整体轨迹稳定'), findsOneWidget);
    expect(find.textContaining('末端控制可加强'), findsOneWidget);
  });

  testWidgets(
    'recognition keeps video visible and exposes live processing stages',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.selectedMediaPath = 'missing-test-video.mp4';
      controller.selectedMediaName = '训练视频.mp4';
      controller.selectedMediaBytes = 3 * 1024 * 1024;
      controller.recognitionStatus = RecognitionStatus.processing;
      controller.recognitionStage = RecognitionStage.analyzing;
      controller.recognitionElapsedSeconds = 72;
      await tester.pumpWidget(KiloApp(initialController: controller));
      await _openRoute(tester, 'AI');
      await tester.tap(find.byKey(const Key('ai-recognition')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('recognition-video-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-processing-panel')),
        findsOneWidget,
      );
      expect(find.text('正在分析动作轨迹'), findsWidgets);
      expect(find.textContaining('01:12'), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-overlay-switch')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exercise picker filters and adds multiple actions without changing library state',
    (tester) async {
      final controller = AppController();
      addTearDown(() {
        if (controller.workoutStarted) controller.finishWorkout();
        controller.dispose();
      });
      controller.startWorkout(name: '自由训练');
      controller.openLiveWorkout();
      await tester.pumpWidget(KiloApp(initialController: controller));
      await tester.drag(find.byType(ListView).last, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('first-action-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SizedBox>(
              find.byKey(const Key('exercise-picker-muscle-strip')),
            )
            .width,
        82,
      );
      final originalSearch = controller.search;
      final originalMuscle = controller.muscleFilter;
      await tester.enterText(
        find.byKey(const Key('exercise-picker-search')),
        '卧推',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('exercise-picker-item-bench_press')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsWidgets);
      await tester.tap(find.byKey(const Key('exercise-picker-filter-胸')));
      await tester.pump();
      expect(find.text('没有匹配动作，试试清空搜索或切换部位。'), findsNothing);
      expect(controller.search, originalSearch);
      expect(controller.muscleFilter, originalMuscle);
      await tester.tap(
        find.byKey(const Key('exercise-picker-item-bench_press')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('exercise-picker-filter-全部')));
      await tester.enterText(
        find.byKey(const Key('exercise-picker-search')),
        '高脚杯深蹲',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('exercise-picker-item-goblet_squat')),
      );
      await tester.pump();
      expect(find.text('添加 2 个动作'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exercise-picker-add-selected')));
      await tester.pumpAndSettle();
      expect(controller.workout, hasLength(2));
      controller.finishWorkout();
      await tester.pump();
    },
  );

  testWidgets('rest editor saves quick values and cancels safely', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '自由训练');
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(Key('rest-settings-${controller.workout.single.id}')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(Key('rest-settings-${controller.workout.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest-seconds-input')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rest-quick-120')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('rest-seconds-input')))
          .controller!
          .text,
      '120',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('rest-quick-120')))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('rest-save-button')));
    await tester.pumpAndSettle();
    expect(controller.workout.single.restSeconds, 120);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(Key('rest-settings-${controller.workout.single.id}')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(Key('rest-settings-${controller.workout.single.id}')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rest-seconds-input')), '601');
    await tester.tap(find.byKey(const Key('rest-save-button')));
    await tester.pump();
    expect(controller.workout.single.restSeconds, 120);
    await tester.tap(find.byKey(const Key('rest-cancel-button')));
    await tester.pumpAndSettle();
    expect(controller.workout.single.restSeconds, 120);
    expect(tester.takeException(), isNull);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets('live workout can delete an unfinished or completed set', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '删组测试');
    controller.addExercise('bench_press');
    final exercise = controller.workout.single;
    controller.addSet(exercise);
    controller.addSet(exercise);
    final completed = exercise.sets.first..completed = true;
    final unfinished = exercise.sets.last;
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });

    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.ensureVisible(find.byKey(Key('delete-set-${completed.id}')));
    await tester.tap(find.byKey(Key('delete-set-${completed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('这组已完成，删除后训练统计会同步更新。'), findsOneWidget);
    await tester.tap(find.byKey(Key('confirm-delete-set-${completed.id}')));
    await tester.pumpAndSettle();
    expect(exercise.sets, isNot(contains(completed)));

    await tester.ensureVisible(find.byKey(Key('delete-set-${unfinished.id}')));
    await tester.tap(find.byKey(Key('delete-set-${unfinished.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('confirm-delete-set-${unfinished.id}')));
    await tester.pumpAndSettle();
    expect(exercise.sets, isEmpty);
    controller.finishWorkout();
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('compact live controls keep actions visible at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    controller.startWorkout(name: '自由训练');
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    expect(find.byKey(const Key('live-workout-controls')), findsOneWidget);
    expect(find.byKey(const Key('pause-workout-button')), findsOneWidget);
    expect(find.byKey(const Key('workout-batch-button')), findsOneWidget);
    expect(find.byKey(const Key('plate-calculator-button')), findsOneWidget);
    expect(find.byKey(const Key('workout-settings-button')), findsOneWidget);
    expect(find.text('已完成 0/1 组'), findsNothing);
    expect(find.text('先检查动作，再开始计时'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('pause-workout-button')));
    await tester.pump();
    expect(controller.workoutPaused, isTrue);
    expect(tester.takeException(), isNull);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets('exercise picker rail has no compact-width overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    controller.startWorkout(name: '自由训练');
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('first-action-button')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('first-action-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('exercise-picker-muscle-strip')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('exercise-picker-muscle-strip')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-picker-filter-腿')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('高脚杯深蹲'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('高脚杯深蹲'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭动作选择'));
    await tester.pumpAndSettle();
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets(
    'completing the first set automatically starts workout and rest timers',
    (tester) async {
      final controller = AppController();
      controller.startWorkout(name: '自动开练', autoStartTimer: false);
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      controller.updateExerciseRest(exercise, 45);
      controller.openLiveWorkout();
      addTearDown(() {
        if (controller.workoutStarted) controller.finishWorkout();
        controller.dispose();
      });

      await tester.pumpWidget(KiloApp(initialController: controller));
      final set = exercise.sets.single;
      expect(controller.workoutTimerStarted, isFalse);

      await tester.ensureVisible(find.byKey(Key('set-complete-${set.id}')));
      await tester.tap(find.byKey(Key('set-complete-${set.id}')));
      await tester.pump();

      expect(controller.workoutTimerStarted, isTrue);
      expect(set.completed, isTrue);
      expect(controller.restRunning, isTrue);
      expect(controller.restRemainingSeconds, 45);
      expect(find.text('训练已开始，本组完成，休息计时已启动'), findsOneWidget);
      controller.finishWorkout();
      await tester.pump(const Duration(milliseconds: 900));
    },
  );

  testWidgets(
    'completion burst is deterministic and finish defaults to saving free plan',
    (tester) async {
      final controller = AppController();
      controller.startWorkout(name: '自由训练');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      controller.openLiveWorkout();
      addTearDown(() {
        if (controller.workoutStarted) controller.finishWorkout();
        controller.dispose();
      });
      await tester.pumpWidget(KiloApp(initialController: controller));
      final set = exercise.sets.single;
      await tester.ensureVisible(find.byKey(Key('set-complete-${set.id}')));
      await tester.tap(find.byKey(Key('set-complete-${set.id}')));
      await tester.pump();
      expect(controller.completionBurstActive, isTrue);
      expect(find.byKey(const Key('completion-burst')), findsOneWidget);
      final burstId = controller.completionBurstId;
      await tester.ensureVisible(find.byKey(Key('set-complete-${set.id}')));
      await tester.tap(find.byKey(Key('set-complete-${set.id}')));
      await tester.pump();
      expect(controller.completionBurstId, burstId);

      await tester.scrollUntilVisible(
        find.byKey(const Key('finish-workout-button')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finish-workout-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('finish-save-routine-checkbox')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('finish-routine-name')),
        '我的自由计划',
      );
      await tester.tap(find.byKey(const Key('finish-save-button')));
      await tester.pumpAndSettle();
      expect(controller.history, hasLength(1));
      expect(controller.routines, hasLength(1));
      expect(controller.routines.single.name, '我的自由计划');
    },
  );

  testWidgets('free finish can cancel saving a plan', (tester) async {
    final controller = AppController();
    controller.startWorkout(name: '自由训练');
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('finish-workout-button')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-workout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-save-routine-checkbox')));
    await tester.tap(find.byKey(const Key('finish-save-button')));
    await tester.pumpAndSettle();
    expect(controller.history, hasLength(1));
    expect(controller.routines, isEmpty);
  });

  testWidgets(
    'live set rows show previous history, preserve values, and toggle green',
    (tester) async {
      final controller = AppController();
      addTearDown(() {
        if (controller.workoutStarted) controller.finishWorkout();
        controller.dispose();
      });

      // Seed a real history snapshot. The next free session must read this
      // value instead of a plan/default weight.
      controller.startWorkout(name: 'history source');
      controller.addExercise('bench_press');
      final historyExercise = controller.workout.single;
      controller.addSet(historyExercise);
      historyExercise.sets.single
        ..weight = 67.5
        ..reps = 6
        ..completed = true;
      controller.finishWorkout();

      controller.startWorkout(name: 'live row');
      controller.addExercise('bench_press');
      final exercise = controller.workout.single;
      controller.addSet(exercise);
      final set = exercise.sets.single
        ..weight = 77.5
        ..reps = 5
        ..note = '窄握';
      controller.openLiveWorkout();

      await tester.pumpWidget(KiloApp(initialController: controller));
      expect(find.byKey(Key('previous-set-${set.id}')), findsOneWidget);
      expect(find.text('67.5×6'), findsOneWidget);

      await tester.tap(find.byKey(Key('set-type-${set.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('set-type-option-${set.id}-warmup')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(Key('set-type-option-${set.id}-warmup')));
      await tester.pumpAndSettle();
      expect(set.type, 'warmup');

      await tester.tap(find.byKey(Key('set-note-${set.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(Key('set-note-input-${set.id}')),
        '窄握，最后两次速度变慢',
      );
      await tester.tap(find.byKey(Key('set-note-save-${set.id}')));
      await tester.pumpAndSettle();
      expect(set.note, '窄握，最后两次速度变慢');
      expect(find.byKey(Key('set-note-preview-${set.id}')), findsOneWidget);
      expect(find.textContaining('窄握，最后两次速度变慢'), findsOneWidget);

      await tester.ensureVisible(find.byKey(Key('set-complete-${set.id}')));
      await tester.tap(find.byKey(Key('set-complete-${set.id}')));
      await tester.pump();
      expect(set.completed, isTrue);
      expect(set.weight, 77.5);
      expect(set.reps, 5);
      expect(set.note, '窄握，最后两次速度变慢');
      final completedRow = tester.widget<AnimatedContainer>(
        find.byKey(Key('set-row-${set.id}')),
      );
      expect(
        (completedRow.decoration! as BoxDecoration).color,
        const Color(0xFFE6F5EC),
      );

      await tester.enterText(
        find.byKey(Key('weight-${set.id}-${set.weight}')),
        '82.5',
      );
      await tester.enterText(
        find.byKey(Key('reps-${set.id}-${set.reps}')),
        '7',
      );
      await tester.pump();
      expect(set.completed, isTrue);
      expect(set.weight, 82.5);
      expect(set.reps, 7);

      await tester.ensureVisible(
        find.byKey(Key('exercise-note-preview-${exercise.id}')),
      );
      await tester.tap(find.byKey(Key('exercise-note-preview-${exercise.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(Key('exercise-note-input-${exercise.id}')),
        '肩胛收紧，器械第 7 档',
      );
      await tester.tap(find.byKey(Key('exercise-note-save-${exercise.id}')));
      await tester.pumpAndSettle();
      expect(exercise.note, '肩胛收紧，器械第 7 档');
      expect(find.textContaining('器械第 7 档'), findsOneWidget);

      await tester.ensureVisible(find.byKey(Key('set-complete-${set.id}')));
      await tester.tap(find.byKey(Key('set-complete-${set.id}')));
      await tester.pump();
      expect(set.completed, isFalse);
      expect(set.weight, 82.5);
      expect(set.reps, 7);
      expect(set.note, '窄握，最后两次速度变慢');
      controller.finishWorkout();
      await tester.pump(const Duration(milliseconds: 900));
    },
  );

  testWidgets('routine cards expose details, one start action, and more menu', (
    tester,
  ) async {
    final controller = AppController();
    final source = controller.createWorkoutExercise('bench_press', 'fixture');
    controller.saveRoutineFromDraft('菜单测试', [source]);
    final routine = controller.routines.single;
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');

    expect(find.byKey(Key('routine-card-${routine.id}')), findsOneWidget);
    expect(find.byKey(Key('routine-start-${routine.id}')), findsOneWidget);
    expect(find.byKey(Key('routine-more-${routine.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('routine-card-${routine.id}')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('routine-detail-start-${routine.id}')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(Key('routine-detail-start-${routine.id}'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('routine-more-${routine.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('routine-edit-${routine.id}')), findsOneWidget);
    expect(find.byKey(Key('routine-rename-${routine.id}')), findsOneWidget);
    expect(find.byKey(Key('routine-delete-${routine.id}')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(Key('routine-edit-${routine.id}'))),
    ).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('record cards expose metrics and green structured set details', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '记录卡');
    controller.addExercise('bench_press');
    final exercise = controller.workout.single;
    controller.addSet(exercise);
    final set = exercise.sets.single
      ..weight = 50
      ..reps = 10
      ..note = '最后两次速度变慢'
      ..completed = true;
    controller.finishWorkout();
    final record = controller.history.single;
    addTearDown(controller.dispose);

    await tester.pumpWidget(KiloApp(initialController: controller));
    controller.selectPage(PageId.records);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('record-tile-${record.id}')),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(Key('record-tile-${record.id}')), findsOneWidget);
    expect(find.textContaining('500 kg'), findsOneWidget);
    await tester.tap(find.byKey(Key('record-tile-${record.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('record-detail-${record.id}')), findsOneWidget);
    expect(find.byKey(Key('record-set-row-${set.id}')), findsOneWidget);
    final detailRow = tester.widget<Container>(
      find.byKey(Key('record-set-row-${set.id}')),
    );
    expect(
      (detailRow.decoration! as BoxDecoration).color,
      const Color(0xFFE5F5EB),
    );
    expect(find.textContaining('50 kg'), findsWidgets);
    Navigator.of(
      tester.element(find.byKey(Key('record-detail-${record.id}'))),
    ).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('live set table stays within a 320dp viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    controller.startWorkout(name: 'compact table');
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    final set = controller.workout.single.sets.single;
    final rowSize = tester.getSize(find.byKey(Key('set-row-${set.id}')));
    expect(rowSize.width, lessThanOrEqualTo(304));
    expect(tester.takeException(), isNull);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets(
    '320dp at 200% text scale survives long plan and heavy set values',
    (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = AppController();
      final longName = '超长计划名称-${List<String>.filled(72, '压力').join()}';
      final source = controller.createWorkoutExercise('bench_press', 'stress');
      source.sets.first
        ..weight = 999.5
        ..reps = 100
        ..note = List<String>.filled(30, '长备注').join();
      controller.saveRoutineFromDraft(longName, [source]);
      final routine = controller.routines.single;
      controller.startRoutine(routine);
      final set = controller.workout.single.sets.first
        ..weight = 999.5
        ..reps = 100
        ..note = List<String>.filled(30, '长备注').join();
      addTearDown(() {
        if (controller.workoutStarted) controller.finishWorkout();
        controller.dispose();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: KiloApp(initialController: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const Key('live-workout'))),
        ).scale(1),
        2,
      );
      expect(find.text(longName), findsOneWidget);

      final completionKey = Key('set-complete-${set.id}');
      await tester.ensureVisible(find.byKey(completionKey));
      await tester.pumpAndSettle();
      expect(find.byKey(completionKey), findsOneWidget);
      expect(find.byKey(Key('set-note-preview-${set.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(completionKey));
      await tester.pump();
      expect(set.completed, isTrue);
      expect(tester.takeException(), isNull);

      controller.finishWorkout();
      await tester.pump(const Duration(milliseconds: 900));
    },
  );

  testWidgets(
    'exercise cover opens detail and switches overview teaching history',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(KiloApp(initialController: controller));
      await _openRoute(tester, '动作');
      await tester.enterText(find.byKey(const Key('exercise-search')), '卧推');
      await tester.pumpAndSettle();

      final cover = find.byKey(const Key('exercise-cover-bench_press'));
      expect(cover, findsOneWidget);
      await tester.tap(cover);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise-detail-sheet')), findsOneWidget);
      expect(
        find.byKey(const Key('exercise-detail-gif-bench_press')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exercise-detail-stats')), findsOneWidget);

      await tester.tap(find.text('教学').last);
      await tester.pumpAndSettle();
      expect(find.text('分步说明'), findsOneWidget);
      expect(find.text('现有动作提示'), findsOneWidget);

      await tester.tap(find.text('记录').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('还没有该动作的训练记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exercise detail history shows real completed sets', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '动作记录测试');
    controller.addExercise('bench_press');
    final workoutExercise = controller.workout.single;
    controller.addSet(workoutExercise);
    workoutExercise.sets.single
      ..weight = 72.5
      ..reps = 8
      ..note = '肩胛保持稳定'
      ..completed = true;
    controller.finishWorkout();
    final record = controller.history.single;
    addTearDown(controller.dispose);

    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '动作');
    await tester.enterText(find.byKey(const Key('exercise-search')), '卧推');
    await tester.pumpAndSettle();
    final cover = find.byKey(const Key('exercise-cover-bench_press'));
    await tester.tap(cover);
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录').last);
    await tester.pumpAndSettle();

    expect(find.byKey(Key('exercise-history-${record.id}')), findsOneWidget);
    expect(find.textContaining('72.5 kg × 8'), findsOneWidget);
    expect(find.textContaining('备注：肩胛保持稳定'), findsOneWidget);
    expect(find.text('训练次数'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
