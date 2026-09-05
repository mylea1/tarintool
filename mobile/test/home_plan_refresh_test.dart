import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_intelligence.dart';
import 'package:kilo_strength/workout_history_persistence.dart';
import 'training_intelligence_test.dart' as fixtures;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const engine = TrainingIntelligenceEngine();
  const shoulder = Exercise(
    id: 'press',
    name: '动作',
    englishName: 'Press',
    family: '肩',
    muscle: '肩',
    secondary: '',
    equipment: '哑铃',
    camera: '',
    cue: '',
  );
  final clock = DateTime(2026, 9, 2, 12);
  Routine plan(String id, String exercise, {bool official = false}) =>
      fixtures.routine(id: id, name: '计划 $id', exerciseId: exercise)
        ..folder = official ? '官方计划' : '个人';
  DailyTrainingRecommendation recommend({
    List<Routine> personal = const [],
    List<Routine> official = const [],
    TrainingProfile profile = const TrainingProfile(
      focusMuscles: ['胸', '背'],
      excludedMuscles: ['腿'],
    ),
    List<MuscleRecovery> recovery = const [],
  }) => engine.recommendToday(
    history: const [],
    exercises: const [
      fixtures.exercise,
      fixtures.backExercise,
      fixtures.legExercise,
      shoulder,
    ],
    routines: personal,
    officialRoutines: official,
    recovery: recovery,
    volume: const [],
    profile: profile,
    now: clock,
  );

  test('official plans win until personal plans cover preferred muscles', () {
    final personal = [plan('mine', 'bench_press')];
    final official = [plan('catalog', 'barbell_row', official: true)];
    expect(
      recommend(personal: personal, official: official).routineId,
      'catalog',
    );
    personal.add(plan('mine-back', 'barbell_row'));
    personal.add(plan('mine-shoulder', 'press'));
    expect(
      recommend(personal: personal, official: official).routineId,
      startsWith('mine'),
    );
  });
  test(
    'opaque titles cannot bypass excluded leg muscles or disliked exercises',
    () {
      final official = [
        plan('a', 'barbell_squat', official: true),
        plan('b', 'bench_press', official: true),
      ];
      expect(
        recommend(
          official: official,
          profile: const TrainingProfile(excludedMuscles: ['腿']),
        ).routineId,
        'b',
      );
      expect(
        recommend(
          official: official,
          profile: const TrainingProfile(
            excludedMuscles: ['腿'],
            dislikedExerciseIds: ['bench_press'],
          ),
        ).routineId,
        isNull,
      );
    },
  );
  test('recovery determines selection without relying on plan title', () {
    expect(
      recommend(
        official: [
          plan('a', 'bench_press', official: true),
          plan('b', 'barbell_row', official: true),
        ],
        recovery: const [
          MuscleRecovery('胸', 25, ''),
          MuscleRecovery('背', 90, ''),
        ],
      ).routineId,
      'b',
    );
  });
  test('missing catalog and incomplete library do not repeat old routine', () {
    expect(recommend(personal: [plan('old', 'bench_press')]).routineId, isNull);
  });
  test(
    'off days have no automatic workout and exclusion survives profile reload',
    () {
      final profile = TrainingProfile.fromJson(
        const TrainingProfile(
          preferredWeekdays: [1],
          excludedMuscles: ['腿'],
        ).toJson(),
      );
      expect(profile.excludedMuscles, ['腿']);
      expect(
        recommend(
          official: [plan('a', 'bench_press', official: true)],
          profile: profile,
        ).title,
        '今天是休息日',
      );
    },
  );
  test('cover survives library roundtrip while legacy plans still load', () {
    final routine = plan('cover', 'bench_press')
      ..coverImage = base64Encode([1, 2, 3]);
    final encoded = encodeTrainingLibrary(
      TrainingLibrarySnapshot(
        routines: [routine],
        routineFolders: const [],
        scheduledLabels: const {},
      ),
    );
    expect(
      decodeTrainingLibrary(
        jsonDecode(jsonEncode(encoded)),
      ).routines.single.coverImage,
      routine.coverImage,
    );
    (encoded['routines'] as List).first.remove('coverImage');
    expect(decodeTrainingLibrary(encoded).routines.single.coverImage, isNull);
  });
  for (final width in [320.0, 375.0, 414.0]) {
    testWidgets('records mode header stays fixed at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = AppController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RecordsPage(controller: c)),
        ),
      );
      await tester.pumpAndSettle();
      final tabs = find.byKey(const Key('records-statistics-tabs'));
      final rect = tester.getRect(tabs);
      for (final label in ['饮食', '统计', '训练']) {
        await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(tester.getRect(tabs), rect);
        expect(find.byKey(const Key('open-friends')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('capture actual home and training layout', (tester) async {
    tester.view.physicalSize = const Size(414, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController();
    addTearDown(c.dispose);
    c.routines.add(plan('preview', 'bench_press'));
    c.schedule(DateTime.now(), c.routines.first.name);
    final fontFile = File('C:/Windows/Fonts/msyh.ttc');
    if (fontFile.existsSync()) {
      final bytes = await tester.runAsync(() => fontFile.readAsBytes());
      for (final name in ['Ahem', 'Roboto']) {
        final loader = FontLoader(name)
          ..addFont(Future.value(ByteData.sublistView(bytes!)));
        await loader.load();
      }
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: KiloApp(initialController: c),
      ),
    );
    await tester.pumpAndSettle();
    for (final page in [PageId.today, PageId.train]) {
      c.selectPage(page);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(brandLogoAsset),
          boundary.currentContext!,
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../artifacts/home-plan-${page.name}.png');
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
