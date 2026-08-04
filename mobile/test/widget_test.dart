import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilo_strength/main.dart';

Future<void> _openRoute(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('KILO shell exposes five primary destinations', (tester) async {
    await tester.pumpWidget(const KiloApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('主页'), findsWidgets);
    expect(find.text('训练'), findsWidgets);
    expect(find.text('动作'), findsWidgets);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('记录'), findsNothing);
    expect(find.text('识别'), findsNothing);
  });

  testWidgets('training and AI top tabs expose merged routes', (tester) async {
    await tester.pumpWidget(const KiloApp());
    await _openRoute(tester, '训练');
    expect(find.byKey(const Key('train-top-tabs')), findsOneWidget);
    expect(find.text('我的计划'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('train-top-tabs')),
        matching: find.text('记录'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-day-2026-08-03')), findsOneWidget);
    await tester.tap(find.text('计划').last);
    await tester.pumpAndSettle();

    await _openRoute(tester, 'AI');
    expect(find.byKey(const Key('ai-top-tabs')), findsOneWidget);
    await tester.tap(find.text('动作识别').last);
    await tester.pumpAndSettle();
    expect(find.text('动作识别'), findsWidgets);
    await tester.tap(find.text('问答').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-drawer')), findsOneWidget);
  });

  testWidgets('official plans open a list then a single-day detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(414, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const KiloApp());
    await _openRoute(tester, '训练');
    await tester.ensureVisible(find.byKey(const Key('official-plans-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('official-plans-entry')));
    await tester.pumpAndSettle();
    expect(find.text('官方单日计划'), findsOneWidget);
    expect(
      find.byKey(const Key('official-plan-upper-lower-4')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('official-plan-upper-lower-4')));
    await tester.pumpAndSettle();
    expect(find.text('单日训练详情'), findsOneWidget);
    expect(find.text('杠铃卧推'), findsOneWidget);
    expect(find.text('使用此计划'), findsOneWidget);
    expect(find.text('开始训练'), findsOneWidget);
    expect(find.textContaining('组间休息'), findsWidgets);
  });

  testWidgets('history shows three items, all history, and set detail', (
    tester,
  ) async {
    await tester.pumpWidget(const KiloApp());
    await _openRoute(tester, '训练');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('train-top-tabs')),
        matching: find.text('记录'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('最近训练'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('最近训练'), findsOneWidget);
    for (final id in ['history-0801', 'history-0730']) {
      expect(find.byKey(Key('record-tile-$id')), findsOneWidget);
    }
    await tester.tap(find.text('查看全部').last);
    await tester.pumpAndSettle();
    expect(find.text('全部训练历史'), findsOneWidget);
    expect(find.byKey(const Key('record-tile-history-0801')), findsWidgets);
    expect(find.byKey(const Key('record-tile-history-0730')), findsWidgets);
    expect(find.byKey(const Key('record-tile-history-0724')), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-tile-history-0801')).last);
    await tester.pumpAndSettle();
    expect(find.text('动作与每组数据'), findsOneWidget);
    expect(find.textContaining('正式组'), findsWidgets);
    expect(find.textContaining('休息'), findsWidgets);
  });

  testWidgets('home progress opens chart and interpretable metrics', (
    tester,
  ) async {
    await tester.pumpWidget(const KiloApp());
    await tester.scrollUntilVisible(
      find.text('全部趋势'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('全部趋势'));
    await tester.pumpAndSettle();
    expect(find.text('进步分析'), findsOneWidget);
    expect(find.byKey(const Key('progress-trend-chart')), findsOneWidget);
    expect(find.text('训练量趋势'), findsOneWidget);
    expect(find.text('关键动作表现'), findsOneWidget);
    expect(find.text('有效组'), findsOneWidget);
    expect(find.text('记录变化'), findsOneWidget);
  });

  testWidgets('new training has explicit save feedback', (tester) async {
    await tester.pumpWidget(const KiloApp());
    await _openRoute(tester, '训练');
    await tester.tap(find.text('新建计划').last);
    await tester.pumpAndSettle();
    expect(find.text('新建训练'), findsOneWidget);
    await tester.tap(find.byKey(const Key('template-save-button')));
    await tester.pumpAndSettle();
    expect(find.text('训练已保存'), findsOneWidget);
  });

  testWidgets('calendar remains available from the training record tab', (
    tester,
  ) async {
    await tester.pumpWidget(const KiloApp());
    await _openRoute(tester, '训练');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('train-top-tabs')),
        matching: find.text('记录'),
      ),
    );
    await tester.pumpAndSettle();
    final cell = find.byKey(const Key('calendar-day-2026-08-03'));
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.text('日期详情'), findsOneWidget);
    expect(find.textContaining('安排训练'), findsOneWidget);
  });

  testWidgets('five routes render at 320/375/414 with 200% text', (
    tester,
  ) async {
    for (final width in [320.0, 375.0, 414.0]) {
      tester.view.physicalSize = Size(width, 812);
      tester.view.devicePixelRatio = 1;
      tester.view.platformDispatcher.textScaleFactorTestValue = 2.0;
      await tester.pumpWidget(const KiloApp());
      await tester.pumpAndSettle();
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'route $index should not throw at $width px / 200% text',
        );
      }
      await _openRoute(tester, '训练');
      await tester.scrollUntilVisible(
        find.byKey(const Key('routine-edit-routine-upper-a')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('routine-edit-routine-upper-a')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('template-editor-save-button')));
      await tester.pumpAndSettle();
    }
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.platformDispatcher.clearTextScaleFactorTestValue();
    });
  });
}
