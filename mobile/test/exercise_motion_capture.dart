import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('capture live drag handles and filters', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = AppController();
    addTearDown(c.dispose);
    c.openNewOrResumeWorkout();
    c.addExercise('bench_press');
    c.addExercise('lat_pulldown');
    for (final e in c.workout) {
      e.collapsed = true;
    }
    final boundary = GlobalKey();
    for (final dark in [false, true]) {
      await c.setDarkMode(dark);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: KiloApp(initialController: c),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('live-drag-${c.workout.first.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../artifacts/motion-live-${dark ? 'dark' : 'light'}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
