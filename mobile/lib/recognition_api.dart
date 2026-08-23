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
    bool includeOverlay = false,
    void Function(RecognitionProgressUpdate update)? onProgress,
  });
}

class RecognitionResult {
  const RecognitionResult({
    required this.status,
    required this.confidence,
    required this.summary,
    this.repetitions = 0,
    this.error,
    this.overlayUrl,
    this.previewUrl,
    this.events = const <RecognitionEvent>[],
    this.mediaHeaders = const <String, String>{},
    this.metrics = const <String, dynamic>{},
    this.aiReview,
    this.aiReviewError,
  });

  final RecognitionStatus status;
  final double confidence;

  /// Legacy API compatibility only. Recognition UI must use [events].
  final int repetitions;
  final String summary;
  final String? error;
  final String? overlayUrl;
  final String? previewUrl;
  final List<RecognitionEvent> events;
  final Map<String, String> mediaHeaders;
  final Map<String, dynamic> metrics;
  final RecognitionAiReview? aiReview;
  final String? aiReviewError;
}

class RecognitionEvent {
  const RecognitionEvent({
    required this.id,
    required this.code,
    required this.label,
    required this.startMs,
    required this.peakMs,
    required this.endMs,
    required this.displayTime,
    required this.explanation,
    required this.confidence,
    this.stage = '',
    this.evidenceImageUrl,
    this.measurements = const <String, dynamic>{},
  });

  final String id;
  final String code;
  final String label;
  final int startMs;
  final int peakMs;
  final int endMs;
  final String displayTime;
  final String explanation;
  final double confidence;
  final String stage;
  final String? evidenceImageUrl;
  final Map<String, dynamic> measurements;

  String get timeRangeLabel {
    if (endMs <= startMs) return displayTime;
    return '${_formatMs(startMs)}-${_formatMs(endMs)}';
  }

  static String _formatMs(int value) {
    final seconds = value.clamp(0, 1 << 31) / 1000;
    final minutes = seconds ~/ 60;
    final remainder = seconds - minutes * 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toStringAsFixed(1).padLeft(4, '0')}';
  }
}

class RecognitionAiReview {
  const RecognitionAiReview({
    required this.headline,
    this.strengths = const <String>[],
    this.risks = const <String>[],
    this.nextSet = '',
    this.basis = '',
  });

  final String headline;
  final List<String> strengths;
  final List<String> risks;
  final String nextSet;
  final String basis;

  factory RecognitionAiReview.fromJson(Map<String, dynamic> json) =>
      RecognitionAiReview(
        headline: (json['headline'] ?? '动作分析已完成').toString(),
        strengths: _stringList(json['strengths']),
        risks: _stringList(json['risks']),
        nextSet: (json['nextSet'] ?? '').toString(),
        basis: (json['basis'] ?? '').toString(),
      );

  static List<String> _stringList(Object? value) => value is List<dynamic>
      ? value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
      : const <String>[];
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

  Future<List<RecognitionCapability>> capabilities() async {
    try {
      final response = await _client
          .get(Uri.parse('$_origin/v1/analysis/capabilities'))
          .timeout(requestTimeout);
      final payload = _decodeResponse(response, 'recognition_capabilities');
      final rawItems = payload['exercises'];
      if (rawItems is! List<dynamic>) return fallbackRecognitionCapabilities;
      final result = <RecognitionCapability>[];
      for (final raw in rawItems.whereType<Map<String, dynamic>>()) {
        final exerciseId = (raw['exerciseId'] ?? '').toString();
        final rawCameras = raw['cameras'];
        if (exerciseId.isEmpty || rawCameras is! List<dynamic>) continue;
        final cameras = <RecognitionCameraOption>[];
        for (final camera in rawCameras.whereType<Map<String, dynamic>>()) {
          final id = (camera['id'] ?? '').toString();
          final label = (camera['label'] ?? '').toString();
          if (id.isEmpty || label.isEmpty) continue;
          cameras.add(
            RecognitionCameraOption(
              id: id,
              label: label,
              hint: (camera['hint'] ?? '').toString(),
            ),
          );
        }
        if (cameras.isNotEmpty) {
          result.add(
            RecognitionCapability(
              exerciseId: exerciseId,
              cameras: cameras,
              group: raw['group']?.toString() ?? '其他',
            ),
          );
        }
      }
      return result.isEmpty ? fallbackRecognitionCapabilities : result;
    } catch (_) {
      return fallbackRecognitionCapabilities;
    }
  }

  @override
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
    required String mediaPath,
    bool includeOverlay = false,
    void Function(RecognitionProgressUpdate update)? onProgress,
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
      onProgress?.call(
        const RecognitionProgressUpdate(stage: RecognitionStage.preparing),
      );
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
              'includeOverlay': includeOverlay,
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

      await _upload(
        file,
        _urlAgainstConfiguredOrigin(uploadUrl),
        onProgress: onProgress,
      );
      return await _poll(jobId, token, onProgress: onProgress);
    } on TimeoutException {
      throw const RecognitionApiException('recognition_timeout');
    } on SocketException {
      throw const RecognitionApiException('recognition_network');
    } on http.ClientException {
      throw const RecognitionApiException('recognition_network');
    }
  }

  Future<void> _upload(
    File file,
    Uri uri, {
    void Function(RecognitionProgressUpdate update)? onProgress,
  }) async {
    final request = http.StreamedRequest('PUT', uri);
    request.headers['Content-Type'] = _contentType(file.path);
    final totalBytes = await file.length();
    request.contentLength = totalBytes;
    final responseFuture = _client.send(request).timeout(uploadTimeout);
    var sentBytes = 0;
    onProgress?.call(
      RecognitionProgressUpdate(
        stage: RecognitionStage.uploading,
        fraction: 0,
        sentBytes: 0,
        totalBytes: totalBytes,
      ),
    );
    await request.sink.addStream(
      file.openRead().map((chunk) {
        sentBytes += chunk.length;
        onProgress?.call(
          RecognitionProgressUpdate(
            stage: RecognitionStage.uploading,
            fraction: totalBytes == 0 ? 0 : sentBytes / totalBytes,
            sentBytes: sentBytes,
            totalBytes: totalBytes,
          ),
        );
        return chunk;
      }),
    );
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

  Future<RecognitionResult> _poll(
    String jobId,
    String token, {
    void Function(RecognitionProgressUpdate update)? onProgress,
  }) async {
    final deadline = DateTime.now().add(resultTimeout);
    var lastStage = RecognitionStage.idle;
    var consecutiveNetworkFailures = 0;
    while (DateTime.now().isBefore(deadline)) {
      Map<String, dynamic> payload;
      try {
        final response = await _client
            .get(
              Uri.parse('$_origin/v1/analysis/jobs/$jobId'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(requestTimeout);
        payload = _decodeResponse(response, 'recognition_status');
        consecutiveNetworkFailures = 0;
      } on TimeoutException {
        consecutiveNetworkFailures += 1;
        if (consecutiveNetworkFailures >= 3) rethrow;
        await Future<void>.delayed(pollInterval);
        continue;
      } on SocketException {
        consecutiveNetworkFailures += 1;
        if (consecutiveNetworkFailures >= 3) rethrow;
        await Future<void>.delayed(pollInterval);
        continue;
      } on http.ClientException {
        consecutiveNetworkFailures += 1;
        if (consecutiveNetworkFailures >= 3) rethrow;
        await Future<void>.delayed(pollInterval);
        continue;
      } on RecognitionApiException catch (error) {
        if (!RegExp(r'^recognition_status_http_5\d\d$').hasMatch(error.code)) {
          rethrow;
        }
        consecutiveNetworkFailures += 1;
        if (consecutiveNetworkFailures >= 3) rethrow;
        await Future<void>.delayed(pollInterval);
        continue;
      }
      final status = (payload['status'] ?? '').toString();
      final stage = status == 'processing'
          ? RecognitionStage.analyzing
          : RecognitionStage.queued;
      if (stage != lastStage) {
        lastStage = stage;
        onProgress?.call(RecognitionProgressUpdate(stage: stage));
      }
      if (status == 'completed') return _completedResult(payload, token);
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

  RecognitionResult _completedResult(
    Map<String, dynamic> payload,
    String token,
  ) {
    final result = payload['result'];
    final body = result is Map<String, dynamic>
        ? result
        : const <String, dynamic>{};
    final confidence = (body['confidence'] as num?)?.toDouble() ?? 0;
    final media = payload['media'];
    final mediaMap = media is Map<String, dynamic>
        ? media
        : const <String, dynamic>{};
    final rawMetrics = body['metrics'];
    final rawReview = body['aiReview'];
    final rawEvents = body['events'];
    final events = <RecognitionEvent>[];
    if (rawEvents is List<dynamic>) {
      for (final item in rawEvents.whereType<Map<String, dynamic>>()) {
        final rawMeasurements = item['measurements'];
        events.add(
          RecognitionEvent(
            id: (item['id'] ?? item['evidenceId'] ?? '').toString(),
            code: (item['code'] ?? '').toString(),
            label: (item['label'] ?? '动作提示').toString(),
            startMs: (item['startMs'] as num?)?.toInt() ?? 0,
            peakMs: (item['peakMs'] as num?)?.toInt() ?? 0,
            endMs: (item['endMs'] as num?)?.toInt() ?? 0,
            displayTime: (item['displayTime'] ?? '00:00.0').toString(),
            explanation: (item['explanation'] ?? '').toString(),
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
            stage: (item['stage'] ?? '').toString(),
            evidenceImageUrl: _optionalMediaUrl(item['evidenceImageUrl']),
            measurements: rawMeasurements is Map<String, dynamic>
                ? Map<String, dynamic>.unmodifiable(rawMeasurements)
                : const <String, dynamic>{},
          ),
        );
      }
    }
    return RecognitionResult(
      // Confidence remains available for diagnostics, but a completed server
      // job is a completed user task. Never turn an internal score into a
      // user-facing failure state.
      status: RecognitionStatus.complete,
      confidence: confidence,
      repetitions: (body['repetitions'] as num?)?.toInt() ?? 0,
      summary: (body['summary'] ?? '动作分析已完成').toString(),
      overlayUrl: _optionalMediaUrl(mediaMap['overlay']),
      previewUrl: _optionalMediaUrl(mediaMap['preview']),
      events: List<RecognitionEvent>.unmodifiable(events),
      mediaHeaders: {'Authorization': 'Bearer $token'},
      metrics: rawMetrics is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(rawMetrics)
          : const <String, dynamic>{},
      aiReview: rawReview is Map<String, dynamic>
          ? RecognitionAiReview.fromJson(rawReview)
          : null,
      aiReviewError: body['aiReviewError']?.toString(),
    );
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
    String operation,
  ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) clearSession();
      try {
        final errorPayload = jsonDecode(response.body);
        if (errorPayload is Map<String, dynamic>) {
          final serverCode = errorPayload['error']?.toString() ?? '';
          if (serverCode.isNotEmpty) {
            throw RecognitionApiException(serverCode);
          }
        }
      } on RecognitionApiException {
        rethrow;
      } on FormatException {
        // Fall through to the HTTP status based diagnostic below.
      }
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

  static String _errorSummary(String error) => recognitionErrorMessage(error);
}

String recognitionErrorMessage(String error) => switch (error) {
  'video_too_long' => '视频时长超出限制，请裁剪后重试。',
  'invalid_video' => '无法读取该视频，请重新选择。',
  'invalid_video_dimensions' => '无法读取视频尺寸，请转换为 MP4 后重试。',
  'empty_video' => '视频中没有可分析的画面，请重新选择。',
  'video_writer_unavailable' => '服务器暂时无法生成结果视频，请稍后重试。',
  'overlay_encoding_failed' => '服务器暂时无法生成兼容的标注视频，请稍后重试。',
  'quota_exhausted' => '本周动作识别次数已用完。',
  'recognition_timeout' ||
  'recognition_result_timeout' => '服务器分析超时，视频已保留，请稍后直接重试。',
  'recognition_network' => '网络连接中断，视频已保留，请检查网络后重试。',
  'recognition_unauthenticated' ||
  'recognition_auth_token_missing' => '登录状态已失效，请重新登录后重试。',
  'compute_processing_failed' => '分析服务处理失败，视频已保留，请直接重试。',
  'recognition_exercise_unsupported' ||
  'recognition_camera_unsupported' => '暂不支持当前动作或拍摄角度，请更换后重试。',
  _ when error.startsWith('recognition_upload_http_') => '视频上传失败，视频已保留，请直接重试。',
  _ when error.startsWith('recognition_create_http_') => '无法创建识别任务，请稍后重试。',
  _ => '动作识别失败（$error），视频已保留，可直接重试。',
};

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
    bool includeOverlay = false,
    void Function(RecognitionProgressUpdate update)? onProgress,
  }) async {
    return const RecognitionResult(
      status: RecognitionStatus.error,
      confidence: 0,
      repetitions: 0,
      summary: '动作分析暂时不可用，请稍后重试。',
      error: 'service_not_configured',
    );
  }
}
