import 'package:flutter/foundation.dart';

enum AppMarket { china, global }

enum LoginMethod { phone, apple, google }

@immutable
class AppDistribution {
  const AppDistribution({required this.market});

  factory AppDistribution.fromEnvironment() {
    const configured = String.fromEnvironment('APP_MARKET', defaultValue: 'cn');
    return const AppDistribution(
      market: configured == 'global' ? AppMarket.global : AppMarket.china,
    );
  }

  final AppMarket market;

  bool get isChina => market == AppMarket.china;

  List<LoginMethod> loginMethodsFor(TargetPlatform platform) =>
      switch ((market, platform)) {
        (AppMarket.china, TargetPlatform.iOS) => const [
          LoginMethod.phone,
          LoginMethod.apple,
        ],
        (AppMarket.global, TargetPlatform.iOS) => const [
          LoginMethod.apple,
          LoginMethod.google,
        ],
        (_, TargetPlatform.android) => const [LoginMethod.phone],
        _ => const [LoginMethod.phone],
      };
}

final appDistribution = AppDistribution.fromEnvironment();
