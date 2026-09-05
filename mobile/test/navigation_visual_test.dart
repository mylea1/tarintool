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

void main() {
  testWidgets('navigation, home and profile fit small screens and large text', (
    tester,
  ) async {
    final capture = Platform.environment['CAPTURE_NAV_UI'] == '1';
    if (capture) {
      final font = File('C:/Windows/Fonts/msyh.ttc');
      if (font.existsSync()) {
        final data = ByteData.sublistView(font.readAsBytesSync());
        for (final family in ['Roboto', 'Ahem', 'Arial', 'sans-serif']) {
          await (FontLoader(family)..addFont(Future.value(data))).load();
        }
      }
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final account = AccountService();
    account.loginAuthenticatedRemote(
      identifier: 'apple:000349.abcdefghijklmnopqrstuvwxyz',
      displayName: '形域训练者',
      isAdmin: false,
      publicId: '5831047296',
    );
    final c = AppController(accountService: account);
    addTearDown(c.dispose);
    final boundary = GlobalKey();
    for (final width in [320.0, 375.0, 414.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final page in [
          PageId.today,
          PageId.profile,
          PageId.records,
          PageId.train,
        ]) {
          c.selectPage(page);
          if (page == PageId.train) c.selectTrainView(TrainView.plans);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: KiloApp(initialController: c),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$page $width $scale');
          if (capture && width == 375 && scale == 1) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../design-previews/navigation-refresh/actual-${page.name}.png',
              );
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      }
    }
  });
}
