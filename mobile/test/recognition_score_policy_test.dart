import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';
import 'package:kilo_strength/recognition_score_policy.dart';

RecognitionResult result({
  String assessment = 'assessable',
  String reason = 'assessable',
  Map<String, dynamic> scores = const {},
}) => RecognitionResult(
  status: RecognitionStatus.complete,
  confidence: .55,
  assessment: assessment,
  evidenceReason: reason,
  summary: '已识别到主要动作阶段，本次评价可见阶段。',
  metrics: {'scores': scores},
);

void main() {
  test('missing numeric scores do not erase a valid assessment', () {
    final policy = RecognitionScorePolicy(result());
    expect(policy.title, '动作反馈');
    expect(policy.guidance, contains('可见阶段'));
    expect(policy.available, isEmpty);
    expect(policy.canRecordCompleteScore, isFalse);
    expect(policy.historyReason, 'numeric_scores_unavailable_or_partial');
  });
  test('missing symmetry does not hide visible range or a legitimate zero', () {
    final policy = RecognitionScorePolicy(
      result(scores: {'rom': 80, 'tempo': 0}),
    );
    expect(policy.available, {'动作幅度': 80, '节奏控制': 0});
    expect(policy.score('overall'), isNull);
    expect(policy.canRecordCompleteScore, isFalse);
  });
  test(
    'complete real scores including zero may enter history below global .6',
    () {
      final policy = RecognitionScorePolicy(
        result(
          scores: {
            'overall': 0,
            'rom': 0,
            'stability': 0,
            'symmetry': 0,
            'tempo': 0,
            'trajectory': 0,
          },
        ),
      );
      expect(policy.canRecordCompleteScore, isTrue);
    },
  );
  test('invalid values are not clamped into plausible scores', () {
    final policy = RecognitionScorePolicy(
      result(
        scores: {
          'rom': double.nan,
          'tempo': '80',
          'trajectory': 101,
          'stability': -1,
          'symmetry': double.infinity,
        },
      ),
    );
    expect(policy.available, isEmpty);
  });
  test('mismatched exercise never displays numbers', () {
    final policy = RecognitionScorePolicy(
      result(
        assessment: 'insufficient_evidence',
        reason: 'selected_exercise_mismatch',
        scores: {'overall': 90, 'rom': 90},
      ),
    );
    expect(policy.available, isEmpty);
    expect(policy.score('overall'), isNull);
    expect(policy.guidance, contains('动作类型'));
  });
  test('occlusion guidance requests target joints rather than whole body', () {
    final policy = RecognitionScorePolicy(
      result(
        assessment: 'insufficient_evidence',
        reason: 'insufficient_landmarks',
      ),
    );
    expect(policy.guidance, contains('不必强求全身入镜'));
  });
}
