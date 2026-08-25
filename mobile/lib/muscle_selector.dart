import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The SVG body map used by the mini-program muscle selector.
///
/// The source files keep a 660.46 × 1206.46 viewBox.  Keeping the same aspect
/// ratio here is important: the rendered body does not stretch when Android
/// text is scaled to 200%. Taps use the source selector's 48 × 88 alpha masks
/// from masks.js and resolve overlapping areas from the smallest mask first.
/// Approximate regions are used only during the brief asynchronous asset load.
enum MuscleMapGender { male, female }

enum MuscleMapSide { front, back }

class InteractiveMuscleMap extends StatefulWidget {
  const InteractiveMuscleMap({
    super.key,
    required this.muscleSets,
    this.height = 250,
    this.gender = MuscleMapGender.male,
    this.onMuscleTap,
    this.showSideToggle = true,
  });

  final Map<String, int> muscleSets;
  final double height;
  final MuscleMapGender gender;
  final ValueChanged<String>? onMuscleTap;
  final bool showSideToggle;

  @override
  State<InteractiveMuscleMap> createState() => _InteractiveMuscleMapState();
}

class _InteractiveMuscleMapState extends State<InteractiveMuscleMap> {
  static Future<Map<String, dynamic>>? _maskDataFuture;

  MuscleMapSide side = MuscleMapSide.front;
  final selected = <String>{};
  Map<String, dynamic>? _maskData;

  @override
  void initState() {
    super.initState();
    _loadMasks();
  }

  Future<void> _loadMasks() async {
    final data = await (_maskDataFuture ??= _readMasks());
    if (mounted) setState(() => _maskData = data);
  }

  static Future<Map<String, dynamic>> _readMasks() async {
    final source = await rootBundle.loadString(
      'assets/muscle-selector/masks.js',
    );
    final json = source
        .replaceFirst(RegExp(r'^\s*module\.exports\s*=\s*'), '')
        .replaceFirst(RegExp(r';\s*$'), '');
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static const labels = <String, String>{
    'abs': '腹肌',
    'adductors': '内收肌',
    'biceps': '肱二头肌',
    'calves': '小腿',
    'chest': '胸',
    'deltoids': '三角肌',
    'forearm': '前臂',
    'gluteal': '臀部',
    'hamstring': '腘绳肌',
    'lower-back': '下背部',
    'obliques': '腹斜肌',
    'quadriceps': '股四头肌',
    'tibialis': '胫骨前肌',
    'trapezius': '斜方肌',
    'triceps': '肱三头肌',
    'upper-back': '上背部',
  };

  static const overlayGroups = <String, String>{
    'abs': '核心',
    'adductors': '腿',
    'biceps': '手臂',
    'calves': '腿',
    'chest': '胸',
    'deltoids': '肩',
    'forearm': '手臂',
    'gluteal': '腿',
    'hamstring': '腿',
    'lower-back': '背',
    'obliques': '核心',
    'quadriceps': '腿',
    'tibialis': '腿',
    'trapezius': '背',
    'triceps': '手臂',
    'upper-back': '背',
  };

  static const _frontRegions = <_MuscleMaskRegion>[
    _MuscleMaskRegion('trapezius', 17, 13, 31, 16),
    _MuscleMaskRegion('deltoids', 11, 15, 37, 22),
    _MuscleMaskRegion('chest', 14, 16, 34, 25),
    _MuscleMaskRegion('biceps', 8, 22, 40, 31),
    _MuscleMaskRegion('obliques', 15, 23, 33, 38),
    _MuscleMaskRegion('abs', 20, 24, 28, 43),
    _MuscleMaskRegion('forearm', 2, 28, 46, 40),
    _MuscleMaskRegion('quadriceps', 14, 38, 34, 63),
    _MuscleMaskRegion('calves', 11, 64, 37, 88),
  ];

  // These overlays are present only in the female source asset set.
  static const _femaleFrontExtraRegions = <_MuscleMaskRegion>[
    _MuscleMaskRegion('adductors', 18, 47, 30, 62),
    _MuscleMaskRegion('tibialis', 14, 62, 34, 79),
  ];

  static const _backRegions = <_MuscleMaskRegion>[
    _MuscleMaskRegion('trapezius', 20, 17, 28, 27),
    _MuscleMaskRegion('deltoids', 11, 15, 37, 21),
    _MuscleMaskRegion('upper-back', 14, 17, 34, 39),
    _MuscleMaskRegion('triceps', 7, 20, 41, 30),
    _MuscleMaskRegion('forearm', 1, 28, 47, 40),
    _MuscleMaskRegion('lower-back', 20, 26, 28, 39),
    _MuscleMaskRegion('gluteal', 17, 37, 31, 47),
    _MuscleMaskRegion('hamstring', 14, 38, 34, 63),
    _MuscleMaskRegion('calves', 13, 65, 35, 75),
  ];

  String _baseAsset() {
    final gender = widget.gender == MuscleMapGender.female ? 'female' : 'male';
    final sideName = side == MuscleMapSide.front ? 'front' : 'back';
    return 'assets/muscle-selector/$gender-$sideName-base.svg';
  }

  List<_MuscleMaskRegion> get _regions {
    if (side == MuscleMapSide.back) return _backRegions;
    if (widget.gender == MuscleMapGender.female) {
      return [..._frontRegions, ..._femaleFrontExtraRegions];
    }
    return _frontRegions;
  }

  String _overlayAsset(String slug) {
    final gender = widget.gender == MuscleMapGender.female ? 'female' : 'male';
    final sideName = side == MuscleMapSide.front ? 'front' : 'back';
    return 'assets/muscle-selector/$gender-$sideName-$slug.svg';
  }

  Color _heat(String group, {bool selected = false}) {
    final maxValue = widget.muscleSets.values.fold<int>(
      1,
      (max, value) => value > max ? value : max,
    );
    final value = widget.muscleSets[group] ?? 0;
    final amount = value <= 0
        ? 0.18
        : (.24 + value / maxValue * .68).clamp(.24, .92);
    final base = selected ? const Color(0xFFF36A1D) : const Color(0xFFD95718);
    return base.withValues(alpha: amount);
  }

  void _toggle(String slug) {
    setState(() {
      if (!selected.add(slug)) selected.remove(slug);
    });
    widget.onMuscleTap?.call(slug);
  }

  void _tapBody(TapUpDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final point = details.localPosition;
    final x = (point.dx / size.width * 48).floor().clamp(0, 47);
    final y = (point.dy / size.height * 88).floor().clamp(0, 87);
    final maskHit = _maskHit(x, y);
    if (maskHit != null) {
      _toggle(maskHit);
      return;
    }
    // Keep a forgiving fallback while the small mask asset is still loading.
    final hit = _regions.firstWhere(
      (region) => region.contains(x.toDouble(), y.toDouble()),
      orElse: () => const _MuscleMaskRegion('', 0, 0, 0, 0),
    );
    if (hit.slug.isNotEmpty) _toggle(hit.slug);
  }

  String? _maskHit(int x, int y) {
    final genders = _maskData?['genders'] as Map<String, dynamic>?;
    final gender = widget.gender == MuscleMapGender.female ? 'female' : 'male';
    final sides = genders?[gender] as Map<String, dynamic>?;
    final sideName = side == MuscleMapSide.front ? 'front' : 'back';
    final muscles = sides?[sideName] as Map<String, dynamic>?;
    if (muscles == null) return null;
    final entries = muscles.entries.toList()
      ..sort((a, b) {
        final left = a.value as Map<String, dynamic>;
        final right = b.value as Map<String, dynamic>;
        return (left['pixelCount'] as num).compareTo(
          right['pixelCount'] as num,
        );
      });
    for (final entry in entries) {
      final mask = entry.value as Map<String, dynamic>;
      final rows = mask['rows'] as List<dynamic>;
      final row = rows[y] as String;
      final nibble = int.parse(row[x ~/ 4], radix: 16);
      final bit = 3 - (x % 4);
      if ((nibble & (1 << bit)) != 0) return entry.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: AspectRatio(
        aspectRatio: 660.46 / 1206.46,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: const Key('interactive-muscle-body'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _tapBody(
              details,
              Size(constraints.maxWidth, constraints.maxHeight),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.asset(_baseAsset(), fit: BoxFit.contain),
                for (final region in _regions)
                  if (overlayGroups.containsKey(region.slug))
                    IgnorePointer(
                      child: SvgPicture.asset(
                        _overlayAsset(region.slug),
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          _heat(
                            overlayGroups[region.slug]!,
                            selected: selected.contains(region.slug),
                          ),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    final selectedLabels = selected
        .map((slug) => labels[slug] ?? slug)
        .toList();
    return Semantics(
      container: true,
      label: '可互动肌群图，当前为${side == MuscleMapSide.front ? '正面' : '背面'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showSideToggle)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SideButton(
                    label: '正面',
                    selected: side == MuscleMapSide.front,
                    onPressed: () => setState(() => side = MuscleMapSide.front),
                  ),
                  const SizedBox(width: 6),
                  _SideButton(
                    label: '背面',
                    selected: side == MuscleMapSide.back,
                    onPressed: () => setState(() => side = MuscleMapSide.back),
                  ),
                ],
              ),
            ),
          SizedBox(height: widget.height, width: double.infinity, child: body),
          if (selectedLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                selectedLabels.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF756156), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label人体图',
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: selected
            ? const Color(0xFFD95718)
            : const Color(0xFF756156),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    ),
  );
}

class _MuscleMaskRegion {
  const _MuscleMaskRegion(
    this.slug,
    this.left,
    this.top,
    this.right,
    this.bottom,
  );
  final String slug;
  final double left;
  final double top;
  final double right;
  final double bottom;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;
}
