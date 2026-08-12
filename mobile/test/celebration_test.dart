import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';

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
    final controller = AppController();
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
    expect(find.textContaining('kg ×'), findsWidgets);
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
    expect(find.text('有效组数'), findsOneWidget);
    expect(find.text('主要肌群'), findsOneWidget);
    expect(find.text('本次 PR'), findsOneWidget);
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
}
