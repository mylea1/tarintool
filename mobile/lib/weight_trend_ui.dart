part of 'product_features.dart';

class _WeightChart extends StatelessWidget {
  const _WeightChart({
    super.key,
    required this.points,
    required this.controller,
    required this.start,
    required this.end,
  });
  final List<_WeightPoint> points;
  final AppController controller;
  final DateTime start, end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TrendChart(
        unit: '体重 · kg',
        start: start,
        end: end,
        minimumSpan: 1.2,
        gapAfter: const Duration(days: 7),
        data: [
          for (final p in points)
            TrendDatum(
              id: p.entry.id,
              date: p.day,
              value: p.value,
              description:
                  '${trendDate(p.day)} · ${p.value.toStringAsFixed(1)} kg',
            ),
        ],
        detailBuilder: (context, datum) {
          final entry = points.firstWhere((p) => p.entry.id == datum.id).entry;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trendDate(entry.recordedAt)} · ${TimeOfDay.fromDateTime(entry.recordedAt).format(context)}',
                style: TextStyle(color: _muted(context)),
              ),
              Text(
                '${entry.weightKg.toStringAsFixed(1)} kg',
                key: const Key('weight-selected-value'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                key: const Key('weight-chart-open-record'),
                onPressed: () =>
                    _showWeightChartRecord(context, controller, entry.id),
                child: const Text('查看体重记录'),
              ),
            ],
          );
        },
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('体重数据如何显示？', style: TextStyle(fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '每天取最后一次记录，保留实际日期间隔；缺测不补零，超过 7 天的间隔以虚线连接。变化仅比较所选范围内首尾记录，不代表增减的好坏。',
              style: TextStyle(color: _muted(context), fontSize: 13),
            ),
          ),
        ],
      ),
    ],
  );
}

void _showWeightChartRecord(
  BuildContext context,
  AppController controller,
  String id,
) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entries = [...controller.weightEntries]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        final index = entries.indexWhere((entry) => entry.id == id);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '体重记录',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (index < 0)
                  const Text('这条记录已删除')
                else
                  _WeightHistoryTile(
                    entry: entries[index],
                    previous: index + 1 < entries.length
                        ? entries[index + 1]
                        : null,
                    controller: controller,
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
