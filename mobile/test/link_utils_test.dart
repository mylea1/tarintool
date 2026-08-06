import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/link_utils.dart';

void main() {
  group('normalizeTrainingUri', () {
    test('adds https to a host-only training link', () {
      expect(
        normalizeTrainingUri('  example.com/video?id=12  '),
        Uri.parse('https://example.com/video?id=12'),
      );
      expect(
        normalizeTrainingUri('localhost:8790/training'),
        Uri.parse('https://localhost:8790/training'),
      );
    });

    test('preserves http and https links', () {
      expect(
        normalizeTrainingUri('http://example.com/a'),
        Uri.parse('http://example.com/a'),
      );
      expect(
        normalizeTrainingUri('https://example.com/a'),
        Uri.parse('https://example.com/a'),
      );
    });

    test('rejects unsupported schemes and malformed values', () {
      expect(normalizeTrainingUri('ftp://example.com/a'), isNull);
      expect(normalizeTrainingUri('javascript:alert(1)'), isNull);
      expect(normalizeTrainingUri('https://'), isNull);
      expect(normalizeTrainingUri(''), isNull);
    });
  });

  test('launchTrainingUri uses an injectable opener', () async {
    final uri = Uri.parse('https://example.com/training');
    Uri? opened;
    final result = await launchTrainingUri(
      uri,
      opener: (target) async {
        opened = target;
        return true;
      },
    );

    expect(result, isTrue);
    expect(opened, uri);
  });
}
