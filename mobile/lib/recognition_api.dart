import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Stable client boundary for the BetterCoach recognition service.
abstract interface class RecognitionApi {
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
    required String mediaPath,
  });
}

class RecognitionResult {
  const RecognitionResult({
    required this.status,
    required this.confidence,
    required this.repetitions,
    required this.summary,
    this.error,
    this.overlayUrl,
    this.previewUrl,
  });

  final RecognitionStatus status;
  final double confidence;
  final int repetitions;
  final String summary;
  final String? error;
  final String? overlayUrl;
  final String? previewUrl;
}

class HttpRecognitionApi implements RecognitionApi {
  HttpRecognitionApi({
    required this.baseUrl,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 60),
    this.uploadTimeout = const Duration(minutes: 3),
    this.resultTimeout = const Duration(minutes: 4),
    this.pollInterval = const Duration(seconds: 2),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Duration requestTimeout;
  final Duration uploadTimeout;
  final Duration resultTimeout;
  final Duration pollInterval;
  String? _sessionToken;

  bool get hasSession => _sessionToken?.isNotEmpty == true;
  String get _origin => baseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_origin/v1/auth/phone/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'identifier': identifier, 'password': password}),
        )
        .timeout(requestTimeout);
    final payload = _decodeResponse(response, 'recognition_auth');
    final session = payload['session'];
    final token = session is Map<String, dynamic>
        ? (session['token'] ?? '').toString()
        : '';
    if (token.isEmpty) {
      throw const RecognitionApiException('recognition_auth_token_missing');
    }
    _sessionToken = token;
  }

  void clearSession() => _sessionToken = null;

  @override
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
    required String mediaPath,
  }) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      throw const RecognitionApiException('recognition_unauthenticated');
    }
    final file = File(mediaPath);
    if (!await file.exists()) {
      throw const RecognitionApiException('recognition_file_missing');
    }

    try {
      final createdResponse = await _client
          .post(
            Uri.parse('$_origin/v1/analysis/jobs'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'exerciseId': exerciseId,
              'camera': camera,
              'scenario': scenario,
            }),
          )
          .timeout(requestTimeout);
      final created = _decodeResponse(createdResponse, 'recognition_create');
      final jobId = (created['id'] ?? '').toString();
      final upload = created['upload'];
      final uploadUrl = upload is Map<String, dynamic>
          ? (upload['url'] ?? '').toString()
          : '';
      if (jobId.isEmpty || uploadUrl.isEmpty) {
        throw const RecognitionApiException('recognition_job_invalid');
      }

      await _upload(file, _urlAgainstConfiguredOrigin(uploadUrl));
      return await _poll(jobId, token);
    } on TimeoutException {
      throw const RecognitionApiException('recognition_timeout');
    } on SocketException {
      throw const RecognitionApiException('recognition_network');
    } on http.ClientException {
      throw const RecognitionApiException('recognition_network');
    }
  }

  Future<void> _upload(File file, Uri uri) async {
    final request = http.StreamedRequest('PUT', uri);
    request.headers['Content-Type'] = _contentType(file.path);
    request.contentLength = await file.length();
    final responseFuture = _client.send(request).timeout(uploadTimeout);
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final response = await responseFuture;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw RecognitionApiException(
        'recognition_upload_http_${response.statusCode}',
      );
    }
    await response.stream.drain<void>();
  }

  Future<RecognitionResult> _poll(String jobId, String token) async {
    final deadline = DateTime.now().add(resultTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final response = await _client
          .get(
            Uri.parse('$_origin/v1/analysis/jobs/$jobId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(requestTimeout);
      final payload = _decodeResponse(response, 'recognition_status');
      final status = (payload['status'] ?? '').toString();
      if (status == 'completed') return _completedResult(payload);
      if (status == 'failed' || status == 'cancelled' || status == 'expired') {
        final error = (payload['error'] ?? status).toString();
        return RecognitionResult(
          status: RecognitionStatus.error,
          confidence: 0,
          repetitions: 0,
          summary: _errorSummary(error),
          error: error,
        );
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const RecognitionApiException('recognition_result_timeout');
  }

  RecognitionResult _completedResult(Map<String, dynamic> payload) {
    final result = payload['result'];
    final body = result is Map<String, dynamic>
        ? result
        : const <String, dynamic>{};
    final confidence = (body['confidence'] as num?)?.toDouble() ?? 0;
    final media = payload['media'];
    final mediaMap = media is Map<String, dynamic>
        ? media
        : const <String, dynamic>{};
    return RecognitionResult(
      status: confidence >= 0.45
          ? RecognitionStatus.complete
          : RecognitionStatus.lowConfidence,
      confidence: confidence,
      repetitions: (body['repetitions'] as num?)?.toInt() ?? 0,
      summary: (body['summary'] ?? '动作分析已完成').toString(),
      overlayUrl: _optionalMediaUrl(mediaMap['overlay']),
      previewUrl: _optionalMediaUrl(mediaMap['preview']),
    );
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String operation,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) clearSession();
      throw RecognitionApiException('${operation}_http_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw RecognitionApiException('${operation}_invalid_json');
    }
    return decoded;
  }

  Uri _urlAgainstConfiguredOrigin(String value) {
    final supplied = Uri.parse(value);
    final origin = Uri.parse(_origin);
    return origin.replace(path: supplied.path, query: supplied.query);
  }

  String? _optionalMediaUrl(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return _urlAgainstConfiguredOrigin(text).toString();
  }

  static String _contentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }

  static String _errorSummary(String error) => switch (error) {
    'video_too_long' => '视频时长超出限制，请裁剪后重试。',
    'invalid_video' => '无法读取该视频，请重新选择。',
    'quota_exhausted' => '本周动作识别次数已用完。',
    _ => '动作识别失败，请稍后重试。',
  };
}

class RecognitionApiException implements Exception {
  const RecognitionApiException(this.code);

  final String code;

  @override
  String toString() => code;
}

class UnconfiguredRecognitionApi implements RecognitionApi {
  @override
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
    required String mediaPath,
  }) async {
    return const RecognitionResult(
      status: RecognitionStatus.error,
      confidence: 0,
      repetitions: 0,
      summary: '识别服务未配置，请在设置中配置服务后重试。',
      error: 'service_not_configured',
    );
  }
}
