import 'dart:io';

import 'package:flutter/material.dart';

import 'models.dart';

const workoutShareCardAspectRatio = 12 / 7;
const workoutResultCardAspectRatio = 1200 / 950;
const _brandLogoAsset = 'assets/branding/kilo-orange-metal-logo.png';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('workout-result-card'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF111214),
            borderRadius: BorderRadius.circular(18),
          ),
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
              if (exerciseNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    children: [
                      for (final name in exerciseNames)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (socialFooter != null) ...[
          const SizedBox(height: 10),
          socialFooter!,
        ],
      ],
    );
  }
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .24),
                  offset: const Offset(0, 8),
                  blurRadius: 18,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              _brandLogoAsset,
              fit: BoxFit.cover,
              semanticLabel: 'KILOSTRENGTH 标志',
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
            child: _ShareMetric(value: minutes, label: '分钟', accent: accent),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ShareMetric(value: volume, label: '训练量', accent: accent),
          ),
          const _MetricDivider(),
          Expanded(
            child: _ShareMetric(
              value: effectiveSets,
              label: '组数',
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
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.58, 0),
            radius: .58,
            colors: [
              accent.withValues(alpha: .18),
              accent.withValues(alpha: .04),
              Colors.transparent,
            ],
          ),
        ),
      ),
      Align(
        alignment: const Alignment(.68, 0),
        child: SizedBox.square(
          dimension: 500,
          child: ClipOval(
            child: Image.asset(
              _brandLogoAsset,
              fit: BoxFit.cover,
              semanticLabel: 'KILOSTRENGTH 品牌主视觉',
            ),
          ),
        ),
      ),
    ],
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
