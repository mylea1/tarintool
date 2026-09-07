import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/training_details_card.dart';

void main() {
  final exercises = [
    WorkoutExercise(
      id: 'e',
      exerciseId: 'bench_press',
      restSeconds: 90,
      note: '个人动作备注',
      sets: [WorkoutSet(id: 's', weight: 42, reps: 9, note: '个人组备注')],
    ),
  ];
  testWidgets('shared preview and detail both use disclosure without artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingDetailsCard(
            plainExpandable: true,
            title: '上肢力量',
            exercises: exercises,
            nameFor: (_) => '卧推',
          ),
        ),
      ),
    );
    await tester.tap(find.text('卧推'));
    await tester.pumpAndSettle();
    expect(find.textContaining('42 kg'), findsOneWidget);
    expect(find.textContaining('个人组备注'), findsNothing);
    await tester.tap(find.text('上肢力量'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    final action = find.descendant(of: sheet, matching: find.text('卧推'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheet, matching: find.textContaining('42 kg')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.textContaining('个人')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  for (final private in [true, false]) {
    testWidgets('disclosure details and privacy $private', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainingExerciseAccordion(
              exercises: exercises,
              nameFor: (_) => '卧推',
              allowPrivateNotes: private,
            ),
          ),
        ),
      );
      expect(find.textContaining('42 kg'), findsNothing);
      await tester.tap(find.text('卧推'));
      await tester.pumpAndSettle();
      expect(find.textContaining('42 kg × 9 次'), findsOneWidget);
      expect(find.text('休息 90 秒'), findsOneWidget);
      expect(
        find.textContaining('个人动作备注'),
        private ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('个人组备注'),
        private ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('卧推'));
      await tester.pumpAndSettle();
      expect(find.textContaining('42 kg'), findsNothing);
    });
  }
  testWidgets('folder retains expansion; small screen and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var open = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SingleChildScrollView(
                  child: TrainingDisclosure(
                    expanded: open,
                    child: TrainingExerciseAccordion(
                      exercises: exercises,
                      nameFor: (_) => '超长动作名称用于验证小屏折行和触控',
                      allowPrivateNotes: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('超长动作名称用于验证小屏折行和触控'));
    await tester.pumpAndSettle();
    expect(find.textContaining('42 kg'), findsOneWidget);
    update(() => open = false);
    await tester.pumpAndSettle();
    expect(find.textContaining('42 kg'), findsNothing);
    update(() => open = true);
    await tester.pumpAndSettle();
    expect(find.textContaining('42 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
