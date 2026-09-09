import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/legal_links.dart';

void main() {
  testWidgets('iOS legal links open the published documents before login', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: LegalLinks(
            opener: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('legal-eula-link')));
    await tester.tap(find.byKey(const Key('legal-privacy-link')));
    expect(opened, [Uri.parse(appleEulaUrl), Uri.parse(privacyPolicyUrl)]);
  });

  testWidgets('Android does not apply Apple EULA; failed link is recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(body: LegalLinks(opener: (_) async => false)),
      ),
    );
    expect(find.byKey(const Key('legal-eula-link')), findsNothing);
    await tester.tap(find.byKey(const Key('legal-privacy-link')));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法打开链接'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('legal links fit 320px with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            brightness: brightness,
          ),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: LegalLinks()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final key in ['legal-eula-link', 'legal-privacy-link']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
    });
  }
}
