import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/secure_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WriteFailingSessionStore implements SecureSessionStore {
  @override
  Future<RemoteSession?> read() async => null;

  @override
  Future<void> write(RemoteSession session) async {
    throw StateError('keystore unavailable');
  }

  @override
  Future<void> clear() async {}
}

class _PhoneAuthHarness {
  _PhoneAuthHarness({this.failCodeRequest = false}) {
    client = MockClient((request) async {
      requests.add(request);
      final body = request.body.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      switch (request.url.path) {
        case '/v1/auth/phone/request':
          if (failCodeRequest) {
            return _response({'error': 'sms_rate_limited'}, status: 429);
          }
          return _response({
            'sent': true,
            'retryAfterSeconds': 60,
            'expiresInSeconds': 300,
          });
        case '/v1/auth/phone/register':
          expect(body['password'], 'strong-pass-123');
          expect(body['code'], '654321');
          return _authResponse('register-session');
        case '/v1/auth/phone/login':
          expect(body['password'], 'strong-pass-123');
          return _authResponse('password-session');
        case '/v1/auth/phone/verify':
          expect(body['code'], '654321');
          return _authResponse('sms-session');
        default:
          // The post-login hydration calls are intentionally harmless in this
          // UI test; auth requests above are the only requests under test.
          return _response(<String, dynamic>{});
      }
    });
    api = HttpCoachApi(baseUrl: 'https://api.example.test', client: client);
    controller = AppController(coachApi: api, secureSessionStore: store);
  }

  final bool failCodeRequest;
  final store = InMemorySecureSessionStore();
  final requests = <http.BaseRequest>[];
  late final MockClient client;
  late final HttpCoachApi api;
  late final AppController controller;

  static http.Response _response(
    Map<String, dynamic> body, {
    int status = 200,
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );

  static http.Response _authResponse(String token) => _response({
    'user': {
      'id': 'usr-phone-test',
      'identifier': '+8613800138000',
      'displayName': '手机测试用户',
      'role': 'user',
    },
    'session': {
      'token': token,
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    },
  });

  void dispose() {
    controller.dispose();
    client.close();
  }
}

Future<void> _pumpLogin(
  WidgetTester tester,
  _PhoneAuthHarness harness, {
  double width = 375,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.maybeOf(context) ?? const MediaQueryData();
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: LoginPage(
        key: ValueKey<Object>(harness),
        controller: harness.controller,
      ),
    ),
  );
  await tester.pump();
  expect(
    MediaQuery.textScalerOf(
      tester.element(find.byKey(const Key('login-page'))),
    ).scale(1),
    textScale,
  );
}

Future<void> _tapAfterScroll(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
}

Future<void> _enterAfterScroll(
  WidgetTester tester,
  Key key,
  String value,
) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byKey(key), value);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'registration then password and SMS login share the canonical session',
    (tester) async {
      final harness = _PhoneAuthHarness();
      addTearDown(harness.dispose);
      await _pumpLogin(tester, harness);

      await _enterAfterScroll(
        tester,
        const Key('login-identifier'),
        '13800138000',
      );
      await _tapAfterScroll(tester, const Key('login-register-button'));
      await tester.pump();
      expect(find.byKey(const Key('register-code')), findsOneWidget);
      expect(find.byKey(const Key('register-password')), findsOneWidget);
      expect(
        find.byKey(const Key('register-confirm-password')),
        findsOneWidget,
      );

      await _tapAfterScroll(tester, const Key('register-send-code'));
      await tester.pump();
      expect(find.text('60s 后重试'), findsOneWidget);
      await _enterAfterScroll(tester, const Key('register-code'), '654321');
      await _enterAfterScroll(
        tester,
        const Key('register-password'),
        'strong-pass-123',
      );
      await _enterAfterScroll(
        tester,
        const Key('register-confirm-password'),
        'strong-pass-123',
      );
      await _tapAfterScroll(tester, const Key('register-button'));
      await tester.pump();
      expect(harness.controller.currentUser?.identifier, '+8613800138000');
      expect(harness.store.value?.token, 'register-session');
      expect(harness.store.value?.toJson(), isNot(contains('password')));

      harness.controller.logout();
      await _tapAfterScroll(tester, const Key('login-back-to-login'));
      await tester.pump();
      await _enterAfterScroll(
        tester,
        const Key('login-password'),
        'strong-pass-123',
      );
      await _tapAfterScroll(tester, const Key('login-button'));
      await tester.pump();
      expect(harness.controller.currentUser?.identifier, '+8613800138000');
      expect(harness.store.value?.token, 'password-session');

      harness.controller.logout();
      // Use a fresh page for the second authentication method. This keeps the
      // test independent of the registration request's real 60-second
      // cooldown while still exercising the same canonical account.
      final smsHarness = _PhoneAuthHarness();
      addTearDown(smsHarness.dispose);
      await _pumpLogin(tester, smsHarness);
      await _enterAfterScroll(
        tester,
        const Key('login-identifier'),
        '13800138000',
      );
      await _tapAfterScroll(tester, const Key('login-code-mode'));
      await _tapAfterScroll(tester, const Key('login-send-code'));
      await tester.pump();
      expect(find.text('60s 后重试'), findsOneWidget);
      await _enterAfterScroll(tester, const Key('login-code'), '654321');
      await _tapAfterScroll(tester, const Key('login-code-button'));
      await tester.pump();
      expect(smsHarness.controller.currentUser?.identifier, '+8613800138000');
      expect(smsHarness.store.value?.token, 'sms-session');

      final authPaths = harness.requests
          .where((request) => request.url.path.startsWith('/v1/auth/phone'))
          .map((request) => request.url.path)
          .toList();
      expect(
        authPaths,
        containsAllInOrder(<String>[
          '/v1/auth/phone/request',
          '/v1/auth/phone/register',
          '/v1/auth/phone/login',
        ]),
      );
      expect(
        smsHarness.requests
            .where((request) => request.url.path.startsWith('/v1/auth/phone'))
            .map((request) => request.url.path),
        containsAllInOrder(<String>[
          '/v1/auth/phone/request',
          '/v1/auth/phone/verify',
        ]),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty fields, mode switching, and SMS errors stay actionable', (
    tester,
  ) async {
    final harness = _PhoneAuthHarness(failCodeRequest: true);
    addTearDown(harness.dispose);
    await _pumpLogin(tester, harness, width: 320, textScale: 2);

    expect(find.byKey(const Key('login-password-mode')), findsOneWidget);
    expect(find.byKey(const Key('login-code-mode')), findsOneWidget);
    expect(find.byKey(const Key('login-register-button')), findsOneWidget);
    await _tapAfterScroll(tester, const Key('login-register-button'));
    await tester.pump();
    await _tapAfterScroll(tester, const Key('register-button'));
    await tester.pump();
    expect(find.text('请输入有效的大陆手机号。'), findsOneWidget);

    await _enterAfterScroll(
      tester,
      const Key('login-identifier'),
      '13800138000',
    );
    await _tapAfterScroll(tester, const Key('login-back-to-login'));
    await tester.pump();
    await _enterAfterScroll(
      tester,
      const Key('login-password'),
      'password-kept-nowhere',
    );
    await _tapAfterScroll(tester, const Key('login-code-mode'));
    await tester.pump();
    expect(find.byKey(const Key('login-password')), findsNothing);
    expect(find.byKey(const Key('login-code')), findsOneWidget);

    await _tapAfterScroll(tester, const Key('login-send-code'));
    await tester.pump();
    expect(find.text('操作过于频繁，请稍后重试。'), findsOneWidget);
    expect(
      harness.requests.where(
        (request) => request.url.path == '/v1/auth/phone/request',
      ),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'a secure-session write failure does not publish a local user',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/auth/phone/register');
        return _PhoneAuthHarness._authResponse('write-failure-session');
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );
      final controller = AppController(
        coachApi: api,
        secureSessionStore: _WriteFailingSessionStore(),
      );
      addTearDown(() {
        controller.dispose();
        client.close();
      });

      final result = await controller.registerPhoneRemote(
        identifier: '13800138000',
        password: 'strong-pass-123',
        code: '654321',
      );
      expect(result.error, AccountError.serviceNotConfigured);
      expect(controller.currentUser, isNull);
      expect(api.hasSession, isFalse);
    },
  );
}
