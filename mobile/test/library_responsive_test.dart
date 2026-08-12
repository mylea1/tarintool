import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';

void main() {
  testWidgets('library controls wrap at 320dp with 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: KiloApp(initialController: controller),
      ),
    );
    controller.selectPage(PageId.exercises);
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('exercise-search'));
    final filter = find.byKey(const Key('exercise-equipment-filter'));
    final add = find.byKey(const Key('exercise-library-add-inline'));
    expect(search, findsOneWidget);
    expect(filter, findsOneWidget);
    expect(add, findsOneWidget);
    expect(tester.getRect(search).bottom, lessThan(tester.getRect(filter).top));
    expect(tester.getRect(filter).right, lessThanOrEqualTo(320));
    expect(tester.getRect(add).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise cards keep a compact height at normal text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(KiloApp(initialController: controller));
    controller.selectPage(PageId.exercises);
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(
      find.byKey(const Key('exercise-library-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.childAspectRatio, greaterThanOrEqualTo(.8));
    expect(tester.takeException(), isNull);
  });
}
