import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Watch app target uses the single-target watchOS product type', () {
    final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');
    expect(projectFile.existsSync(), isTrue);

    final project = projectFile.readAsStringSync();
    final target = RegExp(
      r'WCH500000000000000000001 /\* KiloWatch \*/ = \{([\s\S]*?)\n\t\t\};',
    ).firstMatch(project);

    expect(target, isNotNull);
    expect(
      target!.group(1),
      contains('productType = "com.apple.product-type.application";'),
    );
    expect(
      target.group(1),
      isNot(contains('com.apple.product-type.application.watchapp2')),
    );
  });
}
