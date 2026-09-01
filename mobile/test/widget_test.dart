import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/exercise_media.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/membership_ui.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/muscle_selector.dart';
import 'package:kilo_strength/recognition_api.dart';

Future<void> _openRoute(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('friend search remains usable at 320dp with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/v1/auth/phone/login' => {
            'session': {'token': 'friend-widget-session'},
          },
          '/v1/friends' => {'friends': [], 'pending': []},
          '/v1/friends/feed' => {'plans': []},
          '/v1/me/identities' => {
            'identities': [
              {'kind': 'username', 'value': 'test_lifter'},
            ],
          },
          '/v1/friends/search' => {
            'results': [
              {
                'id': 'usr_friend',
                'displayName': '训练伙伴',
                'username': 'gym_friend',
                'matchType': 'username',
                'maskedMatch': '@gym_friend',
                'relationshipStatus': 'none',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await api.signIn(identifier: '13800138000', password: '1234');
    final controller = AppController(coachApi: api);
    addTearDown(controller.dispose);
    expect(controller.loginWithPhone('123', password: '123').isSuccess, isTrue);
    controller.selectPage(PageId.profile);

    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-friends-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '用户名、手机号或邮箱'),
      'gym_',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('训练伙伴'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('membership center keeps plans and order entry usable at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = AccountService()..loginWithPhone('13800138000');
    final controller = AppController(accountService: account);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: MembershipCenterPage(controller: controller)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('会员中心'), findsOneWidget);
    expect(find.text('月度会员'), findsOneWidget);
    expect(find.text('年度会员'), findsOneWidget);
    expect(find.text('永久会员'), findsNothing);
    expect(find.text('订单'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('all reference exercise media assets load', () async {
    expect(catalog, hasLength(1324));
    expect(selectableCatalog, hasLength(catalog.length - 300));
    expect(
      selectableCatalog.every(
        (item) => !['波速球', '滑雪机', '训练锤'].any(
          (label) =>
              '${item.name}${item.equipment}${item.family}'.contains(label),
        ),
      ),
      isTrue,
    );
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

    expect(find.text('${selectableCatalog.length} 个动作'), findsOneWidget);
    expect(find.byKey(const Key('exercise-library-load-more')), findsOneWidget);
    expect(
      tester
          .widget<GridView>(find.byKey(const Key('exercise-library-grid')))
          .childrenDelegate
          .estimatedChildCount,
      60,
    );
    await tester.enterText(find.byKey(const Key('exercise-search')), '高位下拉');
    await tester.pumpAndSettle();

    final cover = find.byKey(const Key('exercise-cover-lat_pulldown'));
    expect(cover, findsOneWidget);
    await tester.ensureVisible(cover);
    await tester.pumpAndSettle();
    await tester.tap(cover);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('exercise-detail-gif-lat_pulldown')),
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
    expect(find.text('今日训练'), findsOneWidget);
    expect(find.text('本周训练'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('本周肌群'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('本周肌群'), findsOneWidget);
    expect(find.text('进步摘要'), findsNothing);
    expect(find.text('训练概览'), findsNothing);
    expect(find.text('实时训练'), findsNothing);
    expect(find.text('自由训练'), findsNothing);
    expect(find.byKey(const Key('home-trend-picker')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-ai-workout')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AI 定制训练'), findsOneWidget);
    expect(find.text('上肢力量 A'), findsNothing);
    expect(find.text('重置演示数据'), findsNothing);
    expect(controller.history, isEmpty);
    expect(controller.routines, isEmpty);
  });

  testWidgets('training profile onboarding keeps every field optional', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TrainingProfileOnboardingPage(controller: controller)),
    );
    expect(find.byKey(const Key('profile-onboarding-skip')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-onboarding-save')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-onboarding-save')));
    await tester.pump();
    expect(controller.profileOnboardingCompleted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile uses direct choices for goal and preferred weekdays', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TrainingProfileOnboardingPage(controller: controller)),
    );
    expect(find.text('增肌'), findsOneWidget);
    expect(find.text('减脂'), findsOneWidget);
    expect(find.text('塑形'), findsOneWidget);
    expect(find.text('保持体能'), findsNothing);
    expect(find.text('每周训练日（可多选）'), findsOneWidget);
    await tester.tap(find.text('塑形'));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    for (final weekday in [1, 3, 5, 7]) {
      await tester.tap(find.byKey(Key('preferred-weekday-$weekday')));
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-onboarding-save')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-onboarding-save')));
    await tester.pump();
    expect(controller.trainingProfile.goal, 'body_recomp');
    expect(controller.trainingProfile.weeklyTrainingDays, 4);
    expect(controller.trainingProfile.preferredWeekdays, [1, 3, 5, 7]);
  });

  testWidgets('home nutrition card records calories and protein', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-nutrition-card')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home-nutrition-card')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nutrition-journal-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nutrition-empty-add')));
    await tester.pumpAndSettle();
    expect(find.text('PRO 拍照识别'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nutrition-photo-picker')));
    await tester.pumpAndSettle();
    expect(find.text('拍照识别营养属于形域 PRO'), findsOneWidget);
    await tester.tap(find.text('暂不开通'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '食物名称 *'), '鸡胸肉');
    await tester.enterText(find.widgetWithText(TextField, '热量 kcal *'), '220');
    await tester.enterText(find.widgetWithText(TextField, '蛋白质 g'), '42');
    await tester.tap(find.byKey(const Key('nutrition-save')));
    await tester.pumpAndSettle();
    expect(controller.todayCalories, 220);
    expect(controller.todayProtein, 42);
  });

  testWidgets('advanced statistics stays locked and usable at 320dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordsPage(controller: controller)),
      ),
    );
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-analytics-locked')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('open-member-analytics-paywall')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-member-analytics-paywall')));
    await tester.pumpAndSettle();
    expect(find.text('进阶数据统计属于形域 PRO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('member analytics survives compact width and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final account = AccountService()..loginWithPhone('13800138001');
    account.replaceCurrentEntitlement(
      account.entitlements!.copyWith(
        membership: MembershipPlan.forever,
        clearMembershipExpiresAt: true,
      ),
    );
    final controller = AppController(accountService: account);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordsPage(controller: controller)),
      ),
    );
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('member-analytics-panel')), findsOneWidget);
    await tester.ensureVisible(find.text('训练 × 饮食时间轴'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('new plan composer stays compact at 320dp', (tester) async {
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
    await tester.tap(find.text('新建计划'));
    await tester.pumpAndSettle();
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('draft-name')),
    );
    expect(nameField.style?.fontSize, 20);
    await tester.tap(find.byKey(const Key('draft-add-exercise')));
    await tester.pumpAndSettle();
    final first = selectableCatalog.first;
    await tester.tap(find.byKey(Key('exercise-picker-add-${first.id}')));
    await tester.tap(find.byKey(const Key('exercise-picker-add-selected')));
    await tester.pumpAndSettle();
    expect(find.text(controller.displayExerciseName(first)), findsWidgets);
    expect(find.text('保存计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home exercise trend can switch between recorded exercises', (
    tester,
  ) async {
    final controller = AppController();
    controller.history.addAll([
      WorkoutRecord(
        id: 'recent',
        name: '上肢',
        date: DateTime.now(),
        startTime: '18:00',
        durationSeconds: 3600,
        volume: 4000,
        effectiveSets: 2,
        exerciseIds: const ['bench_press', 'lat_pulldown'],
        exercises: [
          WorkoutExercise(
            id: 'recent-bench',
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(
                id: 'recent-bench-set',
                weight: 82.5,
                reps: 6,
                completed: true,
              ),
            ],
          ),
          WorkoutExercise(
            id: 'recent-pulldown',
            exerciseId: 'lat_pulldown',
            sets: [
              WorkoutSet(
                id: 'recent-pulldown-set',
                weight: 65,
                reps: 10,
                completed: true,
              ),
            ],
          ),
        ],
      ),
      WorkoutRecord(
        id: 'older',
        name: '上肢',
        date: DateTime.now().subtract(const Duration(days: 7)),
        startTime: '18:00',
        durationSeconds: 3300,
        volume: 3600,
        effectiveSets: 2,
        exerciseIds: const ['bench_press', 'lat_pulldown'],
        exercises: [
          WorkoutExercise(
            id: 'older-bench',
            exerciseId: 'bench_press',
            sets: [
              WorkoutSet(
                id: 'older-bench-set',
                weight: 80,
                reps: 6,
                completed: true,
              ),
            ],
          ),
          WorkoutExercise(
            id: 'older-pulldown',
            exerciseId: 'lat_pulldown',
            sets: [
              WorkoutSet(
                id: 'older-pulldown-set',
                weight: 60,
                reps: 10,
                completed: true,
              ),
            ],
          ),
        ],
      ),
    ]);
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-trend-picker')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('杠铃卧推趋势'), findsOneWidget);
    expect(find.text('82.5 kg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-trend-picker')));
    await tester.pumpAndSettle();
    final pulldownOption = find.byKey(
      const Key('home-trend-option-lat_pulldown'),
    );
    await tester.ensureVisible(pulldownOption);
    await tester.tap(pulldownOption);
    await tester.pumpAndSettle();
    expect(find.textContaining('高位下拉'), findsOneWidget);
    expect(find.text('65.0 kg'), findsOneWidget);
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
    Map<dynamic, dynamic>? startTimerArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'startTimer') {
            startTimerArguments = call.arguments as Map<dynamic, dynamic>;
          }
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
    expect(startTimerArguments?['endsAtEpochMs'], isA<int>());
    expect(startTimerArguments?['endsAtEpochMs'], greaterThan(0));
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

  testWidgets('home muscle map uses source SVG and toggles its side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.pump();

    expect(find.byKey(const Key('home-muscle-map')), findsOneWidget);
    expect(find.byKey(const Key('interactive-muscle-map')), findsOneWidget);
    expect(find.bySemanticsLabel('正面人体图'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('背面人体图'));
    await tester.pump();
    expect(find.bySemanticsLabel('背面人体图'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source alpha mask keeps smallest-overlap priority', (
    tester,
  ) async {
    String? tappedMuscle;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: InteractiveMuscleMap(
                muscleSets: const {'胸': 4},
                height: 320,
                onMuscleTap: (value) => tappedMuscle = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final body = find.byKey(const Key('interactive-muscle-body'));
    final rect = tester.getRect(body);
    await tester.tapAt(
      Offset(
        rect.left + rect.width * (19.5 / 48),
        rect.top + rect.height * (16.5 / 88),
      ),
    );
    await tester.pump();
    expect(tappedMuscle, 'trapezius');
    expect(find.text('斜方肌'), findsOneWidget);
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

  testWidgets('exercise picker creates and selects a custom exercise', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    expect(controller.loginWithPhone('123', password: '123').isSuccess, isTrue);
    controller.startWorkout(name: '自由训练', autoStartTimer: false);
    controller.openLiveWorkout();
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('first-action-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-picker-create-custom')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('custom-exercise-name')),
      '自定义肩部动作',
    );
    await tester.enterText(
      find.byKey(const Key('custom-exercise-muscle')),
      '三角肌',
    );
    await tester.tap(find.byKey(const Key('custom-exercise-save')));
    await tester.pumpAndSettle();

    expect(controller.customExercises.single.name, '自定义肩部动作');
    expect(find.text('添加 1 个动作'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exercise-picker-add-selected')));
    await tester.pumpAndSettle();
    expect(
      controller.workout.single.exerciseId,
      controller.customExercises.single.id,
    );
    expect(find.text('自定义肩部动作'), findsOneWidget);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets(
    'recognition result shows detailed time evidence without system status panels',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.recognitionStatus = RecognitionStatus.complete;
      controller.recognitionResult = const RecognitionResult(
        status: RecognitionStatus.complete,
        confidence: .88,
        repetitions: 8,
        summary: '骨骼识别完成',
        metrics: {
          'durationSeconds': 18.6,
          'detectionRate': .9,
          'outputWidth': 720,
          'outputHeight': 1280,
        },
        events: [
          RecognitionEvent(
            id: 'event-001',
            code: 'LAT_PULLDOWN_RANGE_INCOMPLETE',
            label: '高位下拉行程可能不足',
            startMs: 11800,
            peakMs: 12400,
            endMs: 13000,
            displayTime: '00:12.4',
            explanation: '可见侧肘角没有稳定覆盖当前参考范围。',
            confidence: .86,
            evidenceImageUrl: 'http://127.0.0.1:1/evidence-124.jpg',
          ),
          RecognitionEvent(
            id: 'event-002',
            code: 'LAT_PULLDOWN_ELBOW_PATH_LIMITED',
            label: '肘部向下移动不明显',
            startMs: 15900,
            peakMs: 16800,
            endMs: 17700,
            displayTime: '00:16.8',
            explanation: '肘部向下移动的距离低于当前参考线。',
            confidence: .84,
            evidenceImageUrl: 'http://127.0.0.1:1/evidence-168.jpg',
          ),
          RecognitionEvent(
            id: 'event-003',
            code: 'LAT_PULLDOWN_RANGE_INCOMPLETE',
            label: '高位下拉行程可能不足',
            startMs: 15900,
            peakMs: 16800,
            endMs: 17700,
            displayTime: '00:16.8',
            explanation: '最低位置的肘角仍偏大。',
            confidence: .82,
            evidenceImageUrl: 'http://127.0.0.1:1/evidence-168-b.jpg',
          ),
        ],
        aiReview: RecognitionAiReview(
          headline: '整体轨迹稳定',
          strengths: ['动作节奏一致'],
          risks: ['末端控制可加强'],
          nextSet: '保持重量并减慢离心',
          basis: '视频时间事件与骨骼关键点轨迹',
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: KiloApp(initialController: controller),
        ),
      );
      await _openRoute(tester, 'AI');
      await tester.tap(find.byKey(const Key('ai-recognition')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('recognition-open-result')),
      );
      await tester.tap(find.byKey(const Key('recognition-open-result')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recognition-result-page')), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-coach-summary')),
        findsOneWidget,
      );
      expect(find.textContaining('整体轨迹稳定'), findsOneWidget);
      expect(find.textContaining('保持重量并减慢离心'), findsOneWidget);
      expect(find.text('00:12.4'), findsWidgets);
      expect(find.textContaining('00:12.4、00:16.8 附近'), findsOneWidget);
      expect(find.textContaining('00:16.8 附近'), findsOneWidget);
      expect(find.text('系统看到了什么'), findsNothing);
      expect(find.text('这意味着什么'), findsNothing);
      expect(find.text('下一组这样调整'), findsNothing);
      expect(find.text('本组建议'), findsNothing);
      expect(find.textContaining('实际移动距离偏短'), findsOneWidget);
      expect(find.textContaining('整体有劲'), findsNothing);
      expect(find.textContaining('抢跑'), findsNothing);
      expect(find.textContaining('拖泥带水'), findsNothing);
      expect(find.textContaining('稳定复现的完整范围'), findsNothing);
      expect(find.textContaining('完成 8 次'), findsNothing);
      expect(find.textContaining('目标锁定'), findsNothing);
      expect(find.textContaining('骨骼追踪'), findsNothing);
      expect(find.textContaining('个时间提示'), findsNothing);
      expect(find.textContaining('播放骨骼证据'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('recognition-result-page')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recognition-evidence-gallery')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('recognition-evidence-gallery')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('recognition-coach-summary')))
              .dy,
        ),
      );
      expect(
        find.byKey(const Key('recognition-evidence-00:12.4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-evidence-00:16.8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-evidence-00:16.8-b')),
        findsNothing,
      );
      final evidenceImages = tester.widgetList<Image>(
        find.descendant(
          of: find.byKey(const Key('recognition-evidence-gallery')),
          matching: find.byType(Image),
        ),
      );
      expect(evidenceImages, isNotEmpty);
      expect(
        evidenceImages.every((image) => image.fit == BoxFit.contain),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completed report shows only the requested skeleton video', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.selectedMediaPath = 'missing-original.mp4';
    controller.selectedMediaName = '原视频.mp4';
    controller.recognitionIncludeOverlay = true;
    controller.recognitionStatus = RecognitionStatus.complete;
    controller.recognitionResult = const RecognitionResult(
      status: RecognitionStatus.complete,
      confidence: .32,
      repetitions: 6,
      summary: '内部结果',
      overlayUrl: 'http://127.0.0.1:1/overlay.mp4',
    );
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, 'AI');
    await tester.tap(find.byKey(const Key('ai-recognition')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const Key('recognition-open-result')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recognition-open-result')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recognition-result-original-video')),
      findsNothing,
    );
    expect(find.byKey(const Key('recognition-evidence-hero')), findsNothing);
    expect(find.byKey(const Key('recognition-coach-summary')), findsOneWidget);
    expect(find.byKey(const Key('recognition-overlay-video')), findsOneWidget);
    expect(find.textContaining('播放骨骼证据'), findsNothing);
    expect(find.textContaining('完整骨骼视频'), findsNothing);
    expect(find.textContaining('置信'), findsNothing);
    expect(find.textContaining('算法'), findsNothing);
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
      expect(find.byKey(const Key('recognition-edit-video')), findsOneWidget);
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

  testWidgets('active rest card edits current and upcoming rest defaults', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '休息继承');
    controller.addExercise('bench_press');
    controller.addExercise('squat');
    controller.addSet(controller.workout.first);
    controller.addSet(controller.workout.last);
    controller.openLiveWorkout();
    controller.startRest(exercise: '器械推胸', seconds: 53);
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });

    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.tap(find.byKey(const Key('rest-edit-default-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('active-rest-quick-90')));
    await tester.tap(find.byKey(const Key('active-rest-save-button')));
    await tester.pumpAndSettle();

    expect(controller.restRemainingSeconds, 90);
    expect(controller.defaultRestSeconds, 90);
    expect(controller.workout.last.restSeconds, 90);
    expect(controller.workout.last.sets.single.restSeconds, 90);
    controller.skipRest();
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
    // AI plan customization belongs to the training landing page, not the
    // focused live-workout controls.
    controller.startWorkout(name: '自由训练', autoStartTimer: false);
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    expect(find.byKey(const Key('live-workout-controls')), findsOneWidget);
    expect(find.byKey(const Key('start-workout-timer-button')), findsOneWidget);
    expect(find.byKey(const Key('workout-rest-button')), findsOneWidget);
    expect(find.byKey(const Key('ai-customize-workout-button')), findsNothing);
    expect(find.byKey(const Key('workout-batch-button')), findsNothing);
    expect(find.byKey(const Key('plate-calculator-button')), findsNothing);
    expect(find.byKey(const Key('workout-settings-button')), findsNothing);
    expect(find.text('已完成 0/1 组'), findsNothing);
    expect(find.text('先检查动作，再开始计时'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('start-workout-timer-button')));
    await tester.pump();
    expect(controller.workoutTimerStarted, isTrue);
    expect(tester.takeException(), isNull);
    controller.finishWorkout();
    await tester.pump();
  });

  testWidgets('AI workout planner is exposed on training landing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TrainPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('free-workout-button')), findsOneWidget);
    expect(find.byKey(const Key('ai-customize-plan-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('free workout thumbnail opens details and note capture is gone', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(() {
      if (controller.workoutStarted) controller.finishWorkout();
      controller.dispose();
    });
    await tester.pumpWidget(KiloApp(initialController: controller));
    await _openRoute(tester, '训练');
    expect(
      find.byKey(const Key('natural-workout-capture-button')),
      findsNothing,
    );

    controller.startWorkout(name: '自由训练', autoStartTimer: false);
    controller.addExercise('bench_press');
    final exercise = controller.workout.single;
    controller.addSet(exercise);
    controller.openLiveWorkout();
    await tester.pumpAndSettle();

    final thumbnail = find.byKey(Key('exercise-thumbnail-${exercise.id}'));
    expect(thumbnail, findsOneWidget);
    await tester.ensureVisible(thumbnail);
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('exercise-detail-gif-bench_press')),
      findsOneWidget,
    );
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
      controller.updateExerciseRest(exercise, 180);
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

  testWidgets('active workout has a separate hold-to-abort path', (
    tester,
  ) async {
    final controller = AppController();
    controller.startWorkout(name: '可中止训练');
    controller.addExercise('bench_press');
    controller.addSet(controller.workout.single);
    controller.openLiveWorkout();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.scrollUntilVisible(
      find.byKey(const Key('abort-workout-button')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('abort-workout-button')));
    await tester.pumpAndSettle();

    expect(find.text('长按中止，不保存记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hold-to-abort-workout')));
    await tester.pump();
    expect(controller.workoutStarted, isTrue);
    await tester.longPress(find.byKey(const Key('hold-to-abort-workout')));
    await tester.pumpAndSettle();

    expect(controller.workoutStarted, isFalse);
    expect(controller.history, isEmpty);
    expect(controller.workout, isEmpty);
  });

  testWidgets('sent AI message is selectable without a redundant copy action', (
    tester,
  ) async {
    final controller = AppController();
    controller.chat.add(
      ChatMessage(id: 'copy-me', role: 'user', body: '请评价昨天的胸部训练'),
    );
    controller.selectPage(PageId.ai);
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.pumpAndSettle();

    expect(find.text('请评价昨天的胸部训练'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
    expect(find.byKey(const Key('copy-chat-message-copy-me')), findsNothing);
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
      controller.updateExerciseRest(exercise, 90);
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

      final weightField = find.byKey(Key('weight-${set.id}'));
      await tester.tap(weightField);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '8',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      controller.refresh();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.byKey(Key('weight-${set.id}')), findsOneWidget);
      await tester.enterText(weightField, '82.5');
      await tester.enterText(find.byKey(Key('reps-${set.id}')), '7');
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
    expect(find.textContaining('组备注 · 肩胛保持稳定'), findsOneWidget);
    expect(find.text('训练次数'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
