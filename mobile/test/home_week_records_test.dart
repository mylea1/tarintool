import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

WorkoutRecord _record({
  required String id,
  required DateTime date,
  required String startTime,
  required String name,
}) => WorkoutRecord(
  id: id,
  name: name,
  date: date,
  startTime: startTime,
  durationSeconds: 1800,
  volume: 800,
  effectiveSets: 2,
  exerciseIds: const ['bench_press'],
  exercises: [
    WorkoutExercise(
      id: '$id-exercise',
      exerciseId: 'bench_press',
      sets: [
        WorkoutSet(id: '$id-set-1', weight: 40, reps: 8, completed: true),
        WorkoutSet(id: '$id-set-2', weight: 45, reps: 6, completed: true),
      ],
    ),
  ],
);

void _setViewport(WidgetTester tester, {required double width}) {
  tester.view.physicalSize = Size(width, 850);
  tester.view.devicePixelRatio = 1;
}

Finder _homeVerticalScrollable() => find
    .descendant(
      of: find.byType(ListView).first,
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _pumpHome(
  WidgetTester tester,
  AppController controller, {
  double? textScale,
}) async {
  final app = MaterialApp(
    builder: (context, child) {
      if (textScale == null) return child!;
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: Scaffold(body: HomePage(controller: controller)),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> _selectHomeDay(WidgetTester tester, DateTime date) async {
  final day = find.byKey(Key('home-week-day-${_dayKey(date)}'));
  await tester.scrollUntilVisible(
    day,
    160,
    scrollable: _homeVerticalScrollable(),
  );
  expect(day, findsOneWidget);
  await tester.pumpAndSettle();
  await tester.tap(day);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'home day shows sorted same-day records and detail at 320dp with 200% text',
    (tester) async {
      _setViewport(tester, width: 320);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final controller = AppController();
      addTearDown(controller.dispose);
      final today = _today();
      controller.history.addAll([
        _record(
          id: 'late-record',
          date: today,
          startTime: '18:30',
          name: '晚间训练',
        ),
        _record(
          id: 'early-record',
          date: today,
          startTime: '9:05',
          name: '晨间训练',
        ),
      ]);

      await _pumpHome(tester, controller);
      final day = find.byKey(Key('home-week-day-${_dayKey(today)}'));
      await tester.scrollUntilVisible(
        day,
        160,
        scrollable: _homeVerticalScrollable(),
      );
      await tester.pumpAndSettle();
      expect(day, findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _selectHomeDay(tester, today);
      expect(
        find.byKey(const Key('home-day-training-section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home-muscle-card')), findsNothing);
      expect(
        find.byKey(const Key('home-day-record-early-record')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home-day-record-late-record')),
        findsOneWidget,
      );
      expect(find.text('晨间训练'), findsOneWidget);
      expect(find.text('晚间训练'), findsOneWidget);

      final early = tester.getRect(
        find.byKey(const Key('home-day-record-early-record')),
      );
      final late = tester.getRect(
        find.byKey(const Key('home-day-record-late-record')),
      );
      expect(early.top, lessThan(late.top));

      final firstRecord = find.byKey(const Key('home-day-record-early-record'));
      await tester.scrollUntilVisible(
        firstRecord,
        160,
        scrollable: _homeVerticalScrollable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(firstRecord);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('record-detail-early-record')),
        findsOneWidget,
      );
      // This is the existing record bottom sheet, not a pushed page. Close it
      // through the exposed modal barrier, just as a user would.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('record-detail-early-record')), findsNothing);

      final back = find.byKey(const Key('home-day-training-back'));
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-day-training-section')), findsNothing);
      expect(find.byKey(const Key('home-muscle-card')), findsOneWidget);
      expect(controller.workoutStarted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home empty day shows its real scheduled plan label', (
    tester,
  ) async {
    _setViewport(tester, width: 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController();
    addTearDown(controller.dispose);
    final today = _today();
    final emptyDay = today.weekday == DateTime.monday
        ? today.add(const Duration(days: 1))
        : today.subtract(const Duration(days: 1));
    final key = _dayKey(emptyDay);
    controller.scheduled.add(key);
    controller.scheduledLabels[key] = '肩腿力量计划';

    await _pumpHome(tester, controller);
    await _selectHomeDay(tester, emptyDay);

    expect(find.byKey(const Key('home-day-records-empty')), findsOneWidget);
    expect(find.text('计划：肩腿力量计划'), findsOneWidget);
    expect(find.text('当天有计划，完成后会显示记录。'), findsOneWidget);
    expect(controller.history, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home calendar preserves the muscle carousel when returning', (
    tester,
  ) async {
    _setViewport(tester, width: 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController();
    addTearDown(controller.dispose);
    final today = _today();
    controller.history.add(
      _record(
        id: 'carousel-record',
        date: today,
        startTime: '12:00',
        name: '午间训练',
      ),
    );

    await _pumpHome(tester, controller);
    final recoveryTab = find.byKey(const Key('home-muscle-recovery-tab'));
    await tester.scrollUntilVisible(
      recoveryTab,
      160,
      scrollable: _homeVerticalScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(recoveryTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-muscle-open-recovery')), findsOneWidget);

    await _selectHomeDay(tester, today);
    expect(find.byKey(const Key('home-muscle-card')), findsNothing);
    await tester.tap(find.byKey(const Key('home-day-training-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-muscle-card')), findsOneWidget);
    expect(find.byKey(const Key('home-muscle-open-recovery')), findsOneWidget);
    expect(find.byKey(const Key('home-muscle-volume-tab')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
