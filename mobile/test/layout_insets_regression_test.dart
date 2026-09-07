import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';

void main() {
  testWidgets('iPhone safe area is consumed once by page and nested grids', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.reset);
    final c = AppController();
    addTearDown(c.dispose);
    final boundary = GlobalKey();
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
    c.history.add(
      WorkoutRecord(
        id: 'compact-check',
        name: '下肢力量',
        date: DateTime.now(),
        startTime: '18:30',
        durationSeconds: 1800,
        volume: 3200,
        effectiveSets: 9,
        exerciseIds: const ['squat', 'bench_press'],
        exercises: [],
      ),
    );
    for (final page in [
      PageId.ai,
      PageId.exercises,
      PageId.profile,
      PageId.records,
    ]) {
      c.selectPage(page);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: KiloApp(initialController: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (page == PageId.ai) {
        final top = tester.getTopLeft(find.byKey(const Key('ai-drawer'))).dy;
        expect(
          top,
          lessThan(150),
          reason: 'AI header must sit directly below the app bar',
        );
      }
      if (page == PageId.exercises) {
        final grid = tester.widget<GridView>(
          find.byKey(const Key('exercise-library-grid')),
        );
        expect(grid.padding, EdgeInsets.zero);
      }
      if (page == PageId.records) {
        final tile = find.byKey(const Key('record-tile-compact-check'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final card = find.ancestor(of: tile, matching: find.byType(Card)).first;
        expect(tester.getSize(card).height, lessThan(250));
      }
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final f = File('../artifacts/layout-restore-${page.name}.png');
        await f.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
