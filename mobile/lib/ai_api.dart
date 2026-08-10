import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class CoachAnswer {
  const CoachAnswer({
    required this.body,
    this.citations = const [],
    this.plan,
  });
  final String body;
  final List<String> citations;
  final AiPlanDraft? plan;
}

/// Client boundary for the server-owned `/v1/coach/answer` endpoint.
/// Authentication and model keys stay on the server; this client only receives
/// a user prompt, optional consented summary and a JSON answer.
abstract interface class CoachApi {
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
  });
}

class HttpCoachApi implements CoachApi {
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
      throw CoachApiException('coach_auth_http_${response.statusCode}');
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

  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/coach/answer',
    );
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const CoachApiException('coach_unauthenticated');
    }
    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'question': prompt,
            'useTrainingData': includeTrainingSummary,
            if (includeTrainingSummary &&
                trainingSummary?.trim().isNotEmpty == true)
              'trainingSummary': trainingSummary!.trim(),
            if (exerciseCatalog.isNotEmpty) 'exerciseCatalog': exerciseCatalog,
          }),
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) clearSession();
      throw CoachApiException('coach_http_${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final citations = (payload['citations'] as List<dynamic>? ?? const [])
        .map(
          (item) {
            if (item is! Map<String, dynamic>) return item.toString();
            final title = (item['title'] ?? item['detail'] ?? '').toString();
            final source = (item['source'] ?? '').toString();
            return source.isEmpty || source == title ? title : '$title｜$source';
          },
        )
        .where((item) => item.isNotEmpty)
        .toList();
    final planPayload = payload['plan'];
    AiPlanDraft? plan;
    if (planPayload is Map<String, dynamic>) {
      final sessions = (planPayload['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => AiPlanSession(
              dayOffset: (item['dayOffset'] as num?)?.toInt() ?? 0,
              name: (item['name'] ?? '训练').toString(),
              exerciseIds: (item['exerciseIds'] as List<dynamic>? ?? const [])
                  .map((id) => id.toString())
                  .where((id) => id.isNotEmpty)
                  .toList(),
            ),
          )
          .where((session) => session.exerciseIds.isNotEmpty)
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
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
  }) async => const CoachAnswer(body: 'AI 服务未配置，请在设置中配置 Coach 服务后重试。');
}
