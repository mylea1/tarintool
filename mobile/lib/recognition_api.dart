import 'models.dart';

/// Stable client boundary for the BetterCoach recognition service.
/// The Flutter UI only depends on this contract; a production adapter can
/// replace [UnconfiguredRecognitionApi] without moving model logic into a page.
abstract interface class RecognitionApi {
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
  });
}

class RecognitionResult {
  const RecognitionResult({
    required this.status,
    required this.confidence,
    required this.repetitions,
    required this.summary,
    this.error,
  });
  final RecognitionStatus status;
  final double confidence;
  final int repetitions;
  final String summary;
  final String? error;
}

class UnconfiguredRecognitionApi implements RecognitionApi {
  @override
  Future<RecognitionResult> analyze({
    required String exerciseId,
    required String camera,
    required String scenario,
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
