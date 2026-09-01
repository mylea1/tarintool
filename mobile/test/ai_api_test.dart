import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/ai_api.dart';

void main() {
  test(
    'friend discovery uses masked search and stable target user IDs',
    () async {
      final seen = <String, Map<String, dynamic>>{};
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'friend-session'},
            }),
            200,
          );
        }
        if (request.body.isNotEmpty) {
          seen[request.url.path] = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
        }
        expect(request.headers['authorization'], 'Bearer friend-session');
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );
      await api.signIn(identifier: '13800138000', password: '1234');

      await api.updateFriendUsername('lifting_小林');
      await api.searchFriends('13800138001');
      await api.sendFriendRequestToUser('usr_stable_123');

      expect(seen['/v1/me/username'], {'username': 'lifting_小林'});
      expect(seen['/v1/friends/search'], {'query': '13800138001'});
      expect(seen['/v1/friends/requests'], {'targetUserId': 'usr_stable_123'});
    },
  );

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
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['clientDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(body['clientTimezoneOffsetMinutes'], isA<int>());
      expect(body['clientTimezoneName'], isA<String>());
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
    'membership client refreshes entitlements and creates a quarterly order',
    () async {
      final requests = <String, Map<String, dynamic>>{};
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'membership-session'},
            }),
            200,
          );
        }
        if (request.url.path == '/v1/membership/orders') {
          requests[request.url.path] =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'order': {
                'id': 'order-quarterly',
                'userId': 'user-1',
                'plan': 'threeMonths',
                'productId': 'com.kilostrength.pro.quarterly',
                'provider': 'app_store',
                'status': 'pending',
              },
            }),
            201,
          );
        }
        expect(request.url.path, '/v1/me/entitlements');
        expect(request.headers['authorization'], 'Bearer membership-session');
        return http.Response(
          jsonEncode({'membership': 'yearly', 'isMember': true}),
          200,
        );
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );

      await api.signIn(identifier: '13800138000', password: '1234');
      final order = await api.createMembershipOrder(
        productId: 'com.kilostrength.pro.quarterly',
        plan: 'threeMonths',
        amountMinor: 4990,
      );
      final entitlement = await api.fetchEntitlements();

      expect(requests['/v1/membership/orders'], {
        'productId': 'com.kilostrength.pro.quarterly',
        'plan': 'threeMonths',
        'provider': 'app_store',
        'currency': 'CNY',
        'amountMinor': 4990,
      });
      expect(order['order'], isA<Map<String, dynamic>>());
      expect(entitlement['membership'], 'yearly');
    },
  );

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

  test('coach client preserves server quota errors', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(
          jsonEncode({
            'session': {'token': 'quota-session'},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'error': 'quota_exhausted',
          'detail': {'kind': 'ai'},
        }),
        409,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: client,
    );
    await api.signIn(identifier: '123', password: '123');

    await expectLater(
      api.answer(prompt: 'test', includeTrainingSummary: false),
      throwsA(
        isA<CoachApiException>().having(
          (error) => error.code,
          'code',
          'quota_exhausted',
        ),
      ),
    );
  });

  test('coach client reuses the server conversation id', () async {
    Map<String, dynamic>? requestBody;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(
          jsonEncode({
            'session': {'token': 'memory'},
          }),
          200,
        );
      }
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'conversationId': 'conv_memory_1',
            'answer': '我记得上一轮对话。',
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: client,
    );
    await api.signIn(identifier: '123', password: '123');
    final answer = await api.answer(
      prompt: '继续上一个问题',
      includeTrainingSummary: false,
      conversationId: 'conv_memory_1',
    );
    expect(requestBody?['conversationId'], 'conv_memory_1');
    expect(answer.conversationId, 'conv_memory_1');
  });

  test(
    'agent tool handshake keeps request id and sends local read result',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var answerCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'agent-session'},
            }),
            200,
          );
        }
        expect(request.url.path, '/v1/coach/answer');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        answerCalls += 1;
        if (answerCalls == 1) {
          return http.Response(
            jsonEncode({
              'answer': '',
              'toolCalls': [
                {
                  'id': 'call_plans',
                  'name': 'read_training_plans',
                  'arguments': {'limit': 2},
                },
              ],
            }),
            200,
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({'answer': '我读取到了你的计划。'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );
      await api.signIn(identifier: '123', password: '123');
      const requestId = 'agent-mobile-1';
      final availableTools = [
        {
          'type': 'function',
          'function': {'name': 'read_training_plans'},
        },
      ];
      final first = await api.answer(
        prompt: '读取我的训练计划',
        requestId: requestId,
        includeTrainingSummary: true,
        availableTools: availableTools,
      );
      expect(first.toolCalls.single.name, 'read_training_plans');
      expect(bodies.first['requestId'], requestId);
      expect(bodies.first['useTrainingData'], true);
      expect(bodies.first['availableTools'], availableTools);

      final second = await api.answer(
        prompt: '读取我的训练计划',
        requestId: requestId,
        includeTrainingSummary: true,
        toolResults: const [
          {
            'id': 'call_plans',
            'name': 'read_training_plans',
            'arguments': {'limit': 2},
            'result': {'tool': 'read_training_plans', 'plans': [], 'count': 0},
          },
        ],
      );
      expect(second.body, '我读取到了你的计划。');
      expect(bodies[1]['requestId'], requestId);
      expect(bodies[1].containsKey('availableTools'), false);
      expect(
        (bodies[1]['toolResults'] as List<dynamic>).single['name'],
        'read_training_plans',
      );
    },
  );

  test(
    'agent registry is not sent when local-data consent is disabled',
    () async {
      Map<String, dynamic>? body;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'no-consent-session'},
            }),
            200,
          );
        }
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'answer': '普通回答'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: client,
      );
      await api.signIn(identifier: '123', password: '123');
      await api.answer(
        prompt: '普通问题',
        includeTrainingSummary: false,
        availableTools: const [
          {
            'type': 'function',
            'function': {'name': 'read_training_plans'},
          },
        ],
      );
      expect(body?['useTrainingData'], false);
      expect(body?.containsKey('availableTools'), false);
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

  test('coach client sends the exercise catalog and parses a plan', () async {
    Map<String, dynamic>? coachBody;
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(
          jsonEncode({
            'session': {'token': 'plan-session'},
          }),
          200,
        );
      }
      coachBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'answer': '这是你的训练安排。',
            'citations': [
              {'title': '渐进超负荷', 'source': 'https://example.test/source'},
            ],
            'plan': {
              'title': '四周增肌计划',
              'weeks': 4,
              'sessions': [
                {
                  'dayOffset': 0,
                  'name': '上肢训练',
                  'exerciseIds': ['bench-press'],
                },
              ],
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: client,
    );

    await api.signIn(identifier: '123', password: '123');
    final answer = await api.answer(
      prompt: '帮我生成一个月的训练计划',
      includeTrainingSummary: false,
      exerciseCatalog: const [
        {
          'id': 'bench-press',
          'name': '杠铃卧推',
          'equipment': '杠铃',
          'muscle': '胸部',
        },
      ],
    );

    expect(coachBody?['exerciseCatalog'], hasLength(1));
    expect(answer.citations.single, contains('https://example.test/source'));
    expect(answer.plan?.title, '四周增肌计划');
    expect(answer.plan?.weeks, 4);
    expect(answer.plan?.sessions.single.exerciseIds, ['bench-press']);
  });

  test('coach client parses prescribed sets, weights and rest', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(
          jsonEncode({
            'session': {'token': 'structured-plan-session'},
          }),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'answer': '胸部训练已生成。',
            'plan': {
              'title': '今日练胸',
              'weeks': 1,
              'sessions': [
                {
                  'dayOffset': 0,
                  'name': '胸部训练',
                  'exercises': [
                    {
                      'exerciseId': 'bench_press',
                      'note': '肩胛稳定，前臂垂直，控制杠铃触胸。',
                      'sets': [
                        {
                          'type': 'warmup',
                          'weight': 20,
                          'reps': 12,
                          'restSeconds': 60,
                        },
                        {
                          'type': 'work',
                          'weight': 50,
                          'reps': 8,
                          'restSeconds': 120,
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = HttpCoachApi(
      baseUrl: 'https://api.example.test',
      client: client,
    );

    await api.signIn(identifier: '123', password: '123');
    final answer = await api.answer(
      prompt: '生成今日练胸计划',
      includeTrainingSummary: false,
    );

    final session = answer.plan!.sessions.single;
    expect(session.effectiveExerciseIds, ['bench_press']);
    expect(session.totalSets, 2);
    expect(session.plannedVolume, 640);
    expect(session.exercises.single.note, '肩胛稳定，前臂垂直，控制杠铃触胸。');
    expect(session.exercises.single.sets.last.weight, 50);
    expect(session.exercises.single.sets.last.restSeconds, 120);
  });
}
