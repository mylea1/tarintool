import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/account_settings_page.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/membership_ui.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Apple targets hide manual grants and reject redemption independently of host OS',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = AccountService(
        persistence: InMemoryAccountPersistence(),
        allowTestAdmin: true,
      )..loginWithPhone('1234', password: '1234');
      final controller = AppController(accountService: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(KiloApp(initialController: controller));
      controller.selectPage(PageId.profile);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-membership-card')), findsOneWidget);
      expect(
        find.byKey(const Key('admin-grant-membership-button')),
        findsNothing,
      );
      expect(find.byKey(const Key('admin-generate-code-button')), findsNothing);
      final result = await controller.redeemCode('EXAMPLE');
      expect(result.isSuccess, isFalse);
      expect(result.message, '请通过 App Store 管理订阅。');
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS}),
  );
  test('StoreKit product IDs match App Store Connect', () {
    expect(membershipProductIds[MembershipPlan.oneMonth], '11');
    expect(membershipProductIds[MembershipPlan.yearly], '33');
  });
  test('deletion removes local account instead of only logging out', () {
    final persistence = InMemoryAccountPersistence();
    final service = AccountService(persistence: persistence)
      ..loginWithPhone('13800138000');
    final id = service.currentUser!.id;
    service.deleteCurrentAccount();
    expect(service.currentUser, isNull);
    expect((persistence.read()!['users'] as Map).containsKey(id), false);
  });
  testWidgets(
    'account deletion requires confirmation and cancel keeps account',
    (tester) async {
      final service = AccountService()..loginWithPhone('13800138000');
      final controller = AppController(accountService: service);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(home: AccountSettingsPage(controller: controller)),
      );
      await tester.tap(find.byKey(const Key('delete-account-entry')));
      await tester.pumpAndSettle();
      expect(find.text('永久删除账号？'), findsOneWidget);
      await tester.tap(find.text('保留账号'));
      await tester.pumpAndSettle();
      expect(service.currentUser, isNotNull);
      expect(find.text('账号已删除'), findsNothing);
    },
  );
}
