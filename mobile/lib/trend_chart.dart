import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrendDatum {
  const TrendDatum({
    required this.id,
    required this.date,
    required this.value,
    required this.description,
  });
  final String id;
  final DateTime date;
  final double? value;
  final String description;
}

String trendDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
String trendNumber(num value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// A single series. Selection is keyed by record identity, never list index.
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.data,
    required this.unit,
    required this.start,
    required this.end,
    required this.detailBuilder,
    this.bars = false,
    this.integerTicks = false,
    this.minimumSpan = 1,
    this.gapAfter,
    this.emptyText = '所选时间段暂无记录',
  });
  final List<TrendDatum> data;
  final String unit;
  final DateTime start;
  final DateTime end;
  final bool bars;
  final bool integerTicks;
  final double minimumSpan;
  final Duration? gapAfter;
  final String emptyText;
  final Widget Function(BuildContext, TrendDatum) detailBuilder;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  String? selectedId;
  final focusNode = FocusNode();
  int get selectedIndex {
    final index = widget.data.indexWhere((point) => point.id == selectedId);
    return index < 0 ? widget.data.length - 1 : index;
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void select(int index) {
    if (widget.data.isEmpty) return;
    setState(
      () => selectedId = widget.data[index.clamp(0, widget.data.length - 1)].id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (widget.data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(widget.emptyText)),
      );
    }
    final index = selectedIndex;
    final selected = widget.data[index];
    final scale = MediaQuery.textScalerOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(widget.unit, style: TextStyle(color: colors.onSurfaceVariant)),
            Text(
              '${trendDate(widget.start)}—${trendDate(widget.end)}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final height = 214.0 + math.max(0.0, scale.scale(12) - 12) * 4;
            final size = Size(constraints.maxWidth, height);
            final painter = _TrendPainter(
              data: widget.data,
              selected: index,
              start: widget.start,
              end: widget.end,
              bars: widget.bars,
              integerTicks: widget.integerTicks,
              minimumSpan: widget.minimumSpan,
              gapAfter: widget.gapAfter,
              colors: colors,
              scaler: scale,
            );
            void pick(Offset position) {
              final xs = painter.positions(size);
              var nearest = 0;
              for (var i = 1; i < xs.length; i++) {
                if ((xs[i] - position.dx).abs() <
                    (xs[nearest] - position.dx).abs()) {
                  nearest = i;
                }
              }
              select(nearest);
            }

            return Focus(
              focusNode: focusNode,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  select(index - 1);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  select(index + 1);
                } else if (event.logicalKey == LogicalKeyboardKey.home) {
                  select(0);
                } else if (event.logicalKey == LogicalKeyboardKey.end) {
                  select(widget.data.length - 1);
                } else {
                  return KeyEventResult.ignored;
                }
                return KeyEventResult.handled;
              },
              child: Semantics(
                label: '${widget.unit}${widget.bars ? '柱状图' : '单指标折线图'}',
                value: selected.description,
                increasedValue: index < widget.data.length - 1
                    ? widget.data[index + 1].description
                    : selected.description,
                decreasedValue: index > 0
                    ? widget.data[index - 1].description
                    : selected.description,
                onIncrease: widget.data.length > 1
                    ? () => select(index + 1)
                    : null,
                onDecrease: widget.data.length > 1
                    ? () => select(index - 1)
                    : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    focusNode.requestFocus();
                    pick(details.localPosition);
                  },
                  onHorizontalDragStart: (details) =>
                      pick(details.localPosition),
                  onHorizontalDragUpdate: (details) =>
                      pick(details.localPosition),
                  child: SizedBox(
                    height: height,
                    width: double.infinity,
                    child: CustomPaint(painter: painter),
                  ),
                ),
              ),
            );
          },
        ),
        Text(
          '点选或横向拖动查看，左右按钮逐条选择',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        const Divider(height: 24),
        Semantics(
          liveRegion: true,
          child: widget.detailBuilder(context, selected),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '上一条记录',
                onPressed: index > 0 ? () => select(index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: '下一条记录',
                onPressed: index < widget.data.length - 1
                    ? () => select(index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.data,
    required this.selected,
    required this.start,
    required this.end,
    required this.bars,
    required this.integerTicks,
    required this.minimumSpan,
    required this.gapAfter,
    required this.colors,
    required this.scaler,
  });
  final List<TrendDatum> data;
  final int selected;
  final DateTime start, end;
  final bool bars, integerTicks;
  final double minimumSpan;
  final Duration? gapAfter;
  final ColorScheme colors;
  final TextScaler scaler;

  TextPainter text(String value) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    textScaler: scaler,
    textDirection: TextDirection.ltr,
  )..layout();

  ({double low, double high, double step}) get axis {
    final values = data
        .map((p) => p.value)
        .whereType<double>()
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) return (low: 0.0, high: 1.0, step: 1.0);
    final min = bars ? 0.0 : values.reduce(math.min);
    final max = values.reduce(math.max);
    final raw = math.max(max - min, minimumSpan) / 3;
    final power = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final fraction = raw / power;
    var step =
        (fraction <= 1
            ? 1
            : fraction <= 2
            ? 2
            : fraction <= 2.5
            ? 2.5
            : fraction <= 5
            ? 5
            : 10) *
        power;
    if (integerTicks) step = math.max(1, step.ceilToDouble());
    final low = bars
        ? 0.0
        : math.max(0.0, ((min - step * .25) / step).floor() * step);
    final high = math.max(
      low + step,
      ((max + step * .25) / step).ceil() * step,
    );
    return (low: low, high: high, step: step);
  }

  String axisText(double v) =>
      v >= 10000 ? '${trendNumber(v / 1000)}k' : trendNumber(v);

  Rect plot(Size size) {
    final a = axis;
    final labelWidth = math.max(
      text(axisText(a.low)).width,
      text(axisText(a.high)).width,
    );
    return Rect.fromLTRB(
      math.min(labelWidth + 10, size.width * .42),
      12,
      math.max(size.width * .6, size.width - 12),
      size.height - scaler.scale(12) - 18,
    );
  }

  List<double> positions(Size size) {
    final r = plot(size);
    if (bars) {
      return [
        for (var i = 0; i < data.length; i++)
          r.left + r.width * (i + .5) / data.length,
      ];
    }
    final from = start.millisecondsSinceEpoch;
    final span = end.millisecondsSinceEpoch - from;
    return data
        .map(
          (p) => span <= 0
              ? r.center.dx
              : r.left +
                    r.width *
                        ((p.date.millisecondsSinceEpoch - from) / span).clamp(
                          0.0,
                          1.0,
                        ),
        )
        .toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0) return;
    final r = plot(size), a = axis, xs = positions(size);
    final grid = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 1;
    for (var v = a.low; v <= a.high + a.step * .01; v += a.step) {
      final y = r.bottom - (v - a.low) / (a.high - a.low) * r.height;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
      final label = text(axisText(v));
      label.paint(
        canvas,
        Offset(math.max(0, r.left - label.width - 8), y - label.height / 2),
      );
    }
    final first = bars ? data.first.date : start,
        last = bars ? data.last.date : end;
    final firstLabel = text('${first.month}/${first.day}'),
        lastLabel = text('${last.month}/${last.day}');
    firstLabel.paint(canvas, Offset(r.left, r.bottom + 10));
    if (!DateUtils.isSameDay(first, last) &&
        r.width > firstLabel.width + lastLabel.width + 16) {
      lastLabel.paint(canvas, Offset(r.right - lastLabel.width, r.bottom + 10));
    }
    if (!bars && r.width > (firstLabel.width + lastLabel.width) * 2 + 40) {
      final mid = start.add(
        Duration(milliseconds: end.difference(start).inMilliseconds ~/ 2),
      );
      final label = text('${mid.month}/${mid.day}');
      label.paint(canvas, Offset(r.center.dx - label.width / 2, r.bottom + 10));
    }
    final offsets = [
      for (var i = 0; i < data.length; i++)
        data[i].value == null || !data[i].value!.isFinite
            ? null
            : Offset(
                xs[i],
                r.bottom -
                    (data[i].value! - a.low) / (a.high - a.low) * r.height,
              ),
    ];
    final stroke = Paint()
      ..color = colors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.clipRect(r.inflate(7));
    if (bars) {
      final width = math.min(28.0, r.width / data.length * .58);
      for (var i = 0; i < offsets.length; i++) {
        final p = offsets[i];
        if (p == null) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(p.dx - width / 2, p.dy, p.dx + width / 2, r.bottom),
            const Radius.circular(3),
          ),
          Paint()
            ..color = colors.primary.withValues(alpha: i == selected ? 1 : .4),
        );
      }
    } else {
      for (var i = 1; i < offsets.length; i++) {
        final previous = offsets[i - 1], current = offsets[i];
        if (previous == null || current == null) continue;
        if (gapAfter != null &&
            data[i].date.difference(data[i - 1].date) > gapAfter!) {
          final delta = current - previous, distance = delta.distance;
          if (distance > 0) {
            for (var d = 0.0; d < distance; d += 10) {
              canvas.drawLine(
                previous + delta * (d / distance),
                previous + delta * (math.min(d + 4, distance) / distance),
                Paint()
                  ..color = colors.primary.withValues(alpha: .55)
                  ..strokeWidth = 2,
              );
            }
          }
        } else {
          canvas.drawLine(previous, current, stroke);
        }
      }
      for (final point in offsets.whereType<Offset>()) {
        canvas.drawCircle(point, 3, Paint()..color = colors.surface);
        canvas.drawCircle(
          point,
          3,
          Paint()
            ..color = colors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    for (var y = r.top; y < r.bottom; y += 8) {
      canvas.drawLine(
        Offset(xs[selected], y),
        Offset(xs[selected], math.min(y + 3, r.bottom)),
        Paint()
          ..color = colors.primary.withValues(alpha: .55)
          ..strokeWidth = 1,
      );
    }
    final point = offsets[selected];
    if (point != null) {
      canvas.drawCircle(point, 6, Paint()..color = colors.surface);
      canvas.drawCircle(point, 4, Paint()..color = colors.primary);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
