import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';

void main() {
  test('exports the current selectable exercise catalog', () {
    final rows = <Map<String, Object?>>[];
    for (final exercise in selectableCatalog) {
      final stableIndex = catalog.indexWhere((item) => item.id == exercise.id);
      rows.add({
        'number': stableIndex + 1,
        'id': exercise.id,
        'name': conciseExerciseName(exercise, english: false),
        'asset': exerciseAsset(exercise.id),
      });
    }
    final output = Platform.environment['KILO_CATALOG_OUTPUT'];
    expect(output, isNotNull);
    File(
      output!,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    stdout.writeln('Exported ${rows.length} exercises.');
  });
}
