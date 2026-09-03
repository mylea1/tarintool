import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'account_membership.dart';
import 'models.dart';
import 'secure_session_store.dart';

class CoachAnswer {
  const CoachAnswer({
    required this.body,
    this.conversationId,
    this.citations = const [],
    this.plan,
    this.toolCalls = const [],
    this.toolUses = const [],
  });
  final String body;
  final String? conversationId;
  final List<String> citations;
  final AiPlanDraft? plan;
  final List<CoachToolCall> toolCalls;
  final List<CoachToolUse> toolUses;
}

/// A bounded read-only request selected by the model. The app, rather than
/// the server, executes it against the current user's local state.
class CoachToolCall {
  const CoachToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
  };
}

class CoachToolUse {
  const CoachToolUse({required this.name, required this.count});

  final String name;
  final int count;
}

sealed class CoachStreamEvent {
  const CoachStreamEvent();
}

class CoachStreamDelta extends CoachStreamEvent {
  const CoachStreamDelta(this.text);
  final String text;
}

class CoachStreamDone extends CoachStreamEvent {
  const CoachStreamDone(this.answer);
  final CoachAnswer answer;
}

abstract interface class StreamingCoachApi {
  Stream<CoachStreamEvent> streamAnswer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> toolResults = const [],
  });
}

/// Client boundary for the server-owned `/v1/coach/answer` endpoint.
/// Authentication and model keys stay on the server; this client only receives
/// a user prompt, optional consented summary and a JSON answer.
abstract interface class CoachApi {
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? conversationId,
  });
}

/// Extended protocol used only when the AI page has granted read-only local
/// data access. Keeping this separate preserves compatibility with existing
/// mock/third-party CoachApi implementations.
abstract interface class AgentCoachApi {
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> availableTools = const [],
    List<Map<String, dynamic>> toolResults = const [],
  });

  Future<void> rollbackQuotaReservation(String requestId);
}

class HttpCoachApi implements CoachApi, AgentCoachApi, StreamingCoachApi {
  HttpCoachApi({
    required this.baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 90),
    this.onSessionInvalidated,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final Duration requestTimeout;
  final void Function()? onSessionInvalidated;
  String? _sessionToken;
  RemoteSession? _remoteSession;

  bool get hasSession => _sessionToken?.isNotEmpty == true;
  RemoteSession? get session => _remoteSession;

  /// Restores a session previously stored by [SecureSessionStore]. The
  /// caller supplies the current local account so an old account's token
  /// cannot be attached after switching users.
  bool restoreSession(
    RemoteSession session, {
    required String accountIdentifier,
  }) {
    if (!session.matches(
      accountIdentifier: accountIdentifier,
      apiOrigin: baseUrl,
    )) {
      clearSession();
      return false;
    }
    _remoteSession = session;
    _sessionToken = session.token;
    return true;
  }

  /// Releases a pending AI reservation when a local tool or its follow-up
  /// request fails. The request id makes this operation idempotent server-side.
  @override
  Future<void> rollbackQuotaReservation(String requestId) async {
    if (requestId.trim().isEmpty) return;
    final response = await _client
        .post(
          _endpoint('/v1/usage/rollback'),
          headers: _authHeaders,
          body: jsonEncode({'kind': 'ai', 'requestId': requestId}),
        )
        .timeout(requestTimeout);
    _decodeJsonResponse(response, 'coach_rollback');
  }

  Future<Map<String, dynamic>> signIn({
    required String identifier,
    required String password,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/auth/phone/login',
    );
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _coachServerException(
        response.statusCode,
        response.body,
        'coach_auth',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final session = payload['session'];
    final token = session is Map<String, dynamic>
        ? (session['token'] ?? '').toString()
        : '';
    if (token.isEmpty) {
      throw const CoachApiException('coach_auth_token_missing');
    }
    final rawUser = payload['user'];
    final canonicalIdentifier = rawUser is Map
        ? (rawUser['identifier'] ?? '').toString().trim()
        : '';
    _remoteSession = RemoteSession(
      token: token,
      accountIdentifier: canonicalIdentifier.isEmpty
          ? identifier.trim()
          : canonicalIdentifier,
      apiOrigin: baseUrl,
      expiresAt: _sessionExpiry(session),
    );
    _sessionToken = token;
    return payload;
  }

  Future<PhoneCodeChallenge> requestPhoneCode({
    required String identifier,
    required String purpose,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/auth/phone/request'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': identifier.trim(),
            'purpose': purpose,
          }),
        )
        .timeout(requestTimeout);
    final payload = _decodeJsonResponse(response, 'phone_code_request');
    if (payload['sent'] != true) {
      throw const CoachApiException('phone_code_not_sent');
    }
    return PhoneCodeChallenge(
      sent: true,
      retryAfterSeconds: _nonNegativeInt(payload['retryAfterSeconds'], 60),
      expiresInSeconds: _nonNegativeInt(payload['expiresInSeconds'], 300),
    );
  }

  Future<Map<String, dynamic>> registerPhone({
    required String identifier,
    required String password,
    required String code,
  }) async => _phoneAuth(
    path: '/v1/auth/phone/register',
    operation: 'phone_register',
    body: {
      'identifier': identifier.trim(),
      'password': password,
      'code': code.trim(),
    },
  );

  Future<Map<String, dynamic>> verifyPhone({
    required String identifier,
    required String code,
  }) async => _phoneAuth(
    path: '/v1/auth/phone/verify',
    operation: 'phone_verify',
    body: {'identifier': identifier.trim(), 'code': code.trim()},
  );

  Future<Map<String, dynamic>> _phoneAuth({
    required String path,
    required String operation,
    required Map<String, Object?> body,
  }) async {
    final response = await _client
        .post(
          _endpoint(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    final payload = _decodeJsonResponse(response, operation);
    final session = payload['session'];
    final token = session is Map<String, dynamic>
        ? (session['token'] ?? '').toString()
        : '';
    if (token.isEmpty) {
      throw CoachApiException('${operation}_token_missing');
    }
    final rawUser = payload['user'];
    final canonicalIdentifier = rawUser is Map
        ? (rawUser['identifier'] ?? '').toString().trim()
        : '';
    _remoteSession = RemoteSession(
      token: token,
      accountIdentifier: canonicalIdentifier.isEmpty
          ? (body['identifier'] ?? '').toString().trim()
          : canonicalIdentifier,
      apiOrigin: baseUrl,
      expiresAt: _sessionExpiry(session),
    );
    _sessionToken = token;
    return payload;
  }

  Future<Map<String, dynamic>> signInWithApple({
    required String identityToken,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/auth/apple'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'identityToken': identityToken}),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _coachServerException(
        response.statusCode,
        response.body,
        'coach_apple_auth',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final session = payload['session'];
    final token = session is Map<String, dynamic>
        ? (session['token'] ?? '').toString()
        : '';
    final rawUser = payload['user'];
    final identifier = rawUser is Map
        ? (rawUser['identifier'] ?? '').toString().trim()
        : '';
    if (token.isEmpty) {
      throw const CoachApiException('coach_auth_token_missing');
    }
    if (identifier.isEmpty) {
      throw const CoachApiException('coach_auth_user_missing');
    }
    _remoteSession = RemoteSession(
      token: token,
      accountIdentifier: identifier,
      apiOrigin: baseUrl,
      expiresAt: _sessionExpiry(session),
    );
    _sessionToken = token;
    return payload;
  }

  Future<Map<String, dynamic>> createManagedUser({
    required String identifier,
    required String password,
    String? displayName,
    String? membershipPlan,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/admin/users'),
          headers: _authHeaders,
          body: jsonEncode({
            'identifier': identifier,
            'password': password,
            if (displayName?.trim().isNotEmpty == true)
              'displayName': displayName!.trim(),
            if (membershipPlan != null && membershipPlan != 'free')
              'membershipPlan': membershipPlan,
          }),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'admin_user_create');
  }

  Future<Map<String, dynamic>> grantMembershipRemote({
    required String identifier,
    required String plan,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/admin/memberships/grant'),
          headers: _authHeaders,
          body: jsonEncode({'identifier': identifier, 'plan': plan}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'admin_membership_grant');
  }

  Future<Map<String, dynamic>> fetchFriends() async {
    final response = await _client
        .get(_endpoint('/v1/friends'), headers: _authHeaders)
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friends_fetch');
  }

  Future<Map<String, dynamic>> fetchFriendIdentities() async {
    final response = await _client
        .get(_endpoint('/v1/me/identities'), headers: _authHeaders)
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_identities_fetch');
  }

  Future<Map<String, dynamic>> updateFriendUsername(String username) async {
    final response = await _client
        .put(
          _endpoint('/v1/me/username'),
          headers: _authHeaders,
          body: jsonEncode({'username': username}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_username_update');
  }

  Future<Map<String, dynamic>> searchFriends(String query) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/search'),
          headers: _authHeaders,
          body: jsonEncode({'query': query}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_search');
  }

  Future<Map<String, dynamic>> fetchFriendPlanFeed() async {
    final response = await _client
        .get(_endpoint('/v1/friends/feed'), headers: _authHeaders)
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_feed_fetch');
  }

  Future<Map<String, dynamic>> sendFriendRequest(String identifier) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/requests'),
          headers: _authHeaders,
          body: jsonEncode({'identifier': identifier}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_request');
  }

  Future<Map<String, dynamic>> sendFriendRequestToUser(
    String targetUserId,
  ) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/requests'),
          headers: _authHeaders,
          body: jsonEncode({'targetUserId': targetUserId}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_request');
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/requests/$requestId/accept'),
          headers: _authHeaders,
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_accept');
  }

  Future<Map<String, dynamic>> shareFriendPlan({
    required String sourcePlanId,
    required String name,
    required Map<String, dynamic> plan,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/plans'),
          headers: _authHeaders,
          body: jsonEncode({
            'sourcePlanId': sourcePlanId,
            'name': name,
            'plan': plan,
          }),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_plan_share');
  }

  Future<Map<String, dynamic>> reactToFriendPlan(
    String shareId,
    String emoji,
  ) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/plans/$shareId/reactions'),
          headers: _authHeaders,
          body: jsonEncode({'emoji': emoji}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_plan_reaction');
  }

  /// Publishes an explicitly selected completed workout snapshot. The server
  /// owns visibility and only returns posts visible to the current account.
  Future<Map<String, dynamic>> publishWorkoutActivity(
    Map<String, dynamic> snapshot,
  ) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/workouts'),
          headers: _authHeaders,
          body: jsonEncode(snapshot),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_workout_publish');
  }

  Future<Map<String, dynamic>> toggleWorkoutActivityLike(String postId) async {
    final response = await _client
        .post(
          _endpoint('/v1/friends/workouts/${Uri.encodeComponent(postId)}/like'),
          headers: _authHeaders,
          body: '{}',
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_workout_like');
  }

  Future<Map<String, dynamic>> commentOnWorkoutActivity(
    String postId,
    String emoji,
  ) async {
    final response = await _client
        .post(
          _endpoint(
            '/v1/friends/workouts/${Uri.encodeComponent(postId)}/comments',
          ),
          headers: _authHeaders,
          body: jsonEncode({'emoji': emoji}),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_workout_comment');
  }

  Future<Map<String, dynamic>> deleteWorkoutActivity(String postId) async {
    final response = await _client
        .delete(
          _endpoint('/v1/friends/workouts/${Uri.encodeComponent(postId)}'),
          headers: _authHeaders,
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'friend_workout_delete');
  }

  /// Sends one or more local image files to the server-owned multimodal
  /// boundary. The result is always a reviewable candidate; this method never
  /// manufactures nutrition values on-device.
  Future<Map<String, dynamic>> recognizeFoodPhotos(
    List<String> imagePaths,
  ) async {
    if (imagePaths.isEmpty) {
      throw const CoachApiException('food_images_required');
    }
    final request = http.MultipartRequest(
      'POST',
      _endpoint('/v1/food/recognition'),
    );
    final headers = Map<String, String>.from(_authHeaders)
      ..remove('Content-Type');
    request.headers.addAll(headers);
    for (final path in imagePaths.take(8)) {
      final file = File(path);
      if (!await file.exists()) continue;
      request.files.add(await http.MultipartFile.fromPath('images', path));
    }
    if (request.files.isEmpty) {
      throw const CoachApiException('food_images_unreadable');
    }
    final streamed = await request.send().timeout(requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decodeJsonResponse(response, 'food_recognition');
  }

  void clearSession() {
    _sessionToken = null;
    _remoteSession = null;
  }

  void _invalidateSession() {
    clearSession();
    onSessionInvalidated?.call();
  }

  Map<String, String> get _authHeaders {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _endpoint(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, Object> get _clientTimeContext {
    final now = DateTime.now();
    final localDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return {
      'clientDate': localDate,
      'clientTimezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'clientTimezoneName': now.timeZoneName,
    };
  }

  Future<Map<String, dynamic>> createMembershipOrder({
    required String productId,
    required String plan,
    String provider = 'app_store',
    int? amountMinor,
    String currency = 'CNY',
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/membership/orders'),
          headers: _authHeaders,
          body: jsonEncode({
            'productId': productId,
            'plan': plan,
            'provider': provider,
            'currency': currency,
            'amountMinor': ?amountMinor,
          }),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'membership_order_create');
  }

  /// Reads the server-owned membership state. Callers must refresh this
  /// before deciding whether a cloud backup/restore is allowed; local cached
  /// quota or membership data is never sufficient for that decision.
  Future<Map<String, dynamic>> fetchEntitlements() async {
    final response = await _client
        .get(_endpoint('/v1/me/entitlements'), headers: _authHeaders)
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'membership_entitlements');
  }

  Future<Map<String, dynamic>> activateMembershipTrial({
    required String workoutId,
    required int durationSeconds,
    required int effectiveSets,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/membership/trial/activate'),
          headers: _authHeaders,
          body: jsonEncode({
            'workoutId': workoutId,
            'durationSeconds': durationSeconds,
            'effectiveSets': effectiveSets,
          }),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'membership_trial_activate');
  }

  Future<Map<String, dynamic>> cancelMembershipOrder(String orderId) async {
    final response = await _client
        .post(
          _endpoint(
            '/v1/membership/orders/${Uri.encodeComponent(orderId)}/cancel',
          ),
          headers: _authHeaders,
          body: '{}',
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'membership_order_cancel');
  }

  Future<List<Map<String, dynamic>>> fetchMembershipOrders() async {
    final response = await _client
        .get(_endpoint('/v1/membership/orders'), headers: _authHeaders)
        .timeout(requestTimeout);
    final payload = _decodeJsonResponse(response, 'membership_orders');
    return (payload['orders'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> fetchAndroidPaymentCapabilities() async {
    final response = await _client
        .get(_endpoint('/v1/membership/android/capabilities'))
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'android_payment_capabilities');
  }

  Future<Map<String, dynamic>> createAndroidMembershipCheckout({
    required String productId,
    required String provider,
    required int amountMinor,
  }) async {
    final response = await _client
        .post(
          _endpoint('/v1/membership/android/checkout'),
          headers: _authHeaders,
          body: jsonEncode({
            'productId': productId,
            'provider': provider,
            'platform': 'android',
            'amountMinor': amountMinor,
            'currency': 'CNY',
          }),
        )
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'android_payment_checkout');
  }

  Future<List<Map<String, dynamic>>> fetchSyncEntities(
    String entityType,
  ) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    final response = await _client
        .get(
          Uri.parse(
            '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/sync?entityType=${Uri.encodeQueryComponent(entityType)}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _coachServerException(response.statusCode, response.body, 'sync');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['entities'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> upsertSyncEntity({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    required int baseRevision,
  }) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    final response = await _client
        .post(
          Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/sync'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'entityType': entityType,
            'entityId': entityId,
            'baseRevision': baseRevision,
            'payload': payload,
          }),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _coachServerException(response.statusCode, response.body, 'sync');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    String operation,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _coachServerException(
        response.statusCode,
        response.body,
        operation,
      );
      if (response.statusCode == 401 || error.code == 'session_expired') {
        _invalidateSession();
      }
      throw error;
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      throw CoachApiException('${operation}_invalid_response');
    }
    return payload;
  }

  Future<Map<String, dynamic>> verifyApplePurchase({
    required String productId,
    required String verificationData,
    String? transactionId,
    String? localOrderId,
  }) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    final response = await _client
        .post(
          Uri.parse(
            '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/membership/apple/verify',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'productId': productId,
            'verificationData': verificationData,
            if (transactionId?.isNotEmpty == true)
              'transactionId': transactionId,
            if (localOrderId?.isNotEmpty == true) 'localOrderId': localOrderId,
          }),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _coachServerException(
        response.statusCode,
        response.body,
        'membership_verify',
      );
      if (response.statusCode == 401 || error.code == 'session_expired') {
        _invalidateSession();
      }
      throw error;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Stream<CoachStreamEvent> streamAnswer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> toolResults = const [],
  }) {
    final controller = StreamController<CoachStreamEvent>();
    final client = http.Client();
    controller.onListen = () async {
      try {
        final token = _sessionToken;
        if (token == null || token.isEmpty) {
          throw const CoachApiException('coach_unauthenticated');
        }
        final request =
            http.Request(
                'POST',
                Uri.parse(
                  '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/coach/stream',
                ),
              )
              ..headers.addAll({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              })
              ..body = jsonEncode({
                'question': prompt,
                'locale': locale,
                ..._clientTimeContext,
                'useTrainingData': includeTrainingSummary,
                if (includeTrainingSummary &&
                    trainingSummary?.trim().isNotEmpty == true)
                  'trainingSummary': trainingSummary!.trim(),
                if (exerciseCatalog.isNotEmpty)
                  'exerciseCatalog': exerciseCatalog,
                if (skills.isNotEmpty) 'skills': skills,
                if (requestId?.trim().isNotEmpty == true)
                  'requestId': requestId!.trim(),
                if (conversationId?.trim().isNotEmpty == true)
                  'conversationId': conversationId!.trim(),
                if (toolResults.isNotEmpty) 'toolResults': toolResults,
              });
        final response = await client.send(request).timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await response.stream.bytesToString();
          final error = _coachServerException(
            response.statusCode,
            body,
            'coach',
          );
          if (response.statusCode == 401 || error.code == 'session_expired') {
            _invalidateSession();
          }
          throw error;
        }
        var buffer = '';
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;
          final blocks = buffer.split(RegExp(r'\r?\n\r?\n'));
          buffer = blocks.removeLast();
          for (final block in blocks) {
            String? event;
            String? data;
            for (final line in block.split(RegExp(r'\r?\n'))) {
              if (line.startsWith('event:')) event = line.substring(6).trim();
              if (line.startsWith('data:')) data = line.substring(5).trim();
            }
            if (data == null || data.isEmpty) continue;
            final payload = jsonDecode(data) as Map<String, dynamic>;
            if (event == 'delta') {
              final text = payload['text']?.toString() ?? '';
              if (text.isNotEmpty && !controller.isClosed) {
                controller.add(CoachStreamDelta(text));
              }
            } else if (event == 'done' && !controller.isClosed) {
              controller.add(CoachStreamDone(_answerFromPayload(payload)));
            } else if (event == 'error') {
              throw CoachApiException(
                payload['code']?.toString() ?? 'coach_stream_failed',
              );
            }
          }
        }
        await controller.close();
      } on TimeoutException {
        controller.addError(const CoachApiException('coach_timeout'));
        await controller.close();
      } on http.ClientException {
        controller.addError(const CoachApiException('coach_network'));
        await controller.close();
      } catch (error) {
        controller.addError(error);
        await controller.close();
      } finally {
        client.close();
      }
    };
    controller.onCancel = client.close;
    return controller.stream;
  }

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> availableTools = const [],
    List<Map<String, dynamic>> toolResults = const [],
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/coach/answer',
    );
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'question': prompt,
              ..._clientTimeContext,
              if (requestId?.trim().isNotEmpty == true) 'requestId': requestId,
              if (conversationId?.trim().isNotEmpty == true)
                'conversationId': conversationId!.trim(),
              'locale': locale,
              'useTrainingData': includeTrainingSummary,
              if (includeTrainingSummary &&
                  trainingSummary?.trim().isNotEmpty == true)
                'trainingSummary': trainingSummary!.trim(),
              if (exerciseCatalog.isNotEmpty)
                'exerciseCatalog': exerciseCatalog,
              if (skills.isNotEmpty) 'skills': skills,
              if (includeTrainingSummary && availableTools.isNotEmpty)
                'availableTools': availableTools,
              if (toolResults.isNotEmpty) 'toolResults': toolResults,
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const CoachApiException('coach_timeout');
    } on http.ClientException {
      throw const CoachApiException('coach_network');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _coachServerException(
        response.statusCode,
        response.body,
        'coach',
      );
      if (response.statusCode == 401 || error.code == 'session_expired') {
        _invalidateSession();
      }
      throw error;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return _answerFromPayload(payload);
  }

  CoachAnswer _answerFromPayload(Map<String, dynamic> payload) {
    final citations = (payload['citations'] as List<dynamic>? ?? const [])
        .map((item) {
          if (item is! Map<String, dynamic>) return item.toString();
          final title = (item['title'] ?? item['detail'] ?? '').toString();
          final source = (item['source'] ?? '').toString();
          return source.isEmpty || source == title ? title : '$title｜$source';
        })
        .where((item) => item.isNotEmpty)
        .toList();
    final toolCalls = (payload['toolCalls'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final rawArguments = item['arguments'];
          Map<String, dynamic> arguments;
          if (rawArguments is Map<String, dynamic>) {
            arguments = rawArguments;
          } else {
            try {
              final parsed = jsonDecode(rawArguments?.toString() ?? '{}');
              arguments = parsed is Map<String, dynamic>
                  ? parsed
                  : <String, dynamic>{};
            } on FormatException {
              arguments = <String, dynamic>{};
            }
          }
          return CoachToolCall(
            id: (item['id'] ?? '').toString(),
            name: (item['name'] ?? '').toString(),
            arguments: arguments,
          );
        })
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .take(3)
        .toList();
    final toolUses = (payload['toolUses'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => CoachToolUse(
            name: (item['name'] ?? '').toString(),
            count: (((item['count'] as num?)?.toInt() ?? 0).clamp(
              0,
              3,
            )).toInt(),
          ),
        )
        .where((item) => item.name.isNotEmpty && item.count > 0)
        .toList();
    final planPayload = payload['plan'];
    AiPlanDraft? plan;
    if (planPayload is Map<String, dynamic>) {
      final sessions = (planPayload['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final exercises = (item['exercises'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map((exercise) {
                  final id = (exercise['exerciseId'] ?? '').toString();
                  final sets = (exercise['sets'] as List<dynamic>? ?? const [])
                      .whereType<Map<String, dynamic>>()
                      .map(
                        (set) => AiPlanSetDraft(
                          type: (set['type'] ?? 'work').toString(),
                          weight: (set['weight'] as num?)?.toDouble() ?? 0,
                          reps: (set['reps'] as num?)?.toInt() ?? 8,
                          restSeconds:
                              (set['restSeconds'] as num?)?.toInt() ?? 90,
                        ),
                      )
                      .toList();
                  return AiPlanExerciseDraft(
                    exerciseId: id,
                    sets: sets,
                    note: (exercise['note'] ?? '').toString().trim(),
                  );
                })
                .where(
                  (exercise) =>
                      exercise.exerciseId.isNotEmpty &&
                      exercise.sets.isNotEmpty,
                )
                .toList();
            final legacyIds =
                (item['exerciseIds'] as List<dynamic>? ?? const [])
                    .map((id) => id.toString())
                    .where((id) => id.isNotEmpty)
                    .toList();
            return AiPlanSession(
              dayOffset: (item['dayOffset'] as num?)?.toInt() ?? 0,
              name: (item['name'] ?? '训练').toString(),
              exerciseIds: exercises.isEmpty
                  ? legacyIds
                  : exercises.map((exercise) => exercise.exerciseId).toList(),
              exercises: exercises,
            );
          })
          .where((session) => session.effectiveExerciseIds.isNotEmpty)
          .toList();
      if (sessions.isNotEmpty) {
        plan = AiPlanDraft(
          title: (planPayload['title'] ?? 'AI 训练计划').toString(),
          weeks: ((planPayload['weeks'] as num?)?.toInt() ?? 1)
              .clamp(1, 8)
              .toInt(),
          sessions: sessions,
        );
      }
    }
    return CoachAnswer(
      body: (payload['answer'] ?? payload['body'] ?? '').toString(),
      conversationId: payload['conversationId']?.toString(),
      citations: citations,
      plan: plan,
      toolCalls: toolCalls,
      toolUses: toolUses,
    );
  }

  static DateTime? _sessionExpiry(Object? rawSession) {
    if (rawSession is! Map<String, dynamic>) return null;
    return DateTime.tryParse((rawSession['expiresAt'] ?? '').toString());
  }

  static int _nonNegativeInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed ?? fallback).clamp(0, 86400).toInt();
  }
}

CoachApiException _coachServerException(
  int statusCode,
  String responseBody,
  String operation,
) {
  try {
    final payload = jsonDecode(responseBody);
    if (payload is Map<String, dynamic>) {
      final serverCode = payload['error']?.toString() ?? '';
      if (serverCode.isNotEmpty) return CoachApiException(serverCode);
    }
  } on FormatException {
    // Preserve the HTTP fallback for non-JSON proxy and tunnel responses.
  }
  return CoachApiException('${operation}_http_$statusCode');
}

class CoachApiException implements Exception {
  const CoachApiException(this.code);

  final String code;

  @override
  String toString() => code;
}

/// Explicit no-op adapter used until a server endpoint is configured.
class UnconfiguredCoachApi implements CoachApi {
  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
    String? conversationId,
  }) async => const CoachAnswer(body: 'AI 服务未配置，请在设置中配置 Coach 服务后重试。');
}
