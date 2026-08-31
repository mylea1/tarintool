import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/apple_sign_in_client.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/secure_session_store.dart';

class _FakeAppleSignInClient implements AppleSignInClient {
  const _FakeAppleSignInClient({required this.error});

  final AppleSignInClientException error;

  @override
  Future<String> requestIdentityToken() async {
    throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Apple identity token creates a backend session payload', () async {
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/v1/auth/apple');
        expect(jsonDecode(request.body), {'identityToken': 'apple-id-token'});
        return http.Response(
          jsonEncode({
            'user': {
              'identifier': 'apple:000123',
              'displayName': 'Apple 用户',
              'role': 'user',
            },
            'session': {
              'token': 'server-session',
              'expiresAt': '2026-09-30T00:00:00.000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final payload = await api.signInWithApple(identityToken: 'apple-id-token');

    expect(payload['user'], isA<Map>());
    expect(api.session?.token, 'server-session');
    expect(api.session?.accountIdentifier, 'apple:000123');

    final service = AccountService();
    final result = service.loginAuthenticatedRemote(
      identifier: 'apple:000123',
      displayName: 'Apple 用户',
      isAdmin: false,
      provider: AuthProvider.apple,
    );
    expect(result.isSuccess, isTrue);
    expect(service.currentUser?.provider, AuthProvider.apple);
    expect(service.currentUser?.id, 'apple:000123');
  });

  test(
    'canceling Apple authorization does not create a local session',
    () async {
      final service = AccountService();
      final controller = AppController(
        accountService: service,
        appleSignInClient: const _FakeAppleSignInClient(
          error: AppleSignInClientException(AppleSignInFailure.canceled),
        ),
        secureSessionStore: InMemorySecureSessionStore(),
      );
      addTearDown(controller.dispose);

      final result = await controller.loginWithAppleRemote();

      expect(result.isSuccess, isFalse);
      expect(result.message, 'Apple 登录已取消。');
      expect(service.currentUser, isNull);
    },
  );
}
