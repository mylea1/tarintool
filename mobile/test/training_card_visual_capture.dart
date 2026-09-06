import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_details_card.dart';
import 'package:kilo_strength/premium_feature_surface.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('capture detailed cards in both themes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = shadows);
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      for (final family in ['Roboto', 'Ahem', 'Arial', 'sans-serif']) {
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController();
    addTearDown(c.dispose);
    final record = WorkoutRecord(
      id: 'preview',
      name: '上肢力量',
      date: DateTime(2026, 9, 6),
      startTime: '12:27',
      durationSeconds: 2880,
      volume: 1960,
      effectiveSets: 6,
      exerciseIds: ['bench_press', 'lat_pulldown'],
      exercises: [
        for (final id in ['bench_press', 'lat_pulldown'])
          WorkoutExercise(
            id: id,
            exerciseId: id,
            sets: [
              WorkoutSet(id: '1', weight: 50, reps: 12, completed: true),
              WorkoutSet(id: '2', weight: 50, reps: 10, completed: true),
              WorkoutSet(id: '3', weight: 45, reps: 10, completed: true),
            ],
          ),
      ],
    );
    for (final dark in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xffc14e09),
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
            ),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '训练已完成',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TrainingDetailsCard.fromRecord(
                        controller: c,
                        record: record,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('分享到动态'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final asset in [
          brandLogoAsset,
          brandLogoLightAsset,
          exerciseAsset('bench_press'),
          exerciseAsset('lat_pulldown'),
        ]) {
          await precacheImage(AssetImage(asset), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../artifacts/training-card-${dark ? 'dark' : 'light'}-v41.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    for (final dark in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'PRO 专属功能',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (final name in ['深度训练洞察', 'AI 今日饮食建议'])
                        PremiumFeatureSurface(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lock_outline),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Text('PRO'),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: () {},
                                  child: const Text('解锁建议'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../artifacts/premium-${dark ? 'dark' : 'light'}-restored.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    debugDisableShadows = shadows;
  });
}
