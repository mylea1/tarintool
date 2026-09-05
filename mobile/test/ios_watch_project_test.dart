import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');

  test('Watch app target uses the single-target watchOS product type', () {
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

  test('Runner connectivity source path is relative to the Runner group', () {
    final project = projectFile.readAsStringSync();

    expect(
      project,
      contains(
        'path = KiloWatchConnectivityManager.swift; sourceTree = "<group>";',
      ),
    );
    expect(
      project,
      isNot(contains('path = Runner/KiloWatchConnectivityManager.swift;')),
    );
  });
}
