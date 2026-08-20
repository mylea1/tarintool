import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class CoachAnswer {
  const CoachAnswer({required this.body, this.citations = const [], this.plan});
  final String body;
  final List<String> citations;
  final AiPlanDraft? plan;
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
  });
}

class HttpCoachApi implements CoachApi, StreamingCoachApi {
  HttpCoachApi({
    required this.baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  final Duration requestTimeout;
  String? _sessionToken;

  bool get hasSession => _sessionToken?.isNotEmpty == true;

  Future<void> signIn({
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
    _sessionToken = token;
  }

  void clearSession() => _sessionToken = null;

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

  Future<Map<String, dynamic>> fetchCheckinStatus() async {
    final response = await _client
        .get(_endpoint('/v1/checkin/status'), headers: _authHeaders)
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'checkin_status');
  }

  Future<Map<String, dynamic>> checkIn() async {
    final response = await _client
        .post(_endpoint('/v1/checkin'), headers: _authHeaders, body: '{}')
        .timeout(requestTimeout);
    return _decodeJsonResponse(response, 'checkin');
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response,
    String operation,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) clearSession();
      throw _coachServerException(
        response.statusCode,
        response.body,
        operation,
      );
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
      throw _coachServerException(
        response.statusCode,
        response.body,
        'membership_verify',
      );
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
                'useTrainingData': includeTrainingSummary,
                if (includeTrainingSummary &&
                    trainingSummary?.trim().isNotEmpty == true)
                  'trainingSummary': trainingSummary!.trim(),
                if (exerciseCatalog.isNotEmpty)
                  'exerciseCatalog': exerciseCatalog,
                if (skills.isNotEmpty) 'skills': skills,
              });
        final response = await client.send(request).timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await response.stream.bytesToString();
          throw _coachServerException(response.statusCode, body, 'coach');
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
              'locale': locale,
              'useTrainingData': includeTrainingSummary,
              if (includeTrainingSummary &&
                  trainingSummary?.trim().isNotEmpty == true)
                'trainingSummary': trainingSummary!.trim(),
              if (exerciseCatalog.isNotEmpty)
                'exerciseCatalog': exerciseCatalog,
              if (skills.isNotEmpty) 'skills': skills,
            }),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const CoachApiException('coach_timeout');
    } on http.ClientException {
      throw const CoachApiException('coach_network');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) clearSession();
      throw _coachServerException(response.statusCode, response.body, 'coach');
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
                  return AiPlanExerciseDraft(exerciseId: id, sets: sets);
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
      citations: citations,
      plan: plan,
    );
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
  }) async => const CoachAnswer(body: 'AI 服务未配置，请在设置中配置 Coach 服务后重试。');
}
