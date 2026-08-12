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
    expect(find.text(catalog.first.englishName), findsWidgets);
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
    expect(find.text('Phone or account'), findsOneWidget);
    controller.dispose();
  });
}
