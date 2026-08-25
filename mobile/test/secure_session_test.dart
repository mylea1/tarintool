import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/recognition_api.dart';
import 'package:kilo_strength/secure_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remote session matches its account and API origin and expires', () {
    final future = DateTime.now().add(const Duration(days: 1));
    final session = RemoteSession(
      token: 'token',
      accountIdentifier: '13800138000',
      apiOrigin: 'https://api.example.test/',
      expiresAt: future,
    );

    expect(
      session.matches(
        accountIdentifier: '13800138000',
        apiOrigin: 'https://api.example.test',
      ),
      isTrue,
    );
    expect(
      session.matches(
        accountIdentifier: '13800138001',
        apiOrigin: 'https://api.example.test',
      ),
      isFalse,
    );
    expect(
      session.matches(
        accountIdentifier: '13800138000',
        apiOrigin: 'https://other.example.test',
      ),
      isFalse,
    );
    expect(session.isExpired(DateTime.now()), isFalse);
    expect(
      session.isExpired(DateTime.now().add(const Duration(days: 2))),
      isTrue,
    );
  });

  test('coach login stores a structured session without a password', () async {
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'identifier': '13800138000',
          'password': 'secret',
        });
        return http.Response(
          jsonEncode({
            'user': {'identifier': '13800138000'},
            'session': {
              'token': 'coach-token',
              'expiresAt': DateTime.now()
                  .add(const Duration(days: 30))
                  .toUtc()
                  .toIso8601String(),
            },
          }),
          200,
        );
      }),
    );
    await api.signIn(identifier: '13800138000', password: 'secret');

    final json = api.session!.toJson();
    expect(json['token'], 'coach-token');
    expect(json['accountIdentifier'], '13800138000');
    expect(json.containsKey('password'), isFalse);
    expect(jsonEncode(json), isNot(contains('secret')));
  });

  test(
    'recognition restores the same coach session without another login',
    () async {
      final session = RemoteSession(
        token: 'shared-token',
        accountIdentifier: '13800138000',
        apiOrigin: 'https://api.example.test',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      final api = HttpRecognitionApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/analysis/capabilities');
          return http.Response(jsonEncode({'exercises': []}), 200);
        }),
      );

      expect(
        api.restoreSession(session, accountIdentifier: '13800138000'),
        isTrue,
      );
      expect(api.hasSession, isTrue);
      expect(api.session?.token, 'shared-token');
      await api.capabilities();
    },
  );

  test(
    'cold start restores the persisted session for AI and friends',
    () async {
      final persistence = InMemoryAccountPersistence();
      final firstAccount = AccountService(persistence: persistence);
      firstAccount.loginAuthenticatedRemote(
        identifier: '13800138000',
        displayName: '测试用户',
        isAdmin: false,
      );
      final store = InMemorySecureSessionStore(
        RemoteSession(
          token: 'cold-token',
          accountIdentifier: '13800138000',
          apiOrigin: 'https://api.example.test',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final requests = <http.Request>[];
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode({'friends': []}), 200);
        }),
      );
      final secondAccount = AccountService(persistence: persistence);
      final controller = AppController(
        accountService: secondAccount,
        coachApi: api,
        secureSessionStore: store,
      );
      addTearDown(controller.dispose);
      controller.aiBaseUrl = 'https://api.example.test';

      await controller.restoreRemoteSession();
      await controller.fetchFriendsRemote();

      expect(requests.single.headers['authorization'], 'Bearer cold-token');
      expect(api.hasSession, isTrue);
    },
  );

  test('expired or mismatched sessions are rejected and cleared', () async {
    final account = AccountService();
    account.loginWithPhone('13800138000');
    final store = InMemorySecureSessionStore(
      RemoteSession(
        token: 'wrong-account-token',
        accountIdentifier: '13800138001',
        apiOrigin: 'https://api.example.test',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final controller = AppController(
      accountService: account,
      secureSessionStore: store,
    );
    addTearDown(controller.dispose);
    controller.aiBaseUrl = 'https://api.example.test';
    await controller.restoreRemoteSession();
    expect(await store.read(), isNull);

    final expired = InMemorySecureSessionStore(
      RemoteSession(
        token: 'expired-token',
        accountIdentifier: '13800138000',
        apiOrigin: 'https://api.example.test',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );
    final expiredController = AppController(
      accountService: account,
      secureSessionStore: expired,
    );
    addTearDown(expiredController.dispose);
    expiredController.aiBaseUrl = 'https://api.example.test';
    await expiredController.restoreRemoteSession();
    expect(await expired.read(), isNull);
  });

  test('401 invokes invalidation callback but network errors do not', () async {
    final store = InMemorySecureSessionStore(
      RemoteSession(
        token: '401-token',
        accountIdentifier: '13800138000',
        apiOrigin: 'https://api.example.test',
      ),
    );
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      onSessionInvalidated: () => unawaited(store.clear()),
      client: MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': '401-token'},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'session_expired'}), 401);
      }),
    );
    await api.signIn(identifier: '13800138000', password: 'secret');
    await expectLater(
      api.answer(prompt: 'test', includeTrainingSummary: false),
      throwsA(
        isA<CoachApiException>().having(
          (error) => error.code,
          'code',
          'session_expired',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await store.read(), isNull);
    expect(api.hasSession, isFalse);

    final networkStore = InMemorySecureSessionStore();
    final networkApi = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      onSessionInvalidated: () => unawaited(networkStore.clear()),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    // No HTTP 401 occurred, so the invalidation callback is never invoked.
    expect(await networkStore.read(), isNull);
    expect(networkApi.hasSession, isFalse);
  });

  test('explicit logout clears the secure session', () async {
    final store = InMemorySecureSessionStore(
      const RemoteSession(
        token: 'logout-token',
        accountIdentifier: '13800138000',
        apiOrigin: 'https://api.example.test',
      ),
    );
    final account = AccountService();
    account.loginWithPhone('13800138000');
    final controller = AppController(
      accountService: account,
      secureSessionStore: store,
    );
    addTearDown(controller.dispose);
    controller.logout();
    await Future<void>.delayed(Duration.zero);
    expect(await store.read(), isNull);
  });
}
