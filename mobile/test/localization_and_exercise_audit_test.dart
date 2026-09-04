import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/app_localizations.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/main.dart';
import 'package:kilo_strength/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('exercise display names are unique after localization audit', () {
    final chineseNames = catalog.map((exercise) => exercise.name).toList();
    final englishLabels = catalog
        .map((exercise) => '${exercise.englishName}|${exercise.id}')
        .toList();

    expect(chineseNames.toSet().length, chineseNames.length);
    expect(englishLabels.toSet().length, englishLabels.length);
    for (final exercise in catalog) {
      expect(exerciseAsset(exercise.id), isNotEmpty);
    }
  });

  test('equipment variants share one compact barbell filter', () {
    expect(equipmentGroupForLabel('杠铃'), '杠铃');
    expect(equipmentGroupForLabel('曲杆杠铃'), '杠铃');
    expect(equipmentGroupForLabel('六角杠铃'), '杠铃');
    expect(equipmentGroupForLabel('奥杆'), '杠铃');
    expect(equipmentGroupForLabel('哑铃'), '哑铃');
    expect(equipmentGroupForLabel('壶铃'), '壶铃');
    expect(equipmentGroupForLabel('药球'), '药球');
  });

  test('cardio machines share the cardio filter', () {
    expect(equipmentGroupForLabel('固定自行车'), '有氧');
    expect(equipmentGroupForLabel('椭圆机'), '有氧');
    expect(equipmentGroupForLabel('登阶机'), '有氧');
    expect(equipmentGroupForLabel('stationary bike'), '有氧');
  });

  test('retired equipment is hidden from selectable catalog', () {
    const forbidden = [
      '波速球',
      '滑雪机',
      '训练锤',
      '壶铃',
      '弹力带',
      '阻力带',
      '训练绳',
      'kettlebell',
      'resistance band',
      'battle rope',
    ];
    expect(
      selectableCatalog.where(
        (item) => forbidden.any(
          (label) =>
              '${item.name}${item.equipment}${item.family}'.contains(label),
        ),
      ),
      isEmpty,
    );
    expect(catalog.length, greaterThan(selectableCatalog.length));
  });

  test('only the five requested bodyweight actions remain selectable', () {
    final bodyweight = selectableCatalog.where(
      (item) =>
          item.loadMode == 'bodyweight' ||
          item.equipment.contains('自重') ||
          item.equipment.toLowerCase().contains('bodyweight'),
    );
    expect(bodyweight.map((item) => item.id).toSet(), {
      'pull_up',
      'dip',
      'push_up',
      'dataset_0274',
      'dataset_0472',
    });
  });

  test('all specifically requested catalog numbers are retired', () {
    final numbers = <int>{
      39,
      40,
      42,
      43,
      45,
      68,
      69,
      71,
      74,
      263,
      265,
      269,
      270,
      272,
      273,
      274,
      276,
      277,
      278,
      279,
      280,
      281,
      282,
      283,
      284,
      285,
      286,
      287,
      288,
      292,
      293,
      294,
      456,
      458,
      459,
      460,
      461,
      464,
      466,
      470,
      473,
      475,
      476,
      479,
      480,
      761,
      763,
      764,
      811,
      812,
      813,
      817,
      819,
      ...List<int>.generate(27, (index) => 820 + index),
      ...List<int>.generate(5, (index) => 848 + index),
    };
    final selectableIds = selectableCatalog.map((item) => item.id).toSet();
    for (final number in numbers) {
      final id = catalog[number - 1].id;
      if (id == 'dataset_0472') continue;
      expect(selectableIds, isNot(contains(id)));
    }
  });

  test('display names omit equipment words and cardio is categorized', () {
    final controller = AppController();
    addTearDown(controller.dispose);
    expect(controller.displayExerciseName(catalog.first), '推胸');
    expect(controller.equipmentFilterOptions, isNot(contains('壶铃')));
    expect(selectableCatalog.where(isCardioExerciseDefinition), isNotEmpty);
  });

  test('deltoid labels are included in shoulder filtering', () {
    expect(muscleGroupForLabel('三角肌'), '肩');
    expect(muscleGroupForLabel('三角肌中束'), '肩');
  });

  test('controller filters grouped barbell variants and deltoids', () {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.equipmentFilter = '杠铃';
    expect(controller.visibleExercises, isNotEmpty);
    expect(
      controller.visibleExercises.every(
        (item) => equipmentGroupForLabel(item.equipment) == '杠铃',
      ),
      isTrue,
    );

    controller.equipmentFilter = '全部';
    controller.muscleFilter = '肩';
    expect(
      controller.visibleExercises.any(
        (item) => muscleGroupForLabel(item.muscle) == '肩',
      ),
      isTrue,
    );
    expect(controller.equipmentFilterOptions, contains('有氧'));
  });

  test('custom exercises persist for the signed-in account', () async {
    final first = AppController();
    addTearDown(first.dispose);
    expect(first.loginWithPhone('123', password: '123').isSuccess, isTrue);
    final created = first.addCustomExercise(
      name: '我的测试动作',
      englishName: '',
      equipment: '自定义器械',
      muscle: '三角肌',
      cue: '保持稳定',
    );
    await first.flushCustomExercisePersistence();

    final restored = AppController();
    addTearDown(restored.dispose);
    expect(restored.loginWithPhone('123', password: '123').isSuccess, isTrue);
    await restored.hydrateCustomExercises(force: true);

    expect(restored.customExercises.single.id, created.id);
    expect(restored.customExercises.single.name, '我的测试动作');
  });

  testWidgets('English language changes navigation and exercise names', (
    tester,
  ) async {
    final controller = AppController();
    controller.appLanguage = AppLanguage.english;
    await tester.pumpWidget(KiloApp(initialController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);

    controller.selectPage(PageId.exercises);
    await tester.pumpAndSettle();
    expect(find.text('Exercise Library'), findsWidgets);
    expect(
      find.text(controller.displayExerciseName(selectableCatalog.first)),
      findsWidgets,
    );
    controller.dispose();
  });

  testWidgets('language control exposes Chinese and English options', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(KiloApp(initialController: controller));
    controller.selectPage(PageId.profile);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('app-language-setting')));
    await tester.tap(find.byKey(const Key('app-language-setting')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-language-zh')), findsOneWidget);
    expect(find.byKey(const Key('app-language-en')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('language can be changed before the first sign in', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        locale: controller.appLanguage.locale,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: LoginPage(controller: controller),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(controller.appLanguage, AppLanguage.english);

    await tester.pumpWidget(
      MaterialApp(
        locale: controller.appLanguage.locale,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: LoginPage(controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Phone number'), findsOneWidget);
    controller.dispose();
  });
}
