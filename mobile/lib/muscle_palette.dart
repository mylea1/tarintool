import 'package:flutter/material.dart';

/// Shared semantic colours for the muscle overview surfaces.
///
/// Volume colours describe completed effective sets only. They are a visual
/// quantity scale, not a training recommendation or a medical assessment.
/// The bands are deliberately kept here so the home page, statistics, detail
/// pages and SVG body map cannot drift apart:
///
///   0 grey · 1–4 blue · 5–8 teal · 9–12 yellow-green · 13–16 gold ·
///   17–20 orange · 21+ coral red.
///
/// Recovery has a separate semantic scale. A missing map key means that no
/// value was supplied and is grey; an explicit 0 means 0% recovery and is red.
class MusclePalette {
  MusclePalette._();

  static const Color missing = Color(0xFFD7DCE5);

  static const Color volumeBlue = Color(0xFF559BCC);
  static const Color volumeTeal = Color(0xFF40AD9F);
  static const Color volumeLime = Color(0xFF90B75C);
  static const Color volumeGold = Color(0xFFDFB33E);
  static const Color volumeOrange = Color(0xFFE5893C);
  static const Color volumeCoral = Color(0xFFD75E65);

  static const Color recoveryRed = Color(0xFFD75E65);
  static const Color recoveryOrange = Color(0xFFE58B45);
  static const Color recoveryGold = Color(0xFFE6BA49);
  static const Color recoveryGreen = Color(0xFF94B765);
  static const Color recoveryTeal = Color(0xFF399CA7);

  static const List<String> volumeLegendLabels = <String>[
    '0组',
    '1–4组',
    '5–8组',
    '9–12组',
    '13–16组',
    '17–20组',
    '21+组',
  ];

  static const List<int> volumeLegendValues = <int>[0, 1, 5, 9, 13, 17, 21];

  static const List<String> recoveryLegendLabels = <String>[
    '0%',
    '40%',
    '60%',
    '80%',
    '100%',
  ];

  static const List<int> recoveryLegendValues = <int>[0, 40, 60, 80, 100];

  static const List<_PaletteStop> _volumeStops = <_PaletteStop>[
    _PaletteStop(0, missing),
    _PaletteStop(1, Color(0xFF74AAD0)),
    _PaletteStop(4, volumeBlue),
    _PaletteStop(5, Color(0xFF64B8AE)),
    _PaletteStop(8, volumeTeal),
    _PaletteStop(9, Color(0xFFA7C57B)),
    _PaletteStop(12, volumeLime),
    _PaletteStop(13, Color(0xFFE8C25D)),
    _PaletteStop(16, volumeGold),
    _PaletteStop(17, Color(0xFFEAA45C)),
    _PaletteStop(20, volumeOrange),
    _PaletteStop(21, Color(0xFFDE6B6B)),
    _PaletteStop(30, volumeCoral),
  ];

  static const List<_PaletteStop> _recoveryStops = <_PaletteStop>[
    _PaletteStop(0, recoveryRed),
    _PaletteStop(40, recoveryOrange),
    _PaletteStop(60, recoveryGold),
    _PaletteStop(80, recoveryGreen),
    _PaletteStop(100, recoveryTeal),
  ];

  /// Returns the continuous, segmented colour for an effective-set count.
  static Color volumeColor(num value) {
    final safe = value.toDouble();
    if (!safe.isFinite) return missing;
    return _interpolate(_volumeStops, safe.clamp(0, 30).toDouble());
  }

  /// Returns grey only when [group] is absent. An explicit zero still maps to
  /// the volume zero colour (which is grey by definition).
  static Color volumeColorFor(Map<String, num> values, String group) =>
      values.containsKey(group) ? volumeColor(values[group]!) : missing;

  /// Returns the recovery colour. `null` is missing data; zero is explicit red.
  static Color recoveryColor(num? percent) {
    if (percent == null) return missing;
    final safe = percent.toDouble();
    if (!safe.isFinite) return missing;
    return _interpolate(_recoveryStops, safe.clamp(0, 100).toDouble());
  }

  /// Returns grey only when [group] is absent. This distinction prevents a
  /// real 0% recovery value from being mistaken for missing data.
  static Color recoveryColorFor(Map<String, num> values, String group) =>
      values.containsKey(group) ? recoveryColor(values[group]) : missing;

  static LinearGradient volumeGradient(num value) {
    final safe = value.toDouble();
    if (!safe.isFinite) {
      return const LinearGradient(colors: <Color>[missing, missing]);
    }
    final amount = safe.clamp(0, 30).toDouble();
    final start = (amount - 3).clamp(0, 30).toDouble();
    return LinearGradient(
      colors: <Color>[volumeColor(start), volumeColor(amount)],
    );
  }

  static LinearGradient recoveryGradient(num? percent) {
    if (percent == null) {
      return const LinearGradient(colors: <Color>[missing, missing]);
    }
    final safe = percent.toDouble();
    if (!safe.isFinite) {
      return const LinearGradient(colors: <Color>[missing, missing]);
    }
    final amount = safe.clamp(0, 100).toDouble();
    final start = (amount - 18).clamp(0, 100).toDouble();
    return LinearGradient(
      colors: <Color>[recoveryColor(start), recoveryColor(amount)],
    );
  }

  static Color _interpolate(List<_PaletteStop> stops, double value) {
    if (value <= stops.first.value) return stops.first.color;
    for (var index = 1; index < stops.length; index++) {
      final upper = stops[index];
      if (value <= upper.value) {
        final lower = stops[index - 1];
        final span = upper.value - lower.value;
        final t = span == 0 ? 1.0 : (value - lower.value) / span;
        return Color.lerp(lower.color, upper.color, t) ?? upper.color;
      }
    }
    return stops.last.color;
  }
}

class _PaletteStop {
  const _PaletteStop(this.value, this.color);

  final double value;
  final Color color;
}
