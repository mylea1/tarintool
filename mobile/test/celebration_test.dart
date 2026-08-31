import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';

class _CountingCoachApi implements CoachApi {
  int calls = 0;

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? conversationId,
  }) async {
    calls++;
    return const CoachAnswer(body: '这段内容不应为非会员生成');
  }
}

Future<void> _openCelebration(
  WidgetTester tester,
  AppController controller, {
  required bool reducedMotion,
  Size viewport = const Size(800, 1000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  controller.startWorkout(name: '粒子测试');
  controller.addExercise('bench_press');
  controller.addSet(controller.workout.single);
  controller.openLiveWorkout();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: KiloApp(initialController: controller),
    ),
  );
  await tester.scrollUntilVisible(
    find.byKey(const Key('finish-workout-button')),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  if (viewport.width <= 320 && textScale > 1) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const Key('finish-workout-button')));
  await tester.tap(find.byKey(const Key('finish-workout-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('finish-save-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('celebration renders one-shot particles in normal motion', (
    tester,
  ) async {
    final coachApi = _CountingCoachApi();
    final controller = AppController(coachApi: coachApi);
    addTearDown(controller.dispose);
    await _openCelebration(tester, controller, reducedMotion: false);
    expect(find.byKey(const Key('workout-celebration')), findsOneWidget);
    expect(find.byKey(const Key('summary-particles')), findsOneWidget);
    expect(find.byKey(const Key('summary-card-0')), findsOneWidget);
    expect(
      find.byKey(const Key('workout-celebration-exercises')),
      findsOneWidget,
    );
    expect(find.text('杠铃卧推'), findsWidgets);
    expect(find.textContaining('kg ×'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('workout-celebration-exercise-details-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('workout-celebration-exercise-details-0')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('kg ×'), findsWidgets);
    expect(
      find.byKey(const Key('workout-completion-ai-review-locked')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workout-ai-locked-blurred-preview')),
      findsOneWidget,
    );
    expect(coachApi.calls, 0);
  });

  testWidgets('celebration scrolls safely at 320dp and 200% text', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await _openCelebration(
      tester,
      controller,
      reducedMotion: false,
      viewport: const Size(320, 812),
      textScale: 2,
    );
    expect(find.text('训练时长'), findsOneWidget);
    expect(find.text('训练容量'), findsOneWidget);
    expect(find.text('完成组'), findsOneWidget);
    expect(find.text('本次 PR'), findsNothing);
    expect(
      find.byKey(const Key('workout-celebration-records')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('workout-celebration-done')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('celebration is static and omits particles with reduced motion', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await _openCelebration(tester, controller, reducedMotion: true);
    expect(find.byKey(const Key('workout-celebration')), findsOneWidget);
    expect(find.byKey(const Key('summary-particles')), findsNothing);
    expect(find.byKey(const Key('workout-celebration-burst')), findsOneWidget);
  });

  testWidgets('share card is a separate poster without AI review content', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await _openCelebration(tester, controller, reducedMotion: true);
    final shareButton = find.byKey(const Key('workout-celebration-share'));
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('workout-share-card'));
    expect(card, findsOneWidget);
    expect(
      find.byKey(const Key('workout-share-system-button')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('AI 训练评价')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('KILOSTRENGTH')),
      findsOneWidget,
    );
  });
}
