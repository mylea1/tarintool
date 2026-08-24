import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';

void main() {
  testWidgets('default app starts at login root', (tester) async {
    await tester.pumpWidget(const KiloApp());
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('formal login authenticates with backend and has no shortcuts', (
    tester,
  ) async {
    final service = AccountService(allowTestAdmin: true);
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/auth/phone/login');
        return http.Response(
          jsonEncode({
            'user': {
              'identifier': '1234',
              'displayName': '正式管理员',
              'role': 'admin',
            },
            'session': {'token': 'signed-session'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final controller = AppController(accountService: service, coachApi: api);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(controller: controller)),
    );
    expect(
      find.byKey(const Key('login-test-account-fill-button')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('login-member-account-fill-button')),
      findsNothing,
    );
    await tester.enterText(find.byKey(const Key('login-identifier')), '1234');
    await tester.enterText(find.byKey(const Key('login-password')), '1234');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(service.isAdmin, isTrue);
    expect(service.entitlements?.membership, MembershipPlan.forever);
  });

  testWidgets('formal login stays usable on a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final service = AccountService(allowTestAdmin: true);
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'user': {
              'identifier': '17880169489',
              'displayName': '普通用户',
              'role': 'user',
            },
            'session': {'token': 'signed-session'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final controller = AppController(accountService: service, coachApi: api);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(home: LoginPage(controller: controller)),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login-identifier')),
      '17880169489',
    );
    await tester.enterText(find.byKey(const Key('login-password')), '1234');
    await tester.ensureVisible(find.byKey(const Key('login-button')));
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();

    expect(service.currentUser?.identifier, '17880169489');
    expect(service.isAdmin, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disabled test account hides the shortcut and rejects credentials',
    (tester) async {
      final service = AccountService(allowTestAdmin: false);
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: MockClient(
          (request) async =>
              http.Response(jsonEncode({'error': 'invalid_credentials'}), 401),
        ),
      );
      final controller = AppController(accountService: service, coachApi: api);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: LoginPage(controller: controller)),
      );
      expect(
        find.byKey(const Key('login-test-account-fill-button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('login-member-account-fill-button')),
        findsNothing,
      );

      await tester.enterText(find.byKey(const Key('login-identifier')), '1234');
      await tester.enterText(find.byKey(const Key('login-password')), '1234');
      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pumpAndSettle();
      expect(service.currentUser, isNull);
      expect(find.text('账号或密码不正确。'), findsOneWidget);
    },
  );

  testWidgets('admin membership card survives compact width and text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final service = AccountService(allowTestAdmin: true);
    final controller = AppController(accountService: service);
    addTearDown(controller.dispose);
    service.loginWithPhone('1234', password: '1234');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: KiloApp(initialController: controller),
      ),
    );
    controller.selectPage(PageId.profile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-membership-card')), findsOneWidget);
    expect(
      find.byKey(const Key('admin-grant-membership-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('admin-generate-code-button')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('admin-create-user-button')),
    );
    await tester.tap(find.byKey(const Key('admin-create-user-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-create-user-phone')), findsOneWidget);
    expect(find.byKey(const Key('admin-create-user-password')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('test admin is explicitly gated and release default is safe', () {
    final disabled = AccountService(allowTestAdmin: false);
    expect(
      disabled.loginWithPhone('1234', password: '1234').error,
      AccountError.invalidCredentials,
    );

    final enabled = AccountService(allowTestAdmin: true);
    final result = enabled.loginWithPhone('1234', password: '1234');
    expect(result.isSuccess, isTrue);
    expect(enabled.isAdmin, isTrue);
    expect(enabled.entitlements?.membership, MembershipPlan.forever);
    expect(enabled.aiRemaining, 20);
    expect(enabled.entitlements?.recognitionWeeklyGrant, 3);
  });

  test('normal test account is a permanent member without admin rights', () {
    final disabled = AccountService(allowTestAdmin: false);
    expect(
      disabled.loginWithPhone('123', password: '123').error,
      AccountError.invalidCredentials,
    );

    final enabled = AccountService(allowTestAdmin: true);
    final result = enabled.loginWithPhone('123', password: '123');
    expect(result.isSuccess, isTrue);
    expect(enabled.isAdmin, isFalse);
    expect(enabled.currentUser?.displayName, '普通体验用户');
    expect(enabled.entitlements?.membership, MembershipPlan.forever);
    expect(enabled.entitlements?.membershipExpiresAt, isNull);
    expect(enabled.aiRemaining, 20);
    expect(enabled.recognitionRemaining, 5);
    expect(enabled.entitlements?.recognitionWeeklyGrant, 3);
  });

  test('test administrator quota reservations stay unlimited locally', () {
    final service = AccountService(allowTestAdmin: true);
    service.loginWithPhone('1234', password: '1234');
    for (var index = 0; index < 30; index++) {
      final ai = service.reserveAi();
      final recognition = service.reserveRecognition();
      expect(ai, isNotNull);
      expect(recognition, isNotNull);
      ai!.commit();
      recognition!.commit();
    }
    expect(service.aiRemaining, 20);
    expect(service.recognitionRemaining, 5);
  });

  test('quota reservation commits and rolls back without losing credits', () {
    final service = AccountService();
    expect(service.loginWithPhone('13800138000').isSuccess, isTrue);
    expect(service.aiRemaining, 3);

    final rollback = service.reserveAi();
    expect(rollback, isNotNull);
    expect(service.aiRemaining, 2);
    rollback!.rollback();
    expect(service.aiRemaining, 3);

    final commit = service.reserveRecognition();
    expect(commit, isNotNull);
    commit!.commit();
    expect(service.recognitionRemaining, 4);
  });

  test(
    'reservation rollback returns credit to the reserving user after switch',
    () {
      final service = AccountService();
      service.loginWithPhone('13800138010');
      final reservation = service.reserveAi()!;
      expect(service.aiRemaining, 2);
      service.loginWithPhone('13800138011');
      expect(service.aiRemaining, 3);
      reservation.rollback();
      expect(service.aiRemaining, 3);
      service.loginWithPhone('13800138010');
      expect(service.aiRemaining, 3);
    },
  );

  test('remote quota helper rolls back on failure', () async {
    final service = AccountService();
    service.loginWithPhone('13800138001');
    await expectLater(
      service.runWithQuota(UsageKind.ai, () async {
        throw StateError('upstream');
      }),
      throwsStateError,
    );
    expect(service.aiRemaining, 3);
    await expectLater(
      service.runWithQuota(UsageKind.recognition, () async {
        throw StateError('recognition_upstream');
      }),
      throwsStateError,
    );
    expect(service.recognitionRemaining, 5);
  });

  test(
    'controller does not charge AI when the configured request fails',
    () async {
      final service = AccountService();
      final controller = AppController(
        accountService: service,
        coachApi: _ThrowingCoachApi(),
      );
      addTearDown(controller.dispose);
      service.loginWithPhone('13800138002');
      await controller.sendChat('test');
      expect(service.aiRemaining, 3);
    },
  );

  test(
    'free quota exhaustion explains membership upgrade instead of failure',
    () async {
      final service = AccountService();
      final controller = AppController(
        accountService: service,
        coachApi: _ThrowingCoachApi(),
      );
      addTearDown(controller.dispose);
      service.loginWithPhone('13800138003');
      for (var index = 0; index < 3; index++) {
        expect(service.consumeAi(), isTrue);
      }

      await controller.sendChat('请评价训练');

      expect(controller.chat.last.body, contains('免费 AI 次数已用完'));
      expect(controller.chat.last.body, contains('开通会员'));
    },
  );

  test('free recognition exhaustion explains membership upgrade', () async {
    final service = AccountService();
    final controller = AppController(
      accountService: service,
      recognitionApi: UnconfiguredRecognitionApi(),
    );
    addTearDown(controller.dispose);
    service.loginWithPhone('13800138004');
    for (var index = 0; index < 5; index++) {
      expect(service.consumeRecognition(), isTrue);
    }
    controller.selectedMediaPath = 'quota-check.mp4';
    controller.recognitionStatus = RecognitionStatus.ready;

    controller.startRecognition();
    await Future<void>.delayed(Duration.zero);

    expect(controller.recognitionResult?.summary, contains('免费动作识别次数已用完'));
    expect(controller.recognitionResult?.summary, contains('开通会员'));
  });

  test('AI daily reset and recognition weekly refill follow the clock', () {
    var now = DateTime(2026, 8, 6, 12);
    final service = AccountService(clock: () => now);
    service.loginWithPhone('13900139000');
    for (var i = 0; i < 3; i++) {
      expect(service.consumeAi(), isTrue);
    }
    expect(service.consumeAi(), isFalse);
    now = now.add(const Duration(days: 1));
    expect(service.aiRemaining, 3);

    for (var i = 0; i < 3; i++) {
      expect(service.consumeRecognition(), isTrue);
    }
    now = now.add(const Duration(days: 7));
    expect(service.recognitionRemaining, 3);
  });

  test('valid workout reward is idempotent', () {
    final service = AccountService();
    service.loginWithPhone('13700137000');
    expect(service.recognitionRemaining, 5);
    expect(service.rewardWorkoutCompleted('history-1'), isTrue);
    expect(service.recognitionRemaining, 6);
    expect(service.rewardWorkoutCompleted('history-1'), isFalse);
    expect(service.recognitionRemaining, 6);
    expect(service.rewardWorkoutCompleted('empty', valid: false), isFalse);
  });

  test('redemption code is one-time and admin operations are protected', () {
    final service = AccountService(allowTestAdmin: true);
    service.loginWithPhone('1234', password: '1234');
    final code = service.generateRedemptionCode(
      plan: MembershipPlan.threeMonths,
    );
    expect(
      service
          .grantMembership(identifier: '', plan: MembershipPlan.oneMonth)
          .error,
      AccountError.emptyIdentifier,
    );

    service.loginWithPhone('13600136000');
    final redeemed = service.redeemCode(code.code);
    expect(redeemed.isSuccess, isTrue);
    expect(service.entitlements?.membership, MembershipPlan.threeMonths);
    expect(service.redeemCode(code.code).error, AccountError.codeAlreadyUsed);

    final regular = AccountService();
    regular.loginWithPhone('13500135000');
    expect(
      regular
          .grantMembership(identifier: 'someone', plan: MembershipPlan.oneMonth)
          .error,
      AccountError.adminRequired,
    );
    expect(
      () => regular.generateRedemptionCode(plan: MembershipPlan.oneMonth),
      throwsStateError,
    );
  });

  test('redemption extends the later expiry and never downgrades forever', () {
    var now = DateTime(2026, 1, 15, 9);
    final service = AccountService(allowTestAdmin: true, clock: () => now);
    service.loginWithPhone('1234', password: '1234');
    final threeMonth = service.generateRedemptionCode(
      plan: MembershipPlan.threeMonths,
    );
    service.loginWithPhone('13300133000');
    expect(service.redeemCode(threeMonth.code).isSuccess, isTrue);
    expect(service.entitlements?.membershipExpiresAt, DateTime(2026, 4, 15, 9));

    service.loginWithPhone('1234', password: '1234');
    final oneMonth = service.generateRedemptionCode(
      plan: MembershipPlan.oneMonth,
    );
    service.loginWithPhone('13300133000');
    expect(service.redeemCode(oneMonth.code).isSuccess, isTrue);
    expect(service.entitlements?.membershipExpiresAt, DateTime(2026, 5, 15, 9));

    service.loginWithPhone('1234', password: '1234');
    final forever = service.generateRedemptionCode(
      plan: MembershipPlan.forever,
    );
    service.loginWithPhone('13300133000');
    expect(service.redeemCode(forever.code).isSuccess, isTrue);
    service.loginWithPhone('1234', password: '1234');
    final shortCode = service.generateRedemptionCode(
      plan: MembershipPlan.oneMonth,
    );
    service.loginWithPhone('13300133000');
    expect(service.redeemCode(shortCode.code).isSuccess, isTrue);
    expect(service.entitlements?.membership, MembershipPlan.forever);
    expect(service.entitlements?.membershipExpiresAt, isNull);
  });

  test('in-memory persistence restores account and entitlements', () {
    final persistence = InMemoryAccountPersistence();
    final first = AccountService(
      persistence: persistence,
      allowTestAdmin: true,
    );
    first.loginWithPhone('1234', password: '1234');
    final code = first.generateRedemptionCode(plan: MembershipPlan.oneMonth);
    first.loginWithPhone('13400134000');
    expect(first.redeemCode(code.code).isSuccess, isTrue);

    final restored = AccountService(
      persistence: persistence,
      allowTestAdmin: true,
    );
    expect(restored.currentUser?.identifier, '13400134000');
    expect(restored.entitlements?.membership, MembershipPlan.oneMonth);
  });

  test('membership orders are user scoped and survive persistence', () {
    final persistence = InMemoryAccountPersistence();
    final service = AccountService(persistence: persistence);
    service.loginWithPhone('13800138000');
    final order = service.createMembershipOrder(
      plan: MembershipPlan.threeMonths,
      productId: 'com.kilostrength.pro.quarterly',
      displayPrice: '¥36',
      provider: MembershipOrderProvider.appStore,
    );
    expect(order, isNotNull);
    service.updateMembershipOrder(
      order!.id,
      status: MembershipOrderStatus.paid,
      transactionId: 'transaction-1',
    );

    final restored = AccountService(persistence: persistence);
    expect(restored.membershipOrders, hasLength(1));
    expect(restored.membershipOrders.single.status, MembershipOrderStatus.paid);
    expect(restored.membershipOrders.single.transactionId, 'transaction-1');

    restored.loginWithPhone('13900139000');
    expect(restored.membershipOrders, isEmpty);
  });

  test('server yearly and refunded order fields remain terminal locally', () {
    final order = MembershipOrder.fromMap({
      'id': 'ord-yearly-refund',
      'userId': 'user-1',
      'plan': 'yearly',
      'productId': 'com.kilostrength.pro.yearly',
      'provider': 'app_store',
      'status': 'refunded',
      'createdAt': '2026-08-20T00:00:00.000Z',
      'updatedAt': '2026-08-20T01:00:00.000Z',
    });

    expect(order.plan, MembershipPlan.threeMonths);
    expect(order.status, MembershipOrderStatus.refunded);
    expect(order.provider, MembershipOrderProvider.appStore);
  });

  test('persisted test admin is removed when the release gate is disabled', () {
    final persistence = InMemoryAccountPersistence();
    final debugService = AccountService(
      persistence: persistence,
      allowTestAdmin: true,
    );
    debugService.loginWithPhone('1234', password: '1234');
    final releaseService = AccountService(
      persistence: persistence,
      allowTestAdmin: false,
    );
    expect(releaseService.currentUser, isNull);
    expect(releaseService.isAdmin, isFalse);
    expect(
      releaseService.loginWithPhone('1234', password: '1234').isSuccess,
      isFalse,
    );
  });
}

class _ThrowingCoachApi implements CoachApi {
  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
  }) async {
    throw StateError('upstream');
  }
}
