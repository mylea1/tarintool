import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/membership_ui.dart';

class _LongPricePurchaseCoordinator extends MembershipPurchaseCoordinator {
  _LongPricePurchaseCoordinator(super.controller);

  @override
  String priceFor(MembershipPlan plan) => switch (plan) {
    MembershipPlan.oneMonth => 'HK\$ 123,456.78',
    MembershipPlan.yearly => 'HK\$ 9,876,543.21',
    _ => super.priceFor(plan),
  };
}

void _setTestViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1;
}

void main() {
  testWidgets('membership plans share one row at 375dp and can switch', (
    tester,
  ) async {
    _setTestViewport(tester, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = AccountService()..loginWithPhone('13800138000');
    final controller = AppController(accountService: service);
    addTearDown(controller.dispose);

    // Prevent the widget test's default Android target from registering a
    // real billing bridge. Linux has no store implementation, so initialization
    // must take the unavailable/error path and leave purchasing disabled.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        MaterialApp(home: MembershipCenterPage(controller: controller)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    final comparison = find.byKey(const Key('membership-plan-comparison'));
    final monthly = find.byKey(const Key('membership-plan-oneMonth'));
    final yearly = find.byKey(const Key('membership-plan-yearly'));
    expect(comparison, findsOneWidget);
    expect(monthly, findsOneWidget);
    expect(yearly, findsOneWidget);

    final comparisonRect = tester.getRect(comparison);
    final monthlyRect = tester.getRect(monthly);
    final yearlyRect = tester.getRect(yearly);
    expect(monthlyRect.left, lessThan(yearlyRect.left));
    expect(monthlyRect.top, closeTo(yearlyRect.top, 1));
    expect(monthlyRect.right, lessThanOrEqualTo(comparisonRect.right + 1));
    expect(yearlyRect.right, lessThanOrEqualTo(comparisonRect.right + 1));
    expect(monthlyRect.height, inInclusiveRange(130.0, 190.0));
    expect(yearlyRect.height, inInclusiveRange(130.0, 190.0));
    expect(find.text('月度会员'), findsOneWidget);
    expect(find.text('年度会员'), findsOneWidget);
    expect(find.text('最受欢迎'), findsNothing);
    expect(find.text('完整 PRO 权益'), findsNothing);
    expect(find.text('适合先体验 AI 训练闭环'), findsNothing);
    expect(find.text('所有方案均解锁完整 PRO 能力，区别仅在订阅周期。'), findsNothing);
    expect(find.textContaining('付款由 App Store'), findsNothing);
    expect(find.text('部分会员商品尚未在商店启用。'), findsNothing);
    final purchaseButton = find.ancestor(
      of: find.text('购买 · ¥128'),
      matching: find.byType(FilledButton),
    );
    expect(purchaseButton, findsOneWidget);
    expect(tester.widget<FilledButton>(purchaseButton).onPressed, isNull);

    await tester.tap(monthly);
    await tester.pump();
    expect(find.text('购买 · ¥12'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow scaled comparison stacks long localized prices safely', (
    tester,
  ) async {
    _setTestViewport(tester, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = AccountService()..loginWithPhone('13800138001');
    final controller = AppController(accountService: service);
    addTearDown(controller.dispose);
    final purchase = _LongPricePurchaseCoordinator(controller);
    addTearDown(purchase.dispose);
    MembershipPlan? selected = MembershipPlan.oneMonth;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) => MembershipPlanComparison(
                selected: selected!,
                purchase: purchase,
                onSelected: (plan) => setState(() => selected = plan),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final comparison = find.byKey(const Key('membership-plan-comparison'));
    final monthly = find.byKey(const Key('membership-plan-oneMonth'));
    final yearly = find.byKey(const Key('membership-plan-yearly'));
    expect(comparison, findsOneWidget);
    expect(MediaQuery.textScalerOf(tester.element(comparison)).scale(1), 2);
    expect(monthly, findsOneWidget);
    expect(yearly, findsOneWidget);
    expect(find.text('HK\$ 123,456.78'), findsOneWidget);
    expect(find.text('HK\$ 9,876,543.21'), findsOneWidget);

    final comparisonRect = tester.getRect(comparison);
    final monthlyRect = tester.getRect(monthly);
    final yearlyRect = tester.getRect(yearly);
    expect(comparisonRect.right, lessThanOrEqualTo(320));
    expect(monthlyRect.right, lessThanOrEqualTo(comparisonRect.right + 1));
    expect(yearlyRect.right, lessThanOrEqualTo(comparisonRect.right + 1));
    expect(yearlyRect.top, greaterThan(monthlyRect.bottom));
    expect(tester.takeException(), isNull);

    await tester.tap(yearly);
    await tester.pump();
    expect(selected, MembershipPlan.yearly);
    expect(tester.takeException(), isNull);
  });

  test('unavailable App Store purchase gives explicit feedback', () async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final purchase = MembershipPurchaseCoordinator(controller);
    addTearDown(purchase.dispose);

    expect(await purchase.purchase(MembershipPlan.yearly), isFalse);
    expect(purchase.errorMessage, '该会员方案尚未在 App Store 配置完成。');
  });

  testWidgets('profile opens membership orders and returns', (tester) async {
    final service = AccountService()..loginWithPhone('13800138002');
    final controller = AppController(accountService: service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ProfilePage(controller: controller)),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('profile-orders-entry'));
    await tester.scrollUntilVisible(
      entry,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('会员订单'), findsOneWidget);
    expect(find.byType(MembershipOrdersPage), findsOneWidget);
    expect(find.text('还没有会员订单'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final order = controller.createMembershipOrder(
      plan: MembershipPlan.oneMonth,
      productId: membershipProductIds[MembershipPlan.oneMonth]!,
      displayPrice: '¥12',
      provider: MembershipOrderProvider.appStore,
    );
    expect(order, isNotNull);
    await tester.pump();
    expect(find.text('还没有会员订单'), findsNothing);
    expect(find.text('订单 ${order!.id}'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-orders-entry')), findsOneWidget);
    expect(find.text('会员订单'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
