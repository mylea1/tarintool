import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/workout_share_card.dart';

const _capture = Key('share-card-capture');

Widget _testCard({
  String style = 'coral',
  String name = '自由训练',
  String? localPhotoPath,
  ImageProvider<Object>? photoImageProvider,
  double width = 1200,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: RepaintBoundary(
        key: _capture,
        child: SizedBox(
          width: width,
          child: WorkoutShareCard(
            workoutName: name,
            date: DateTime(2026, 9, 3),
            durationSeconds: 82 * 60,
            volume: 8400,
            effectiveSets: 14,
            cardStyle: style,
            localPhotoPath: localPhotoPath,
            photoImageProvider: photoImageProvider,
          ),
        ),
      ),
    ),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('renders the fixed landscape information hierarchy', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 760));
    await tester.pumpWidget(_testCard());
    await tester.pumpAndSettle();

    expect(find.text('KILOSTRENGTH'), findsOneWidget);
    expect(find.text('TRAINING / COMPLETE'), findsOneWidget);
    expect(find.text('自由训练'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('8.4T'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('2026.09.03'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all six accents survive long content at phone preview width', (
    tester,
  ) async {
    _viewport(tester, const Size(375, 812));
    for (final style in workoutCardStyles) {
      await tester.pumpWidget(
        _testCard(
          style: style,
          name: '超长训练名称压力测试 Upper Body Strength Session',
          width: 343,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutShareCard), findsOneWidget);
      expect(tester.takeException(), isNull, reason: style);
    }
  });

  testWidgets(
    'renders brand mode golden',
    (tester) async {
      _viewport(tester, const Size(1280, 760));
      await tester.pumpWidget(_testCard());
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(_capture),
        matchesGoldenFile('goldens/workout-share-card-brand.png'),
      );
    },
    // Flutter's macOS and Linux rasterizers differ by more than a safe visual
    // tolerance even with Ahem. Run the exact-pixel check explicitly on the
    // platform where its baseline is generated; cross-platform CI still runs
    // the hierarchy, stress-layout, and photo-composition tests above/below.
    skip: Platform.environment['RUN_GOLDEN_TESTS'] != '1',
  );

  testWidgets('renders photo mode with the same curved composition', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 760));
    await tester.pumpWidget(
      _testCard(
        style: 'forest',
        photoImageProvider: const AssetImage(
          'assets/exercises/bench_press_0.png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('workout-share-photo')), findsOneWidget);
  });

  testWidgets('result card adds summaries and actions without social content', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 1120));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutResultCard(
            workoutName: '自由训练',
            date: DateTime(2026, 9, 3),
            durationSeconds: 82 * 60,
            volume: 8400,
            effectiveSets: 14,
            completionPercent: 100,
            exerciseNames: const ['高位下拉', '单臂下拉', '坐姿划船', '反向飞鸟', '弯举'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('82 分钟'), findsOneWidget);
    expect(find.text('8400 kg'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('高位下拉'), findsOneWidget);
    expect(find.text('还有 2 个动作 ›'), findsOneWidget);
    expect(find.byKey(const Key('social-footer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('social mode accepts one lightweight interaction footer', (
    tester,
  ) async {
    _viewport(tester, const Size(1280, 1180));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutResultCard(
            workoutName: '自由训练',
            date: DateTime(2026, 9, 3),
            durationSeconds: 82 * 60,
            volume: 8400,
            effectiveSets: 14,
            completionPercent: 100,
            exerciseNames: const ['高位下拉'],
            socialFooter: const Row(
              key: Key('social-footer'),
              children: [Icon(Icons.favorite_border), Text('28')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('social-footer')), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
