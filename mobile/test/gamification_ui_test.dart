import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/gamification_ui.dart';

Widget _frame(Widget child, {required double width, double scale = 1}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(body: SafeArea(child: child)),
    ),
  );
}

void main() {
  for (final width in <double>[320, 375, 414]) {
    testWidgets('game layers fit ${width.toInt()}dp without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          SingleChildScrollView(child: HomeGameLayer(controller: controller)),
          width: width,
        ),
      );
      await tester.pump();
      expect(find.textContaining('训练者 Lv.'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _frame(WorldPage(controller: controller), width: width),
      );
      await tester.pump();
      expect(find.text('训练场'), findsOneWidget);
      expect(find.byKey(const Key('world-real-empty-state')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('profile game settings survive 320dp and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _frame(
        SingleChildScrollView(child: ProfileGameLayer(controller: controller)),
        width: 320,
        scale: 2,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('profile-character-card')), findsOneWidget);
    expect(find.text('身体成长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
