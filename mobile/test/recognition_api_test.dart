import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PersistentCoachApi implements CoachApi {
  @override
  Future<CoachAnswer> answer({
    required String prompt,
    required bool includeTrainingSummary,
    String locale = 'zh-CN',
    String? trainingSummary,
    List<Map<String, String>> exerciseCatalog = const [],
    List<Map<String, String>> skills = const [],
  }) async => CoachAnswer(
    body: '已记录：$prompt',
    citations: const ['测试论文｜https://example.test/paper'],
    plan: const AiPlanDraft(
      title: '测试计划',
      weeks: 1,
      sessions: [
        AiPlanSession(
          dayOffset: 0,
          name: '胸部训练',
          exerciseIds: ['bench_press'],
          exercises: [
            AiPlanExerciseDraft(
              exerciseId: 'bench_press',
              sets: [
                AiPlanSetDraft(
                  type: 'work',
                  weight: 40,
                  reps: 8,
                  restSeconds: 120,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HTTP recognition uploads through configured origin and polls result', () async {
    var statusRequests = 0;
    late final List<int> uploadedBytes;
    final progress = <RecognitionStage>[];
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/phone/login') {
        return http.Response(
          jsonEncode({
            'session': {'token': 'session-token'},
          }),
          200,
        );
      }
      if (request.url.path == '/v1/analysis/jobs' && request.method == 'POST') {
        expect(request.headers['Authorization'], 'Bearer session-token');
        expect(jsonDecode(request.body)['includeOverlay'], false);
        return http.Response(
          jsonEncode({
            'id': 'job-1',
            'upload': {
              'url':
                  'https://blocked.example/v1/analysis/jobs/job-1/upload?token=upload-token',
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
              'summary': '动作骨骼提取完成',
              'metrics': {
                'durationSeconds': 12.4,
                'detectionRate': 0.91,
                'completeMotionCycles': 1,
              },
              'events': [
                {
                  'id': 'event-001',
                  'code': 'SQUAT_DEPTH_LIMITED',
                  'label': '下蹲深度可能不足',
                  'startMs': 11800,
                  'peakMs': 12400,
                  'endMs': 13000,
                  'displayTime': '00:12.4',
                  'explanation': '最低位置的膝角高于当前参考线。',
                  'confidence': 0.86,
                  'evidenceImageUrl':
                      'https://blocked.example/v1/analysis/jobs/job-1/media/evidence/event-001',
                  'measurements': {
                    'kneeAngleDeg': 126,
                    'referenceLimitDeg': 118,
                  },
                },
              ],
              'aiReview': {
                'headline': '整体轨迹稳定',
                'strengths': ['动作节奏一致'],
                'risks': ['末端控制可加强'],
                'nextSet': '保持重量，减慢离心阶段',
                'basis': '骨骼捕获率与重复次数',
              },
            },
            'media': {
              'overlay':
                  'https://blocked.example/v1/analysis/jobs/job-1/media/overlay',
              'preview':
                  'https://blocked.example/v1/analysis/jobs/job-1/media/preview',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });
    final temp = await Directory.systemTemp.createTemp(
      'kilo-recognition-test-',
    );
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
      includeOverlay: false,
      onProgress: (update) => progress.add(update.stage),
    );

    expect(uploadedBytes, [1, 2, 3, 4]);
    expect(statusRequests, 2);
    expect(result.status, RecognitionStatus.complete);
    expect(result.confidence, 0.82);
    expect(result.repetitions, 0);
    expect(result.events, hasLength(1));
    expect(result.events.single.displayTime, '00:12.4');
    expect(result.events.single.timeRangeLabel, '00:11.8-00:13.0');
    expect(result.events.single.evidenceImageUrl, contains('test-api.example'));
    expect(result.metrics['detectionRate'], 0.91);
    expect(result.aiReview?.headline, '整体轨迹稳定');
    expect(result.aiReview?.risks, ['末端控制可加强']);
    expect(result.overlayUrl, contains('test-api.example'));
    expect(result.mediaHeaders['Authorization'], 'Bearer session-token');
    expect(
      progress,
      containsAllInOrder([
        RecognitionStage.preparing,
        RecognitionStage.uploading,
        RecognitionStage.analyzing,
      ]),
    );
  });

  test(
    'recognition preserves server quota error instead of generic HTTP error',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/v1/auth/phone/login') {
          return http.Response(
            jsonEncode({
              'session': {'token': 'token'},
            }),
            200,
          );
        }
        if (request.url.path == '/v1/analysis/jobs') {
          return http.Response(
            jsonEncode({
              'error': 'quota_exhausted',
              'detail': {'kind': 'recognition'},
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });
      final temp = await Directory.systemTemp.createTemp('kilo-quota-test-');
      addTearDown(() => temp.delete(recursive: true));
      final video = File('${temp.path}/sample.mp4');
      await video.writeAsBytes([1, 2, 3]);
      final api = HttpRecognitionApi(
        baseUrl: 'https://test-api.example',
        client: client,
      );
      await api.signIn(identifier: '1234', password: '1234');

      await expectLater(
        api.analyze(
          exerciseId: 'barbell_squat',
          camera: 'side',
          scenario: 'normal',
          mediaPath: video.path,
        ),
        throwsA(
          isA<RecognitionApiException>().having(
            (error) => error.code,
            'code',
            'quota_exhausted',
          ),
        ),
      );
    },
  );

  test(
    'AI conversations and plan details restore locally per account',
    () async {
      SharedPreferences.setMockInitialValues({});

      AppController buildController() {
        final account = AccountService(allowTestAdmin: true);
        account.loginWithPhone('123', password: '123');
        return AppController(
          accountService: account,
          coachApi: _PersistentCoachApi(),
        );
      }

      final first = buildController();
      await first.hydrateAiConversations(force: true);
      await first.sendChat('帮我检查今天的卧推');
      await first.flushAiConversationPersistence();
      expect(first.conversations, hasLength(1));
      final stored = (await SharedPreferences.getInstance()).getString(
        'xingyu.ai-conversations.v1.phone:123',
      );
      expect(stored, contains('帮我检查今天的卧推'));
      first.dispose();

      final second = buildController();
      await second.hydrateAiConversations(force: true);
      expect(second.conversations, hasLength(1));
      expect(second.chat.map((message) => message.body), [
        '帮我检查今天的卧推',
        '已记录：帮我检查今天的卧推',
      ]);
      expect(second.chat.last.citations, hasLength(1));
      expect(second.chat.last.plan?.title, '测试计划');
      expect(
        second
            .chat
            .last
            .plan
            ?.sessions
            .single
            .exercises
            .single
            .sets
            .single
            .weight,
        40,
      );
      second.dispose();
    },
  );
}
