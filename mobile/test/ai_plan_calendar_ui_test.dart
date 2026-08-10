import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';

AiPlanDraft _planFixture() => const AiPlanDraft(
  title: '今日练胸',
  weeks: 1,
  sessions: [
    AiPlanSession(
      dayOffset: 0,
      name: '胸部训练',
      exerciseIds: ['bench_press'],
      exercises: [
        AiPlanExerciseDraft(
          exerciseId: 'bench_press',
          sets: [
            AiPlanSetDraft(
              type: 'warmup',
              weight: 20,
              reps: 12,
              restSeconds: 60,
            ),
            AiPlanSetDraft(type: 'work', weight: 50, reps: 8, restSeconds: 120),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('AI plan detail exposes weight reps rest and references copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.chat.add(
      ChatMessage(
        id: 'answer',
        role: 'assistant',
        body: '计划已生成。',
        citations: const ['渐进超负荷指南 · https://example.test'],
        plan: _planFixture(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AiPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制全部'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();
    expect(find.text('训练计划详情'), findsOneWidget);
    expect(find.textContaining('50 kg × 8 次'), findsOneWidget);
    expect(find.text('休 120s'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.text('训练计划详情'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存并安排日历'));
    await tester.tap(find.text('保存并安排日历'));
    await tester.pumpAndSettle();
    expect(find.text('选择计划开始日期'), findsOneWidget);
    expect(find.text('安排到这天'), findsOneWidget);
  });

  testWidgets('calendar distinguishes scheduled body part and profile switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.schedule(DateTime.now(), '胸部训练');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecordsPage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('胸'), findsOneWidget);
    expect(find.text('已安排'), findsOneWidget);
    expect(find.text('当前选中'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilePage(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final notificationSwitch = tester.widget<Switch>(
      find.byKey(const Key('notification-feedback-switch')),
    );
    expect(notificationSwitch.value, isTrue);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(414, 1100);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: ProfilePage(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('notification-feedback-switch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
