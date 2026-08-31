import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum AppleSignInFailure {
  canceled,
  notAvailable,
  missingIdentityToken,
  authorizationFailed,
}

class AppleSignInClientException implements Exception {
  const AppleSignInClientException(this.failure, [this.details]);

  final AppleSignInFailure failure;
  final String? details;

  @override
  String toString() => 'AppleSignInClientException(${failure.name})';
}

abstract interface class AppleSignInClient {
  Future<String> requestIdentityToken();
}

class NativeAppleSignInClient implements AppleSignInClient {
  const NativeAppleSignInClient();

  @override
  Future<String> requestIdentityToken() async {
    if (!await SignInWithApple.isAvailable()) {
      throw const AppleSignInClientException(AppleSignInFailure.notAvailable);
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken?.trim() ?? '';
      if (token.isEmpty) {
        throw const AppleSignInClientException(
          AppleSignInFailure.missingIdentityToken,
        );
      }
      return token;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AppleSignInClientException(AppleSignInFailure.canceled);
      }
      throw AppleSignInClientException(
        AppleSignInFailure.authorizationFailed,
        error.message,
      );
    } on AppleSignInClientException {
      rethrow;
    } catch (error) {
      throw AppleSignInClientException(
        AppleSignInFailure.authorizationFailed,
        error.toString(),
      );
    }
  }
}
