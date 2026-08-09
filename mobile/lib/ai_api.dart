import 'dart:convert';

import 'package:http/http.dart' as http;

class CoachAnswer {
  const CoachAnswer({required this.body, this.citations = const []});
  final String body;
  final List<String> citations;
}

/// Client boundary for the server-owned `/v1/coach/answer` endpoint.
/// Authentication and model keys stay on the server; this client only receives
/// a user prompt, optional consented summary and a JSON answer.
abstract interface class CoachApi {
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String? trainingSummary,
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
          (item) => item is Map<String, dynamic>
              ? (item['title'] ?? item['detail'] ?? '').toString()
              : item.toString(),
        )
        .where((item) => item.isNotEmpty)
        .toList();
    return CoachAnswer(
      body: (payload['answer'] ?? payload['body'] ?? '').toString(),
      citations: citations,
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
  }) async => const CoachAnswer(body: 'AI 服务未配置，请在设置中配置 Coach 服务后重试。');
}
