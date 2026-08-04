import 'dart:async';

import 'models.dart';

/// Stable client boundary for the BetterCoach/mock recognition service.
/// The Flutter UI only depends on this contract; a production adapter can
/// replace [MockRecognitionApi] without moving model logic into a page.
abstract interface class RecognitionApi {
  Future<RecognitionResult> analyze({required String exerciseId, required String camera, required String scenario});
}

class RecognitionResult {
  const RecognitionResult({required this.status, required this.confidence, required this.repetitions, required this.summary, this.error});
  final RecognitionStatus status;
  final double confidence;
  final int repetitions;
  final String summary;
  final String? error;
}

class MockRecognitionApi implements RecognitionApi {
  @override
  Future<RecognitionResult> analyze({required String exerciseId, required String camera, required String scenario}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (scenario == 'offline') return const RecognitionResult(status: RecognitionStatus.offline, confidence: 0, repetitions: 0, summary: '当前处于离线状态，视频已保存在本地，联网后可继续分析。', error: 'offline');
    if (scenario == 'error') return const RecognitionResult(status: RecognitionStatus.error, confidence: 0, repetitions: 0, summary: '识别服务暂时不可用，请稍后重试。', error: 'service_unavailable');
    if (scenario == 'low-confidence') return const RecognitionResult(status: RecognitionStatus.lowConfidence, confidence: .48, repetitions: 6, summary: '机位与光线导致部分关键点遮挡，结果仅供参考。');
    return const RecognitionResult(status: RecognitionStatus.complete, confidence: .92, repetitions: 8, summary: '深度稳定，膝盖轨迹与脚尖方向保持一致。');
  }
}
