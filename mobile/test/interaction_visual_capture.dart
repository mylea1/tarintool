import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('capture profile themes and contextual chat with keyboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final font = File('C:/Windows/Fonts/msyh.ttc');
    if (font.existsSync()) {
      final bytes = ByteData.sublistView(font.readAsBytesSync());
      for (final family in ['Roboto', 'Ahem', 'Arial', 'sans-serif']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final account = AccountService()
      ..loginAuthenticatedRemote(
        identifier: 'preview-user',
        displayName: '形域训练者',
        isAdmin: false,
        publicId: '5831047296',
      );
    final c = AppController(accountService: account);
    addTearDown(c.dispose);
    final key = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in [
          'assets/branding/membership-lines-light.png',
          'assets/branding/membership-lines-dark.png',
          brandLogoAsset,
          brandLogoLightAsset,
        ]) {
          await precacheImage(AssetImage(asset), key.currentContext!);
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
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
          '../artifacts/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    c.selectPage(PageId.profile);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: KiloApp(initialController: c),
      ),
    );
    await capture('profile-light-v40');
    await c.setDarkMode(true);
    await capture('profile-dark-v40');
    await c.setDarkMode(false);
    c.startWorkout(
      source: [c.createBlankWorkoutExercise('bench_press', 'preview')],
      autoStartTimer: false,
    );
    c.openLiveWorkout();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workout-coach-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('coach-orbit-${c.workout.first.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workout-coach-panel')), findsOneWidget);
    await capture('coach-panel-v40');
    tester.view.physicalSize = const Size(320, 740);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await capture('coach-panel-keyboard-v40');
  });
}
