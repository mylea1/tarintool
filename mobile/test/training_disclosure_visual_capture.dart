import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_details_card.dart';

void main() {
  testWidgets('capture disclosures in both themes', (tester) async {
    final font = File('C:/Windows/Fonts/msyh.ttc');
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync()))))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exercises = [
      for (final id in ['bench_press', 'lat_pulldown', 'shoulder_press'])
        WorkoutExercise(
          id: id,
          exerciseId: id,
          restSeconds: 180,
          sets: [
            for (var i = 0; i < 3; i++)
              WorkoutSet(id: '$i', weight: 50, reps: 10 - i),
          ],
        ),
    ];
    for (final dark in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Roboto',
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xffbf4e0b),
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: dark
                  ? const Color(0xff100e0b)
                  : const Color(0xfff5f2e9),
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('好友训练')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('训练伙伴'),
                      subtitle: Text('2026-09-07'),
                    ),
                    TrainingDetailsCard(
                      plainExpandable: true,
                      title: '上肢力量',
                      exercises: exercises,
                      nameFor: (id) => {
                        'bench_press': '卧推',
                        'lat_pulldown': '高位下拉',
                        'shoulder_press': '推举',
                      }[id]!,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: () {},
                          child: const Text('点赞 1'),
                        ),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('保存计划'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final e in exercises) {
          await precacheImage(
            AssetImage(exerciseAsset(e.exerciseId)),
            key.currentContext!,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('卧推'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '../artifacts/disclosure-${dark ? 'dark' : 'light'}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
