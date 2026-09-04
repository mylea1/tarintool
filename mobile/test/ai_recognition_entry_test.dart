import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpAiPage(
  WidgetTester tester,
  AppController controller, {
  TextScaler? textScaler,
}) async {
  final app = MaterialApp(
    builder: (context, child) {
      if (textScaler == null) return child!;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      );
    },
    home: AiPage(controller: controller),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AI recognition entry opens the shared recognition flow', (
    tester,
  ) async {
    _setViewport(tester, 375);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.chat.add(
      ChatMessage(id: 'kept-chat', role: 'assistant', body: '保留这条对话'),
    );

    await _pumpAiPage(tester, controller);
    final input = find.byType(TextField);
    expect(input, findsOneWidget);
    await tester.enterText(input, '保留这段草稿');

    final entry = find.byKey(const Key('ai-top-navigation'));
    expect(entry, findsOneWidget);
    expect(tester.getRect(entry).right, lessThanOrEqualTo(375));
    await tester.tap(find.text('动作识别'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ai-recognition-route')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('动作识别')),
      findsOneWidget,
    );
    expect(find.text('识别动作'), findsOneWidget);
    expect(find.text('选择视频'), findsOneWidget);

    final picker = find.byKey(const Key('recognition-exercise-picker'));
    await tester.scrollUntilVisible(
      picker,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();

    final initialExerciseId = controller.recognitionExerciseId;
    final alternate = controller.recognitionCapabilities.firstWhere(
      (item) => item.exerciseId != initialExerciseId,
    );
    final alternateChoice = find.byKey(
      Key('recognition-exercise-${alternate.exerciseId}'),
    );
    await tester.scrollUntilVisible(
      alternateChoice,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(alternateChoice);
    await tester.pumpAndSettle();
    expect(controller.recognitionExerciseId, alternate.exerciseId);
    expect(
      find.text(
        controller.displayExerciseName(
          controller.exerciseFor(alternate.exerciseId),
        ),
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-page')), findsOneWidget);
    expect(find.text('保留这条对话'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '保留这段草稿',
    );
    expect(controller.recognitionExerciseId, alternate.exerciseId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI recognition entry fits at 320dp with 200 percent text', (
    tester,
  ) async {
    _setViewport(tester, 320);
    final controller = AppController();
    addTearDown(controller.dispose);

    await _pumpAiPage(
      tester,
      controller,
      textScaler: const TextScaler.linear(2),
    );
    final pageContext = tester.element(find.byKey(const Key('ai-page')));
    expect(MediaQuery.textScalerOf(pageContext).scale(1), closeTo(2, .001));
    final entry = find.byKey(const Key('ai-top-navigation'));
    expect(entry, findsOneWidget);
    final entryRect = tester.getRect(entry);
    expect(entryRect.left, greaterThanOrEqualTo(0));
    expect(entryRect.right, lessThanOrEqualTo(320));
    expect(entryRect.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
