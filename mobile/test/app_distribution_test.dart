import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/app_distribution.dart';

void main() {
  test('china builds expose phone on Android and phone plus Apple on iOS', () {
    const distribution = AppDistribution(market: AppMarket.china);

    expect(distribution.loginMethodsFor(TargetPlatform.android), [
      LoginMethod.phone,
    ]);
    expect(distribution.loginMethodsFor(TargetPlatform.iOS), [
      LoginMethod.phone,
      LoginMethod.apple,
    ]);
  });

  test(
    'global builds keep phone on Android and use Apple plus Google on iOS',
    () {
      const distribution = AppDistribution(market: AppMarket.global);

      expect(distribution.loginMethodsFor(TargetPlatform.android), [
        LoginMethod.phone,
      ]);
      expect(distribution.loginMethodsFor(TargetPlatform.iOS), [
        LoginMethod.apple,
        LoginMethod.google,
      ]);
    },
  );
}
