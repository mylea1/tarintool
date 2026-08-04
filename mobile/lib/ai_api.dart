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
  Future<CoachAnswer> answer({required String prompt, required bool includeTrainingSummary});
}

class HttpCoachApi implements CoachApi {
  HttpCoachApi({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;

  @override
  Future<CoachAnswer> answer({required String prompt, required bool includeTrainingSummary}) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/coach/answer');
    final response = await _client.post(uri, headers: const {'Content-Type': 'application/json'}, body: jsonEncode({'question': prompt, 'useTrainingData': includeTrainingSummary})).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('coach_http_${response.statusCode}');
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final citations = (payload['citations'] as List<dynamic>? ?? const []).map((item) => item is Map<String, dynamic> ? (item['title'] ?? item['detail'] ?? '').toString() : item.toString()).where((item) => item.isNotEmpty).toList();
    return CoachAnswer(body: (payload['answer'] ?? payload['body'] ?? '').toString(), citations: citations);
  }
}

class MockCoachApi implements CoachApi {
  @override
  Future<CoachAnswer> answer({required String prompt, required bool includeTrainingSummary}) async => CoachAnswer(body: includeTrainingSummary ? '根据已授权的训练摘要，建议先保持当前重量并记录 RPE。' : '可以先保持当前重量，记录 RPE 后再决定是否加重。', citations: includeTrainingSummary ? const ['KILO 训练记录摘要'] : const ['NSCA · Resistance Training Guidelines']);
}
