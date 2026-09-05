import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectFile = File('ios/Runner.xcodeproj/project.pbxproj');
  final appDelegateFile = File('ios/Runner/AppDelegate.swift');

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

  test('Runner release target keeps Apple Watch integration disabled', () {
    final project = projectFile.readAsStringSync();
    final runnerTarget = RegExp(
      r'97C146ED1CF9000F007C117D /\* Runner \*/ = \{([\s\S]*?)\n\t\t\};',
    ).firstMatch(project);
    final runnerSources = RegExp(
      r'97C146EA1CF9000F007C117D /\* Sources \*/ = \{([\s\S]*?)\n\t\t\};',
    ).firstMatch(project);

    expect(runnerTarget, isNotNull);
    expect(runnerSources, isNotNull);
    expect(runnerTarget!.group(1), isNot(contains('Embed Watch Content')));
    expect(runnerTarget.group(1), isNot(contains('WCH800000000000000000001')));
    expect(
      runnerSources!.group(1),
      isNot(contains('KiloWatchConnectivityManager.swift in Sources')),
    );
    expect(
      appDelegateFile.readAsStringSync(),
      isNot(contains('KiloWatchConnectivityManager')),
    );
  });
}
