import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

const workoutShareCardAspectRatio = 12 / 7;
const workoutResultCardAspectRatio = 1200 / 950;

Color workoutShareAccent(String style) => switch (style) {
  'midnight' => const Color(0xFF5B8CFF),
  'forest' => const Color(0xFF42C8A2),
  'titanium' => const Color(0xFFD6DCE2),
  'gold' => const Color(0xFFD7A84E),
  'electric' => const Color(0xFF3487FF),
  _ => const Color(0xFFFF6A1A),
};

String workoutShareStyleLabel(String style) => switch (style) {
  'midnight' => '冷蓝',
  'forest' => '青绿',
  'titanium' => '银白',
  'gold' => '金色',
  'electric' => '电光蓝',
  _ => '活力橙',
};

class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.workoutName,
    required this.date,
    required this.durationSeconds,
    required this.volume,
    required this.effectiveSets,
    this.cardStyle = 'coral',
    this.localPhotoPath,
    this.photoImageProvider,
  });

  factory WorkoutShareCard.fromRecord({
    Key? key,
    required WorkoutRecord record,
    String cardStyle = 'coral',
    String? localPhotoPath,
  }) => WorkoutShareCard(
    key: key,
    workoutName: record.name,
    date: record.date,
    durationSeconds: record.durationSeconds,
    volume: record.volume,
    effectiveSets: record.effectiveSets,
    cardStyle: cardStyle,
    localPhotoPath: localPhotoPath,
  );

  final String workoutName;
  final DateTime date;
  final int durationSeconds;
  final double volume;
  final int effectiveSets;
  final String cardStyle;
  final String? localPhotoPath;
  final ImageProvider<Object>? photoImageProvider;

  String get _date =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  String get _minutes => '${(durationSeconds / 60).round()}';

  String get _volume => volume >= 1000
      ? '${(volume / 1000).toStringAsFixed(1)}T'
      : '${volume.toStringAsFixed(0)}KG';

  @override
  Widget build(BuildContext context) {
    final accent = workoutShareAccent(cardStyle);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: AspectRatio(
        aspectRatio: workoutShareCardAspectRatio,
        child: FittedBox(
          fit: BoxFit.fill,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: SizedBox(
              width: 1200,
              height: 700,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _ShareSurfacePainter(accent: accent)),
                  ClipPath(
                    clipper: const _ShareVisualClipper(),
                    child: localPhotoPath == null && photoImageProvider == null
                        ? _BrandVisual(accent: accent)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                key: const Key('workout-share-photo'),
                                image:
                                    photoImageProvider ??
                                    FileImage(File(localPhotoPath!)),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, _, _) =>
                                    _BrandVisual(accent: accent),
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xE617181A),
                                      Color(0x66101012),
                                      Color(0x05000000),
                                    ],
                                    stops: [0, .22, .58],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  CustomPaint(painter: _ShareFoldPainter(accent: accent)),
                  Positioned(
                    left: 64,
                    top: 54,
                    width: 545,
                    bottom: 54,
                    child: _ShareInformation(
                      workoutName: workoutName,
                      minutes: _minutes,
                      volume: _volume,
                      effectiveSets: '$effectiveSets',
                      date: _date,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A complete training-result surface. Personal/share mode stops after the
/// exercise list; social mode accepts a lightweight interaction footer.
class WorkoutResultCard extends StatelessWidget {
  const WorkoutResultCard({
    super.key,
    required this.workoutName,
    required this.date,
    required this.durationSeconds,
    required this.volume,
    required this.effectiveSets,
    required this.completionPercent,
    required this.exerciseNames,
    this.cardStyle = 'coral',
    this.localPhotoPath,
    this.photoImageProvider,
    this.socialFooter,
  });

  final String workoutName;
  final DateTime date;
  final int durationSeconds;
  final double volume;
  final int effectiveSets;
  final int completionPercent;
  final List<String> exerciseNames;
  final String cardStyle;
  final String? localPhotoPath;
  final ImageProvider<Object>? photoImageProvider;
  final Widget? socialFooter;

  @override
  Widget build(BuildContext context) {
    final accent = workoutShareAccent(cardStyle);
    final visible = exerciseNames.take(3).toList(growable: false);
    final remaining = exerciseNames.length - visible.length;
    final canvasHeight = socialFooter == null ? 950.0 : 1100.0;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1,
      child: AspectRatio(
        aspectRatio: 1200 / canvasHeight,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: 1200,
            height: canvasHeight,
            child: Container(
              key: const Key('workout-result-card'),
              decoration: BoxDecoration(
                color: const Color(0xFF111214),
                borderRadius: BorderRadius.circular(42),
                border: Border.all(color: const Color(0xFF34363A)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  WorkoutShareCard(
                    workoutName: workoutName,
                    date: date,
                    durationSeconds: durationSeconds,
                    volume: volume,
                    effectiveSets: effectiveSets,
                    cardStyle: cardStyle,
                    localPhotoPath: localPhotoPath,
                    photoImageProvider: photoImageProvider,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 24, 34, 28),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ResultMetric(
                                icon: Icons.timer_outlined,
                                value: '${(durationSeconds / 60).round()} 分钟',
                                label: '时长',
                                accent: accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ResultMetric(
                                icon: Icons.fitness_center_outlined,
                                value: '${volume.toStringAsFixed(0)} kg',
                                label: '总量',
                                accent: accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ResultMetric(
                                icon: Icons.task_alt_rounded,
                                value: '$effectiveSets 组',
                                label: '组数',
                                accent: accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ResultMetric(
                                icon: Icons.percent_rounded,
                                value: '${completionPercent.clamp(0, 100)}%',
                                label: '完成度',
                                accent: accent,
                              ),
                            ),
                          ],
                        ),
                        if (visible.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              for (
                                var index = 0;
                                index < visible.length;
                                index++
                              ) ...[
                                Expanded(
                                  child: _ExerciseResultChip(
                                    name: visible[index],
                                    accent: accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (remaining > 0)
                                Expanded(
                                  child: _ExerciseResultChip(
                                    name: '还有 $remaining 个动作 ›',
                                    accent: accent,
                                    quiet: true,
                                  ),
                                )
                              else if (visible.length < 4)
                                for (
                                  var index = visible.length;
                                  index < 4;
                                  index++
                                )
                                  const Expanded(child: SizedBox()),
                            ],
                          ),
                        ],
                        if (socialFooter != null) ...[
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFF3A3C40)),
                          const SizedBox(height: 14),
                          socialFooter!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    height: 102,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1C1F),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF36383D)),
    ),
    child: Row(
      children: [
        Icon(icon, color: accent, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF96999F), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExerciseResultChip extends StatelessWidget {
  const _ExerciseResultChip({
    required this.name,
    required this.accent,
    this.quiet = false,
  });
  final String name;
  final Color accent;
  final bool quiet;

  @override
  Widget build(BuildContext context) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF202124),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFF3B3D42)),
    ),
    child: Row(
      children: [
        if (!quiet) ...[
          Icon(Icons.fitness_center_rounded, size: 20, color: accent),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: quiet ? const Color(0xFFB3B5BA) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ShareInformation extends StatelessWidget {
  const _ShareInformation({
    required this.workoutName,
    required this.minutes,
    required this.volume,
    required this.effectiveSets,
    required this.date,
    required this.accent,
  });

  final String workoutName;
  final String minutes;
  final String volume;
  final String effectiveSets;
  final String date;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, .18)!, accent],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .24),
                  offset: const Offset(0, 8),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          const SizedBox(width: 18),
          const Text(
            'KILOSTRENGTH',
            style: TextStyle(
              color: Color(0xFFF3F4F6),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 6.2,
            ),
          ),
        ],
      ),
      const SizedBox(height: 82),
      const Text(
        'TRAINING / COMPLETE',
        style: TextStyle(
          color: Color(0xFFB7B9BF),
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 5.1,
        ),
      ),
      const SizedBox(height: 24),
      Text(
        workoutName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFF7F7F8),
          fontSize: 58,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
          shadows: [
            Shadow(
              color: Color(0x75000000),
              offset: Offset(0, 4),
              blurRadius: 9,
            ),
          ],
        ),
      ),
      const Spacer(),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _ShareMetric(value: minutes, label: 'MIN', accent: accent),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ShareMetric(value: volume, label: 'VOLUME', accent: accent),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ShareMetric(
              value: effectiveSets,
              label: 'SETS',
              accent: accent,
            ),
          ),
        ],
      ),
      const SizedBox(height: 66),
      Text(
        date,
        style: const TextStyle(
          color: Color(0xFF9A9DA3),
          fontSize: 24,
          fontWeight: FontWeight.w500,
          letterSpacing: 3.2,
        ),
      ),
    ],
  );
}

class _ShareMetric extends StatelessWidget {
  const _ShareMetric({
    required this.value,
    required this.label,
    required this.accent,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: const TextStyle(
          color: Color(0xFFF7F7F8),
          fontSize: 44,
          height: 1,
          fontWeight: FontWeight.w400,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 13),
      Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.1,
        ),
      ),
    ],
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 82,
    margin: const EdgeInsets.only(right: 24),
    color: const Color(0xFF56595F),
  );
}

class _BrandVisual extends StatelessWidget {
  const _BrandVisual({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _BrandVisualPainter(accent: accent),
    child: const SizedBox.expand(),
  );
}

class _ShareVisualClipper extends CustomClipper<Path> {
  const _ShareVisualClipper();

  @override
  Path getClip(Size size) {
    final sx = size.width / 1200;
    final sy = size.height / 700;
    return Path()
      ..moveTo(704 * sx, 0)
      ..cubicTo(666 * sx, 98 * sy, 607 * sx, 188 * sy, 572 * sx, 257 * sy)
      ..cubicTo(539 * sx, 321 * sy, 548 * sx, 375 * sy, 582 * sx, 443 * sy)
      ..cubicTo(621 * sx, 521 * sy, 657 * sx, 605 * sy, 695 * sx, 700 * sy)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ShareSurfacePainter extends CustomPainter {
  const _ShareSurfacePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF303236), Color(0xFF17181A), Color(0xFF090A0B)],
          stops: [0, .52, 1],
        ).createShader(rect),
    );
    final wash = Rect.fromLTWH(360, 0, 500, size.height);
    canvas.drawRect(
      wash,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            accent.withValues(alpha: .075),
            Colors.transparent,
          ],
          stops: const [0, .57, 1],
        ).createShader(wash),
    );
  }

  @override
  bool shouldRepaint(covariant _ShareSurfacePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _ShareFoldPainter extends CustomPainter {
  const _ShareFoldPainter({required this.accent});

  final Color accent;

  Path _seam(Size size) {
    final sx = size.width / 1200;
    final sy = size.height / 700;
    return Path()
      ..moveTo(704 * sx, 0)
      ..cubicTo(666 * sx, 98 * sy, 607 * sx, 188 * sy, 572 * sx, 257 * sy)
      ..cubicTo(539 * sx, 321 * sy, 548 * sx, 375 * sy, 582 * sx, 443 * sy)
      ..cubicTo(621 * sx, 521 * sy, 657 * sx, 605 * sy, 695 * sx, 700 * sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final seam = _seam(size);
    canvas.drawPath(
      seam,
      Paint()
        ..color = Colors.black.withValues(alpha: .40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawPath(
      seam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: .28),
            Color.lerp(accent, Colors.white, .45)!,
            accent.withValues(alpha: .38),
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      seam,
      Paint()
        ..color = Colors.white.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  @override
  bool shouldRepaint(covariant _ShareFoldPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _BrandVisualPainter extends CustomPainter {
  const _BrandVisualPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .79, size.height * .5);
    final radius = math.min(size.width, size.height) * .31;
    final glowRect = Rect.fromCircle(center: center, radius: radius * 1.42);
    canvas.drawCircle(
      center,
      radius * 1.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: .20),
            accent.withValues(alpha: .05),
            Colors.transparent,
          ],
          stops: const [0, .48, 1],
        ).createShader(glowRect),
    );
    for (final scale in [1.15, 1.38, 1.62]) {
      canvas.drawCircle(
        center,
        radius * scale,
        Paint()
          ..color = accent.withValues(alpha: .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }

    final markRect = Rect.fromCircle(center: center, radius: radius * .72);
    canvas.drawArc(
      markRect,
      .18 * math.pi,
      1.54 * math.pi,
      false,
      Paint()
        ..color = const Color(0xFF111113)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * .19,
    );
    canvas.drawArc(
      markRect,
      .18 * math.pi,
      1.54 * math.pi,
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF4B4B4E),
            Color(0xFF111113),
            Color(0xFFE1E1E3),
            Color(0xFF171719),
            Color(0xFF4B4B4E),
          ],
        ).createShader(markRect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * .16,
    );
    canvas.drawArc(
      markRect,
      1.55 * math.pi,
      .34 * math.pi,
      false,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, .28)!,
            accent,
            Color.lerp(accent, Colors.black, .35)!,
          ],
        ).createShader(markRect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * .17,
    );

    final nodeFill = Paint()..color = const Color(0xFF171719);
    final edge = Paint()
      ..color = Color.lerp(accent, Colors.white, .55)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final nodes = [
      center + Offset(-radius * .49, -radius * .42),
      center + Offset(radius * .20, radius * .64),
    ];
    for (final node in nodes) {
      canvas.drawCircle(node, radius * .105, nodeFill);
      canvas.drawCircle(node, radius * .105, edge);
    }

    final triangle = Path()
      ..moveTo(center.dx + radius * .46, center.dy - radius * .12)
      ..lineTo(center.dx + radius * .72, center.dy)
      ..lineTo(center.dx + radius * .46, center.dy + radius * .12)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A5A5E), Color(0xFF111113)],
        ).createShader(triangle.getBounds()),
    );
    canvas.drawPath(triangle, edge);
  }

  @override
  bool shouldRepaint(covariant _BrandVisualPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
