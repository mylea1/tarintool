import 'recognition_api.dart';

/// Missing measurements are not zero scores, and pose confidence is not a
/// technique score. Only display numeric scores actually supplied by the API.
class RecognitionScorePolicy {
  RecognitionScorePolicy(this.result);
  final RecognitionResult result;

  static const dimensions = {
    'rom': '动作幅度',
    'stability': '稳定性',
    'symmetry': '左右对称',
    'tempo': '节奏控制',
    'trajectory': '动作轨迹',
  };

  bool get assessable => result.assessment == 'assessable';

  int? score(String key) {
    if (!assessable) return null;
    final raw = result.metrics['scores'];
    final value = raw is Map ? raw[key] : null;
    if (value is! num || !value.isFinite || value < 0 || value > 100) {
      return null;
    }
    return value.round();
  }

  Map<String, int> get available => {
    for (final entry in dimensions.entries)
      if (score(entry.key) case final int value) entry.value: value,
  };

  // The legacy history model has no nullable dimensions. Do not insert partial
  // results as zero-filled points in its five-dimensional progress chart.
  bool get canRecordCompleteScore =>
      score('overall') != null && available.length == dimensions.length;

  String get title => assessable ? '动作反馈' : '需要补充画面';

  String get guidance {
    if (assessable) {
      return result.summary.isNotEmpty
          ? result.summary
          : '已完成可见动作分析，请结合时间标记和骨骼图片查看调整建议。';
    }
    switch (result.evidenceReason) {
      case 'selected_exercise_mismatch':
        return '视频中的动作与所选动作不一致，请先确认动作类型。';
      case 'insufficient_landmarks':
      case 'insufficient_pose_quality':
        return '关键关节被遮挡或跟踪不稳定。请让发力部位及相邻关节入镜，避开器械遮挡；不必强求全身入镜。';
      case 'insufficient_motion':
        return '可见的目标关节变化还不足以判断。请保留发力和还原过程，避免只截取停顿画面。';
      case 'no_complete_motion_cycle':
        return '还没有可靠连起发力和还原过程。请保留更连续的动作片段，并让发力关节持续可见。';
      default:
        return result.summary.isNotEmpty
            ? result.summary
            : '当前关键动作画面不足。请保持镜头稳定，让发力部位及相邻关节清晰可见。';
    }
  }

  String get historyReason => assessable
      ? 'numeric_scores_unavailable_or_partial'
      : result.evidenceReason;
}
