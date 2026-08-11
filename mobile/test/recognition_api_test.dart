import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';

void main() {
  test('HTTP recognition uploads through configured origin and polls result', () async {
    var statusRequests = 0;
    late final List<int> uploadedBytes;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(jsonEncode({'session': {'token': 'session-token'}}), 200);
      }
      if (request.url.path == '/v1/analysis/jobs' && request.method == 'POST') {
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response(
          jsonEncode({
            'id': 'job-1',
            'upload': {
              'url': 'https://blocked.example/v1/analysis/jobs/job-1/upload?token=upload-token',
            },
          }),
          202,
        );
      }
      if (request.url.path.endsWith('/upload')) {
        expect(request.method, 'PUT');
        expect(request.url.host, 'test-api.example');
        uploadedBytes = request.bodyBytes;
        return http.Response('{}', 200);
      }
      if (request.url.path == '/v1/analysis/jobs/job-1') {
        statusRequests += 1;
        if (statusRequests == 1) {
          return http.Response(jsonEncode({'status': 'processing'}), 200);
        }
        return http.Response(
          jsonEncode({
            'status': 'completed',
            'result': {
              'confidence': 0.82,
              'repetitions': 7,
              'summary': '动作骨骼提取完成',
            },
            'media': {
              'overlay': 'https://blocked.example/v1/analysis/jobs/job-1/media/overlay',
              'preview': 'https://blocked.example/v1/analysis/jobs/job-1/media/preview',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });
    final temp = await Directory.systemTemp.createTemp('kilo-recognition-test-');
    addTearDown(() => temp.delete(recursive: true));
    final video = File('${temp.path}/sample.mp4');
    await video.writeAsBytes([1, 2, 3, 4]);
    final api = HttpRecognitionApi(
      baseUrl: 'https://test-api.example',
      client: client,
      pollInterval: Duration.zero,
    );

    await api.signIn(identifier: '1234', password: '1234');
    final result = await api.analyze(
      exerciseId: 'curl',
      camera: 'front',
      scenario: 'gym',
      mediaPath: video.path,
    );

    expect(uploadedBytes, [1, 2, 3, 4]);
    expect(statusRequests, 2);
    expect(result.status, RecognitionStatus.complete);
    expect(result.confidence, 0.82);
    expect(result.repetitions, 7);
    expect(result.overlayUrl, contains('test-api.example'));
  });
}
