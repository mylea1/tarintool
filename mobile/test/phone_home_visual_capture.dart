// Explicit native Flutter render check; never generates or edits HTML.
// flutter test --no-pub test/phone_home_visual_capture.dart --update-goldens
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = Key('phone-home-capture');

String _day(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Future<void> _snapshot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(_capture),
    matchesGoldenFile('../../design-previews/phone-home-qa/flutter-$name.png'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font = Platform.environment['KILO_QA_FONT'];
    if (font != null) {
      final bytes = ByteData.sublistView(await File(font).readAsBytes());
      for (final family in [
        'Roboto',
        'Ahem',
        '.SF UI Text',
        '.SF UI Display',
        '.SF Pro Text',
        '.SF Pro Display',
        '.AppleSystemUIFont',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 375.0]) {
    testWidgets('native home date record and return at $width', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final controller = AppController()..page = PageId.today;
      addTearDown(controller.dispose);
      controller.history.add(
        WorkoutRecord(
          id: 'qa-today',
          name: '上肢训练',
          date: now,
          startTime: '18:00',
          durationSeconds: 2400,
          volume: 2400,
          effectiveSets: 3,
          exerciseIds: const ['bench_press'],
          exercises: [
            WorkoutExercise(
              id: 'qa-bench',
              exerciseId: 'bench_press',
              sets: [
                for (var i = 0; i < 3; i++)
                  WorkoutSet(
                    id: 'qa-$i',
                    weight: 80,
                    reps: 10,
                    completed: true,
                  ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: _capture,
          child: KiloApp(initialController: controller),
        ),
      );
      await tester.pumpAndSettle();
      final date = find.byKey(Key('home-week-day-${_day(now)}'));
      await tester.scrollUntilVisible(
        date,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-muscle-card')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('home-day-training-section')),
      );
      await _snapshot(tester, 'date-record-${width.toInt()}');
      await tester.tap(find.byKey(const Key('home-day-training-back')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home-muscle-card')));
      await _snapshot(tester, 'muscles-${width.toInt()}');

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await _snapshot(tester, 'login-${width.toInt()}');
      await tester.tap(find.byKey(const Key('login-code-mode')));
      await tester.pumpAndSettle();
      await _snapshot(tester, 'sms-login-${width.toInt()}');
      final register = find.byKey(const Key('login-register-button'));
      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 800),
      );
      await tester.pumpAndSettle();
      await _snapshot(tester, 'register-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
