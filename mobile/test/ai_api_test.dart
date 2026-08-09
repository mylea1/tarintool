import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/ai_api.dart';

void main() {
  test('coach client signs in and forwards bearer token', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      if (request.url.path == '/v1/auth/phone/login') {
        expect(jsonDecode(request.body), {
          'identifier': '123',
          'password': '123',
        });
        return http.Response(
          jsonEncode({
            'session': {'token': 'test-session-token'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/v1/coach/answer');
      expect(request.headers['authorization'], 'Bearer test-session-token');
      return http.Response(
        jsonEncode({
          'answer': '训练建议',
          'citations': [
            {'title': '知识库条目'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: client,
    );

    await api.signIn(identifier: '123', password: '123');
    final answer = await api.answer(
      prompt: '今天怎么练？',
      includeTrainingSummary: true,
    );

    expect(requestCount, 2);
    expect(answer.body, '训练建议');
    expect(answer.citations, ['知识库条目']);
  });

  test(
    'coach client never calls protected endpoint without a session',
    () async {
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((_) async => http.Response('{}', 500)),
      );

      expect(
        () => api.answer(prompt: 'test', includeTrainingSummary: false),
        throwsA(
          isA<CoachApiException>().having(
            (error) => error.code,
            'code',
            'coach_unauthenticated',
          ),
        ),
      );
    },
  );

  test(
    'coach client forwards an explicitly consented training summary',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'summary-session'},
            }),
            200,
          );
        }
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({'answer': 'ok'}), 200);
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );

      await api.signIn(identifier: '123', password: '123');
      await api.answer(
        prompt: 'plan my training',
        includeTrainingSummary: true,
        trainingSummary: 'last workout: squat 80 kg x 8',
      );

      expect(bodies.single['useTrainingData'], true);
      expect(bodies.single['trainingSummary'], 'last workout: squat 80 kg x 8');
    },
  );
}
