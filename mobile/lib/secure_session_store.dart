import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The opaque server session shared by the coach and recognition clients.
///
/// Passwords are deliberately not part of this value.  A session is bound to
/// both the account and the configured API origin so a token cannot be reused
/// after an account switch or a configuration change.
class RemoteSession {
  const RemoteSession({
    required this.token,
    required this.accountIdentifier,
    required this.apiOrigin,
    this.expiresAt,
  });

  final String token;
  final String accountIdentifier;
  final String apiOrigin;
  final DateTime? expiresAt;

  bool get isUsable => token.trim().isNotEmpty && accountIdentifier.isNotEmpty;

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !expiry.toUtc().isAfter((now ?? DateTime.now()).toUtc());
  }

  bool matches({
    required String accountIdentifier,
    required String apiOrigin,
    DateTime? now,
  }) =>
      isUsable &&
      this.accountIdentifier == accountIdentifier.trim() &&
      canonicalApiOrigin(this.apiOrigin) == canonicalApiOrigin(apiOrigin) &&
      !isExpired(now);

  Map<String, dynamic> toJson() => {
    'token': token,
    'accountIdentifier': accountIdentifier,
    'apiOrigin': canonicalApiOrigin(apiOrigin),
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };

  factory RemoteSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ?? '').toString();
    final accountIdentifier = (json['accountIdentifier'] ?? '').toString();
    final apiOrigin = canonicalApiOrigin((json['apiOrigin'] ?? '').toString());
    final rawExpiry = (json['expiresAt'] ?? '').toString();
    return RemoteSession(
      token: token,
      accountIdentifier: accountIdentifier,
      apiOrigin: apiOrigin,
      expiresAt: rawExpiry.isEmpty ? null : DateTime.tryParse(rawExpiry),
    );
  }
}

String canonicalApiOrigin(String value) =>
    value.trim().replaceAll(RegExp(r'/+$'), '');

/// Small injectable boundary around platform secure storage.  The app uses
/// [FlutterSecureSessionStore]; tests can use [InMemorySecureSessionStore]
/// without installing a platform channel.
abstract interface class SecureSessionStore {
  Future<RemoteSession?> read();
  Future<void> write(RemoteSession session);
  Future<void> clear();
}

class FlutterSecureSessionStore implements SecureSessionStore {
  FlutterSecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'kilo.remote-session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<RemoteSession?> read() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final session = RemoteSession.fromJson(decoded);
      return session.isUsable ? session : null;
    } catch (_) {
      // Secure storage may be unavailable in previews, desktop builds or
      // during a platform keystore migration. Keep the current process usable.
      return null;
    }
  }

  @override
  Future<void> write(RemoteSession session) async {
    if (!session.isUsable) return;
    try {
      await _storage.write(
        key: storageKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {
      // A failed write means this process remains memory-only. Never crash
      // startup or turn a successful login into an error.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      // Best effort. Local logout must not be blocked by an unavailable
      // keystore.
    }
  }
}

class InMemorySecureSessionStore implements SecureSessionStore {
  InMemorySecureSessionStore([this._session]);

  RemoteSession? _session;

  RemoteSession? get value => _session;

  @override
  Future<RemoteSession?> read() async => _session;

  @override
  Future<void> write(RemoteSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
