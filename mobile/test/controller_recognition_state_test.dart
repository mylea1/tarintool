import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all configured recognition exercises remain selectable offline', () {
    final controller = AppController();
    addTearDown(controller.dispose);

    expect(fallbackRecognitionCapabilities, hasLength(66));
    expect(controller.recognitionExercises, hasLength(66));
    expect(
      controller.recognitionExercises.map((exercise) => exercise.id),
      containsAll(<String>[
        'leg_press',
        'chest_supported_pulldown',
        'prone_y_raise',
      ]),
    );
    expect(
      controller.recognitionExercises
          .firstWhere((exercise) => exercise.id == 'leg_press')
          .name,
      '45°腿举',
    );
  });

  test('changing recognition inputs clears a stale completed report', () {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.selectedMediaPath = 'lat-pulldown.mp4';
    controller.recognitionStatus = RecognitionStatus.complete;
    controller.recognitionResult = const RecognitionResult(
      status: RecognitionStatus.complete,
      confidence: .9,
      summary: '上一份深蹲报告',
    );

    controller.selectRecognitionExercise('lat_pulldown');

    expect(controller.recognitionExerciseId, 'lat_pulldown');
    expect(controller.recognitionCamera, 'rear');
    expect(controller.recognitionStatus, RecognitionStatus.ready);
    expect(controller.recognitionResult, isNull);

    controller.recognitionStatus = RecognitionStatus.complete;
    controller.recognitionResult = const RecognitionResult(
      status: RecognitionStatus.complete,
      confidence: .8,
      summary: '上一机位的报告',
    );
    controller.selectRecognitionCamera('side');

    expect(controller.recognitionCamera, 'side');
    expect(controller.recognitionStatus, RecognitionStatus.ready);
    expect(controller.recognitionResult, isNull);

    controller.recognitionStatus = RecognitionStatus.complete;
    controller.recognitionResult = const RecognitionResult(
      status: RecognitionStatus.complete,
      confidence: .8,
      summary: '未生成完整骨骼视频的报告',
    );
    controller.setRecognitionIncludeOverlay(true);

    expect(controller.recognitionIncludeOverlay, isTrue);
    expect(controller.recognitionStatus, RecognitionStatus.ready);
    expect(controller.recognitionResult, isNull);
  });
}
